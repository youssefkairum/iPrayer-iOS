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
    
    var icon: String { PrayerSchedule.icon(for: name) }
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
    /// Drives the Home card that asks for location access when it hasn't been decided yet.
    @Published var locationAuthorization: CLAuthorizationStatus = .notDetermined
    
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
        locationAuthorization = locationManager.authorizationStatus
        // Permission is requested from onboarding or the Home card, next to an explanation, not at launch.
        // If access was already granted, locationManagerDidChangeAuthorization (which CoreLocation
        // calls right after the delegate is set) starts the updates.
    }
    
    /// Shows the system location prompt. Called from the onboarding slide and the Home card.
    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
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
            self.locationAuthorization = status
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
    
    /// Re-runs notification, widget and Live Activity scheduling even if the prayer times are unchanged,
    /// for example after a notification setting changes or permission is granted.
    func forceReschedule() {
        lastScheduleSignature = nil
        refreshPrayers()
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
        
        // Shared with the widget so both always use identical parameters
        let params = PrayerSchedule.parameters(method: methodString, madhab: madhabString)
        
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
        
        self.updateWidgetTimeline(latitude: latitude, longitude: longitude, method: methodString, madhab: madhabString, language: appLang)
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
    
    /// The widget computes its own timeline with Adhan, so the app only shares the inputs.
    private func updateWidgetTimeline(latitude: Double, longitude: Double, method: String, madhab: String, language appLang: String) {
        var names: [String: String] = [:]
        for name in PrayerSchedule.prayerNames {
            names[name] = AppTranslations.translate(name, to: appLang)
        }
        
        SharedPrayerConfig(
            latitude: latitude,
            longitude: longitude,
            calculationMethod: method,
            madhab: madhab,
            language: appLang,
            prayerNames: names,
            header: AppTranslations.translate("Next Prayer", to: appLang)
        ).save()
        
        // Entries precomputed by older versions of the app are no longer read
        UserDefaults(suiteName: SharedPrayerConfig.suiteName)?.removeObject(forKey: "widgetTimelineData")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Notifications
    
    /// Schedules several days of prayer notifications, in the app's language,
    /// so users who don't open the app every day keep receiving them.
    private func scheduleNotifications(coordinates: Coordinates, params: CalculationParameters, language: String) {
        let center = UNUserNotificationCenter.current()
        let cal = Calendar(identifier: .gregorian)
        
        // User settings (Settings > Notifications)
        let defaults = UserDefaults.standard
        let adhanEnabled = defaults.object(forKey: UDKey.adhanSoundEnabled.rawValue) as? Bool ?? true
        let reminderMinutes = defaults.integer(forKey: UDKey.prePrayerReminderMinutes.rawValue)
        // iOS keeps at most 64 pending requests per app; reminders double the count, so look less far ahead.
        let daysAhead = reminderMinutes > 0 ? 5 : Self.notificationDaysAhead
        
        // Remove everything this app may have scheduled before, including the legacy per-name identifiers.
        var identifiers = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
        for day in 0..<Self.notificationDaysAhead {
            for prayer in Self.notifiedPrayers {
                identifiers.append("prayer_\(prayerNameString(prayer))_\(day)")
                identifiers.append("preprayer_\(prayerNameString(prayer))_\(day)")
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        for dayOffset in 0..<daysAhead {
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
                content.body = AppTranslations.catalogString("It's time for %@ prayer", language: language, translatedName)
                // Notification sounds must be aiff, wav or caf and under 30 seconds; iOS silently ignores mp3.
                content.sound = adhanEnabled ? UNNotificationSound(named: UNNotificationSoundName("adhan.caf")) : .default
                
                let triggerComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                center.add(UNNotificationRequest(identifier: "prayer_\(name)_\(dayOffset)", content: content, trigger: trigger))
                
                // Optional heads-up a few minutes before the prayer
                let reminderTime = time.addingTimeInterval(TimeInterval(-reminderMinutes * 60))
                if reminderMinutes > 0, reminderTime > Date() {
                    let reminder = UNMutableNotificationContent()
                    reminder.title = translatedName
                    reminder.body = String(format: AppTranslations.minutesFormat("%@ in %lld minutes", minutes: reminderMinutes, language: language), translatedName, reminderMinutes)
                    reminder.sound = .default
                    
                    let reminderComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
                    let reminderTrigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
                    center.add(UNNotificationRequest(identifier: "preprayer_\(name)_\(dayOffset)", content: reminder, trigger: reminderTrigger))
                }
            }
        }
    }
    
    // MARK: - Live Activities
    
    private func startOrUpdateLiveActivity(for prayer: PrayerItem, language appLang: String) {
        let allActivities = Activity<PrayerAttributes>.activities
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // The user switched Live Activities off: don't leave an old countdown behind.
            Task {
                for activity in allActivities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            return
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLang)
        formatter.timeStyle = .short
        let timeStr = formatter.string(from: prayer.time)
        
        let safeUpperBound = max(Date(), prayer.time)
        let state = PrayerAttributes.ContentState(
            timeRemaining: Date()...safeUpperBound,
            prayerName: AppTranslations.translate(prayer.name, to: appLang),
            prayerIcon: prayer.icon,
            prayerTime: timeStr,
            atString: AppTranslations.translate("at", to: appLang),
            startsInString: AppTranslations.translate("Starts in", to: appLang),
            nextString: AppTranslations.translate("NEXT", to: appLang),
            nowString: AppTranslations.translate("Now", to: appLang),
            openHintString: AppTranslations.translate("Tap to open iPrayer", to: appLang)
        )
        // Once the prayer time passes the activity turns stale and the widget shows "Now"
        // instead of a countdown stuck at zero, until the app gets to run and moves it on.
        let content = ActivityContent(state: state, staleDate: prayer.time.addingTimeInterval(60))
        
        let liveActivities = allActivities.filter { $0.activityState == .active || $0.activityState == .stale }
        
        if let current = liveActivities.first {
            Task {
                // Replace the previous prayer with the next one, and end any duplicates
                await current.update(content)
                for extra in liveActivities.dropFirst() {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
            }
        } else {
            do {
                let _ = try Activity.request(
                    attributes: PrayerAttributes(),
                    content: content,
                    pushType: nil
                )
            } catch {
                print("Error starting Live Activity: \(error.localizedDescription)")
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
