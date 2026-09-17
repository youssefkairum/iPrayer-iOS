//
//  PrayerViewModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation
import Combine
import CoreLocation
import MapKit
import Adhan
import SwiftUI
import ActivityKit
import WidgetKit
import BackgroundTasks

// MARK: - Model
struct PrayerItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let time: Date
    let isNext: Bool
    
    var icon: String {
        switch name {
        case "Fajr": return "sun.haze.fill"
        case "Sunrise": return "sunrise.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.min.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.stars.fill"
        default: return "clock.fill"
        }
    }
}

// MARK: - ViewModel
@MainActor // Force all updates to happen on Main Thread (Modern Concurrency)
class PrayerViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var prayerTimes: [PrayerItem] = []
    @Published var todayPrayerTimes: [PrayerItem] = []
    @Published var locationName: String = "Locating..."
    @Published var qiblaDirection: Double = 0.0
    @Published var currentHeading: Double = 0.0
    @Published var nextPrayerTime: String = "--:--"
    @Published var nextPrayerName: String = ""
    @Published var locationError: String?
    
    // Live Activity State managed globally by iOS
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - Compass Battery Management
    func startCompass() {
        locationManager.startUpdatingHeading()
    }
    
    func stopCompass() {
        locationManager.stopUpdatingHeading()
    }
    
    // MARK: - Location Delegate
    
    // Non-isolated is required because CLLocationManagerDelegate methods are not automatically MainActor
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Stop updating location once we have a fix to save battery
        manager.stopUpdatingLocation()
        
        // Switch back to Main Actor to update UI and trigger calculations
        Task {
            await updateLocationData(location: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        // Update UI on Main Thread
        Task { @MainActor in
            self.currentHeading = heading
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = "Please enable location services."
        }
    }
    
    // MARK: - Async Logic
    
    private func updateLocationData(location: CLLocation) async {
        // 1. Fetch City Name (iOS 26+ Modern MapKit Approach)
        if locationName == "Locating..." {
            await fetchCityName(from: location)
        }
        
        // 2. Calculate Prayers
        calculatePrayers(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    private func fetchCityName(from location: CLLocation) async {
        do {
            // iOS 26+ Modern API: Using MKReverseGeocodingRequest
            guard let request = MKReverseGeocodingRequest(location: location) else {
                self.locationName = "Unknown Location"
                return
            }
            
            let mapItems = try await request.mapItems
            
            if let mapItem = mapItems.first {
                // Try addressRepresentations (iOS 26+ preferred API)
                if let addressReps = mapItem.addressRepresentations {
                    // Access the structured address components
                    if let cityName = addressReps.cityName {
                        self.locationName = cityName
                    } else if let regionName = addressReps.regionName {
                        self.locationName = regionName
                    } else {
                        self.locationName = "Unknown Location"
                    }
                }
                // Fallback to name if available
                else if let name = mapItem.name {
                    self.locationName = name
                } else {
                    self.locationName = "Unknown Location"
                }
            } else {
                self.locationName = "Unknown Location"
            }
        } catch {
            print("Geocoding failed: \(error.localizedDescription)")
            self.locationName = "Unknown Location"
        }
    }
    
    // MARK: - Public Refresh Method
    func updateLocation() {
        self.locationName = "Locating..."
        locationManager.startUpdatingLocation()
    }
    
    func refreshPrayers() {
        // Trigger a recalculation using the last known location
        if let location = locationManager.location {
            calculatePrayers(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

        // MARK: - Calculation Logic
        
        private func calculatePrayers(latitude: Double, longitude: Double) {
            let coordinates = Coordinates(latitude: latitude, longitude: longitude)
            let cal = Calendar(identifier: .gregorian)
            let dateComponents = cal.dateComponents([.year, .month, .day], from: Date())
            
            // 1. LOAD SAVED SETTINGS (Replaces Hardcoded Values)
            let methodString = UserDefaults.standard.string(forKey: UDKey.calculationMethod.rawValue) ?? "muslimWorldLeague"
            let madhabString = UserDefaults.standard.string(forKey: UDKey.madhab.rawValue) ?? "shafi"
            
            // Map String -> Adhan.CalculationMethod
            var method: CalculationMethod = .muslimWorldLeague
            switch methodString {
            case "muslimWorldLeague": method = .muslimWorldLeague
            case "egyptian": method = .egyptian
            case "karachi": method = .karachi
            case "ummAlQura": method = .ummAlQura
            case "dubai": method = .dubai
            case "northAmerica": method = .northAmerica
            case "kuwait": method = .kuwait
            case "qatar": method = .qatar
            case "singapore": method = .singapore
            case "turkey": method = .turkey
            case "tehran": method = .tehran
            default: method = .muslimWorldLeague
            }
            
            var params = method.params
            
            // Map String -> Adhan.Madhab
            if madhabString == "hanafi" {
                params.madhab = .hanafi
            } else {
                params.madhab = .shafi // Standard (includes Maliki & Hanbali)
            }
            
            // 2. Calculate Today's Prayers
            guard let todayPrayers = PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else { return }
            
            // 3. Determine Next Prayer and List Data
            let next = todayPrayers.nextPrayer()
            
            var displayPrayers = todayPrayers
            var nextPrayerDate = Date()
            var nextPrayerNameStr = ""
            var isNextDay = false
            
            if let nextP = next {
                // Case A: Still have prayers today
                displayPrayers = todayPrayers
                nextPrayerDate = todayPrayers.time(for: nextP)
                nextPrayerNameStr = self.prayerNameString(nextP)
                isNextDay = false
            } else {
                // Case B: Finished for today (After Isha) -> Switch to Tomorrow
                let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
                let tomorrowComponents = cal.dateComponents([.year, .month, .day], from: tomorrow)
                
                if let tomorrowPrayers = PrayerTimes(coordinates: coordinates, date: tomorrowComponents, calculationParameters: params) {
                    displayPrayers = tomorrowPrayers
                    nextPrayerDate = tomorrowPrayers.fajr
                    nextPrayerNameStr = "Fajr"
                    isNextDay = true
                } else {
                    nextPrayerDate = Date()
                    nextPrayerNameStr = "Unknown"
                    isNextDay = false
                }
            }
            
            // 4. Build List
            let newItems = [
                PrayerItem(name: "Fajr", time: displayPrayers.fajr, isNext: (!isNextDay && next == .fajr) || (isNextDay && nextPrayerNameStr == "Fajr")),
                PrayerItem(name: "Sunrise", time: displayPrayers.sunrise, isNext: !isNextDay && next == .sunrise),
                PrayerItem(name: "Dhuhr", time: displayPrayers.dhuhr, isNext: !isNextDay && next == .dhuhr),
                PrayerItem(name: "Asr", time: displayPrayers.asr, isNext: !isNextDay && next == .asr),
                PrayerItem(name: "Maghrib", time: displayPrayers.maghrib, isNext: !isNextDay && next == .maghrib),
                PrayerItem(name: "Isha", time: displayPrayers.isha, isNext: !isNextDay && next == .isha)
            ]
            
            // 5. Update UI
            let qibla = Qibla(coordinates: coordinates)
            
            let todayItems = [
                PrayerItem(name: "Fajr", time: todayPrayers.fajr, isNext: false),
                PrayerItem(name: "Sunrise", time: todayPrayers.sunrise, isNext: false),
                PrayerItem(name: "Dhuhr", time: todayPrayers.dhuhr, isNext: false),
                PrayerItem(name: "Asr", time: todayPrayers.asr, isNext: false),
                PrayerItem(name: "Maghrib", time: todayPrayers.maghrib, isNext: false),
                PrayerItem(name: "Isha", time: todayPrayers.isha, isNext: false)
            ]
            
            DispatchQueue.main.async {
                self.qiblaDirection = qibla.direction
                withAnimation(.easeInOut) {
                    self.prayerTimes = newItems
                    self.todayPrayerTimes = todayItems
                }
                
                self.updateWidgetTimeline(coordinates: coordinates, params: params)
                
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                self.nextPrayerTime = formatter.string(from: nextPrayerDate)
                self.nextPrayerName = nextPrayerNameStr
                
                self.scheduleNotifications(for: newItems)
                
                // Start or Update Live Activity
                if let nextPrayer = newItems.first(where: { $0.isNext }) {
                    self.startOrUpdateLiveActivity(for: nextPrayer)
                }
            }
        }
        
        // MARK: - Helper Functions (ADDED TO FIX ERRORS)
        
        private func prayerNameString(_ p: Prayer) -> String {
            switch p {
            case .fajr: return "Fajr"
            case .sunrise: return "Sunrise"
            case .dhuhr: return "Dhuhr"
            case .asr: return "Asr"
            case .maghrib: return "Maghrib"
            case .isha: return "Isha"
            }
        }
        
        private func translate(text: String, to language: String) -> String {
            let dict: [String: [String: String]] = [
                "Fajr": ["ar": "الفجر", "ur": "فجر", "fr": "Fajr", "zh-Hans": "晨礼", "de": "Fadschr", "hi": "फज्र", "tr": "İmsak", "ru": "Фаджр"],
                "Sunrise": ["ar": "الشروق", "ur": "طلوع آفتاب", "fr": "Lever du soleil", "zh-Hans": "日出", "de": "Sonnenaufgang", "hi": "सूर्योदय", "tr": "Güneş", "ru": "Восход"],
                "Dhuhr": ["ar": "الظهر", "ur": "ظہر", "fr": "Dhuhr", "zh-Hans": "晌礼", "de": "Dhuhr", "hi": "ज़ुहर", "tr": "Öğle", "ru": "Зухр"],
                "Asr": ["ar": "العصر", "ur": "عصر", "fr": "Asr", "zh-Hans": "晡礼", "de": "Asr", "hi": "असर", "tr": "İkindi", "ru": "Аср"],
                "Maghrib": ["ar": "المغرب", "ur": "مغرب", "fr": "Maghrib", "zh-Hans": "昏礼", "de": "Maghrib", "hi": "मग़रिब", "tr": "Akşam", "ru": "Магриб"],
                "Isha": ["ar": "العشاء", "ur": "عشاء", "fr": "Isha", "zh-Hans": "宵礼", "de": "Ischa", "hi": "ईशा", "tr": "Yatsı", "ru": "Иша"],
                "Next Prayer": ["ar": "الصلاة القادمة", "ur": "اگلی نماز", "fr": "Prochaine prière", "zh-Hans": "下一个祈祷", "de": "Nächstes Gebet", "hi": "अगली प्रार्थना", "tr": "Sonraki Namaz", "ru": "Следующая молитва"],
                "at": ["ar": "في", "ur": "پر", "fr": "à", "zh-Hans": "在", "de": "um", "hi": "पर", "tr": "saat", "ru": "в"],
                "Starts in": ["ar": "يبدأ في", "ur": "شروع ہوتا ہے", "fr": "Commence dans", "zh-Hans": "开始于", "de": "Beginnt in", "hi": "में शुरू होता है", "tr": "Başlıyor", "ru": "Начнется через"],
                "NEXT": ["ar": "التالي", "ur": "اگلا", "fr": "SUIVANT", "zh-Hans": "下一个", "de": "NÄCHSTES", "hi": "अगला", "tr": "SONRAKİ", "ru": "СЛЕДУЮЩИЙ"]
            ]
            return dict[text]?[language] ?? text
        }
        
        private func updateWidgetTimeline(coordinates: Coordinates, params: CalculationParameters) {
            let appLang = UserDefaults.standard.string(forKey: UDKey.appLanguage.rawValue) ?? "en"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: appLang)
            formatter.timeStyle = .short
            let translatedHeader = translate(text: "Next Prayer", to: appLang)
            
            let cal = Calendar(identifier: .gregorian)
            var allPrayers: [(name: String, time: Date)] = []
            
            for dayOffset in -1...2 {
                if let targetDate = cal.date(byAdding: .day, value: dayOffset, to: Date()) {
                    let comps = cal.dateComponents([.year, .month, .day], from: targetDate)
                    if let p = PrayerTimes(coordinates: coordinates, date: comps, calculationParameters: params) {
                        allPrayers.append(("Fajr", p.fajr))
                        allPrayers.append(("Sunrise", p.sunrise))
                        allPrayers.append(("Dhuhr", p.dhuhr))
                        allPrayers.append(("Asr", p.asr))
                        allPrayers.append(("Maghrib", p.maghrib))
                        allPrayers.append(("Isha", p.isha))
                    }
                }
            }
            
            allPrayers.sort { $0.time < $1.time }
            
            struct WidgetEntryData: Codable {
                let date: Date
                let prayerName: String
                let timeString: String
                let icon: String
                let headerString: String
            }
            
            var widgetEntries: [WidgetEntryData] = []
            
            for i in 1..<allPrayers.count {
                let currentPrayer = allPrayers[i]
                let previousPrayer = allPrayers[i-1]
                
                // Switch widget text exactly when the previous prayer starts
                let displayStartTime = previousPrayer.time
                
                // Only schedule for future prayers (and the current active one)
                if currentPrayer.time > Date() {
                    let translatedName = translate(text: currentPrayer.name, to: appLang)
                    let timeString = formatter.string(from: currentPrayer.time)
                    
                    let iconName: String
                    switch currentPrayer.name {
                    case "Fajr": iconName = "sun.haze.fill"
                    case "Sunrise": iconName = "sunrise.fill"
                    case "Dhuhr": iconName = "sun.max.fill"
                    case "Asr": iconName = "sun.min.fill"
                    case "Maghrib": iconName = "sunset.fill"
                    case "Isha": iconName = "moon.stars.fill"
                    default: iconName = "clock.fill"
                    }
                    
                    let entryDate = displayStartTime < Date() ? Date() : displayStartTime
                    
                    widgetEntries.append(WidgetEntryData(
                        date: entryDate,
                        prayerName: translatedName,
                        timeString: timeString,
                        icon: iconName,
                        headerString: translatedHeader
                    ))
                }
            }
            
            // Save JSON array to shared App Group
            if let sharedDefaults = UserDefaults(suiteName: "group.iPrayer.shared") {
                if let encoded = try? JSONEncoder().encode(widgetEntries) {
                    sharedDefaults.set(encoded, forKey: "widgetTimelineData")
                }
            }
            
            WidgetCenter.shared.reloadAllTimelines()
        }
    // MARK: - Notifications
    
    private func scheduleNotifications(for prayers: [PrayerItem]) {
        let center = UNUserNotificationCenter.current()
        
        // Synchronously remove only prayer notifications to prevent async race condition bugs
        let allPrayerIdentifiers = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
        center.removePendingNotificationRequests(withIdentifiers: allPrayerIdentifiers)
        
        for prayer in prayers {
            if prayer.time < Date() { continue }
            
            let content = UNMutableNotificationContent()
            let translatedName = NSLocalizedString(prayer.name, comment: "")
            let formatString = NSLocalizedString("It's time for %@ prayer", comment: "")
            
            content.title = translatedName
            content.body = String(format: formatString, translatedName)
            
            // UPDATED: Use the custom adhan sound
            // Note: iOS limits notification sounds to 30 seconds.
            // If adhan.mp3 is longer, iOS will cut it off or use the default sound.
            content.sound = UNNotificationSound(named: UNNotificationSoundName("adhan.mp3"))
            
            let components = Calendar.current.dateComponents([.hour, .minute], from: prayer.time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: prayer.name, content: content, trigger: trigger)
            center.add(request)
        }
    }
    
    // MARK: - Live Activities
    
    private func startOrUpdateLiveActivity(for prayer: PrayerItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let appLang = UserDefaults.standard.string(forKey: UDKey.appLanguage.rawValue) ?? "en"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLang)
        formatter.timeStyle = .short
        let timeStr = formatter.string(from: prayer.time)
        let translatedName = translate(text: prayer.name, to: appLang)
        let translatedAt = translate(text: "at", to: appLang)
        let translatedStartsIn = translate(text: "Starts in", to: appLang)
        let translatedNext = translate(text: "NEXT", to: appLang)
        
        let attributes = PrayerAttributes()
        let safeUpperBound = max(Date(), prayer.time)
        let state = PrayerAttributes.ContentState(
            timeRemaining: Date()...safeUpperBound,
            prayerName: translatedName,
            prayerIcon: prayer.icon,
            prayerTime: timeStr,
            atString: translatedAt,
            startsInString: translatedStartsIn,
            nextString: translatedNext
        )
        let staleDate = prayer.time.addingTimeInterval(60) // stale 1 minute after prayer
        
        let content = ActivityContent(state: state, staleDate: staleDate)
        
        let activeActivities = Activity<PrayerAttributes>.activities
        
        if activeActivities.isEmpty {
            // Start new activity
            do {
                let _ = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                print("Error starting Live Activity: \(error.localizedDescription)")
            }
        } else {
            // Update all existing activities
            Task {
                for activity in activeActivities {
                    await activity.update(content)
                }
            }
        }
        
        // Ask iOS to wake up the app when the prayer time hits so we can update the Live Activity
        scheduleNextRefresh(for: prayer.time)
    }
    
    private func scheduleNextRefresh(for prayerTime: Date) {
        let request = BGAppRefreshTaskRequest(identifier: "com.youssefkairum.iPrayer.refresh")
        request.earliestBeginDate = prayerTime
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Successfully scheduled background refresh for \(prayerTime)")
        } catch {
            print("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }
}
