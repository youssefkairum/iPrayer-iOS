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
    /// Translation key shown on the home screen when location access is unavailable.
    @Published var locationError: String?
    
    private static let locationErrorKey = "Location access is needed to show prayer times."
    
    /// How many days of prayer notifications to keep scheduled ahead of time.
    private static let notificationDaysAhead = 7
    /// Sunrise is deliberately excluded: it marks the end of Fajr, it is not a prayer.
    private static let notifiedPrayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
    
    /// Signature of the last run of the side effects (notifications, widget, Live Activity).
    /// Launch and foreground events fire several recalculations in a row; this avoids repeating that work.
    private var lastScheduleSignature: String?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        // Hundred-metre accuracy is plenty for prayer times and gets a fix faster on less battery.
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Only publish heading changes of at least one degree so sensor noise doesn't re-render the UI.
        locationManager.headingFilter = 1
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
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .denied, .restricted:
                self.locationError = Self.locationErrorKey
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                self.locationManager.startUpdatingLocation()
            default:
                break
            }
        }
    }
    
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
        // CoreLocation reports an invalid true heading as a negative value; exactly 0 is a valid true north.
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        // Update UI on Main Thread
        Task { @MainActor in
            self.currentHeading = heading
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient errors such as locationUnknown resolve on their own; only surface a hard denial.
        guard (error as? CLError)?.code == .denied else { return }
        Task { @MainActor in
            self.locationError = Self.locationErrorKey
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
        
        // 1. LOAD SAVED SETTINGS
        let methodString = UserDefaults.standard.string(forKey: UDKey.calculationMethod.rawValue) ?? "muslimWorldLeague"
        let madhabString = UserDefaults.standard.string(forKey: UDKey.madhab.rawValue) ?? "shafi"
        let appLang = UserDefaults.standard.string(forKey: UDKey.appLanguage.rawValue) ?? "en"
        
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
        
        let todayItems = [
            PrayerItem(name: "Fajr", time: todayPrayers.fajr, isNext: false),
            PrayerItem(name: "Sunrise", time: todayPrayers.sunrise, isNext: false),
            PrayerItem(name: "Dhuhr", time: todayPrayers.dhuhr, isNext: false),
            PrayerItem(name: "Asr", time: todayPrayers.asr, isNext: false),
            PrayerItem(name: "Maghrib", time: todayPrayers.maghrib, isNext: false),
            PrayerItem(name: "Isha", time: todayPrayers.isha, isNext: false)
        ]
        
        // 5. Update UI (this class is MainActor-isolated, no dispatch needed)
        self.qiblaDirection = Qibla(coordinates: coordinates).direction
        withAnimation(.easeInOut) {
            self.prayerTimes = newItems
            self.todayPrayerTimes = todayItems
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLang)
        formatter.timeStyle = .short
        self.nextPrayerTime = formatter.string(from: nextPrayerDate)
        self.nextPrayerName = nextPrayerNameStr
        
        // 6. Side effects only when something relevant actually changed
        let signature = newItems.map { "\($0.name)|\($0.time.timeIntervalSince1970)|\($0.isNext)" }.joined(separator: ",")
            + "|\(methodString)|\(madhabString)|\(appLang)"
        guard signature != lastScheduleSignature else { return }
        lastScheduleSignature = signature
        
        self.updateWidgetTimeline(coordinates: coordinates, params: params, language: appLang)
        self.scheduleNotifications(coordinates: coordinates, params: params, language: appLang)
        
        // Start or Update Live Activity
        if let nextPrayer = newItems.first(where: { $0.isNext }) {
            self.startOrUpdateLiveActivity(for: nextPrayer, language: appLang)
        }
    }
    
    // MARK: - Helper Functions
    
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
    
    private func updateWidgetTimeline(coordinates: Coordinates, params: CalculationParameters, language appLang: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLang)
        formatter.timeStyle = .short
        let translatedHeader = AppTranslations.translate("Next Prayer", to: appLang)
        
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
                let translatedName = AppTranslations.translate(currentPrayer.name, to: appLang)
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
    
    /// Schedules the next `notificationDaysAhead` days of prayer notifications, in the app's language,
    /// so users who don't open the app every day keep receiving them.
    private func scheduleNotifications(coordinates: Coordinates, params: CalculationParameters, language: String) {
        let center = UNUserNotificationCenter.current()
        let cal = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: language)
        
        // Remove everything this app may have scheduled before, including the legacy per-name identifiers.
        var identifiers = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
        for day in 0..<Self.notificationDaysAhead {
            for prayer in Self.notifiedPrayers {
                identifiers.append("prayer_\(prayerNameString(prayer))_\(day)")
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        for dayOffset in 0..<Self.notificationDaysAhead {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            guard let times = PrayerTimes(coordinates: coordinates, date: comps, calculationParameters: params) else { continue }
            
            for prayer in Self.notifiedPrayers {
                let time = times.time(for: prayer)
                if time < Date() { continue }
                
                let name = prayerNameString(prayer)
                let translatedName = AppTranslations.translate(name, to: language)
                
                let content = UNMutableNotificationContent()
                content.title = translatedName
                content.body = String(localized: "It's time for \(translatedName) prayer", locale: locale)
                // Notification sounds must be aiff, wav or caf and under 30 seconds; iOS silently ignores mp3.
                content.sound = UNNotificationSound(named: UNNotificationSoundName("adhan.caf"))
                
                let triggerComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                let request = UNNotificationRequest(identifier: "prayer_\(name)_\(dayOffset)", content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
    
    // MARK: - Live Activities
    
    private func startOrUpdateLiveActivity(for prayer: PrayerItem, language appLang: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLang)
        formatter.timeStyle = .short
        let timeStr = formatter.string(from: prayer.time)
        
        let attributes = PrayerAttributes()
        let safeUpperBound = max(Date(), prayer.time)
        let state = PrayerAttributes.ContentState(
            timeRemaining: Date()...safeUpperBound,
            prayerName: AppTranslations.translate(prayer.name, to: appLang),
            prayerIcon: prayer.icon,
            prayerTime: timeStr,
            atString: AppTranslations.translate("at", to: appLang),
            startsInString: AppTranslations.translate("Starts in", to: appLang),
            nextString: AppTranslations.translate("NEXT", to: appLang)
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
