//
//  WatchModel.swift
//  iPrayerWatch
//
//  Location, prayer calculation, compass heading and the settings received from the phone.
//  Also writes SharedPrayerConfig to the App Group so the complications compute their own timeline,
//  exactly as the iPhone widget does, and keeps the location fresh with a background refresh.
//

import Foundation
import CoreLocation
import Combine
import WidgetKit
import WatchKit
import Adhan

@MainActor
final class WatchModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WatchModel()
    
    enum LocationSource: String { case none, watch, phone }
    
    @Published private(set) var todayPrayers: [ScheduledPrayer] = []
    @Published private(set) var nextPrayer: ScheduledPrayer?
    /// The one after `nextPrayer`, for the "then ..." line
    @Published private(set) var followingPrayer: ScheduledPrayer?
    @Published var currentHeading: Double = 0
    @Published private(set) var qiblaDirection: Double = 0
    @Published private(set) var distanceToKaabaMetres: Double = 0
    @Published private(set) var locationSource: LocationSource = .none
    @Published private(set) var locationDenied = false
    @Published private(set) var locationName: String = ""
    @Published private(set) var language = "en"
    @Published private(set) var prayerNames: [String: String] = [:]
    @Published private(set) var hijriDate: String = ""
    
    var headingAvailable: Bool { CLLocationManager.headingAvailable() }
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var tick: Timer?
    private var coordinates: (latitude: Double, longitude: Double)?
    private var lastFix: Date?
    
    private static let kaaba = CLLocation(latitude: 21.422487, longitude: 39.826206)
    private static let backgroundRefreshInterval: TimeInterval = 6 * 3600
    static let backgroundRefreshIdentifier = "iPrayerWatch.refresh"
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        load()
        refresh()
    }
    
    // MARK: - Lifecycle
    
    /// Called when the app becomes active
    func start() {
        WatchSync.shared.activate()
        requestLocationIfAllowed()
        refresh()
        scheduleBackgroundRefresh()
        
        // Roll to the next prayer as time passes while the app stays open
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                if let next = WatchModel.shared.nextPrayer, next.time <= Date() {
                    WatchModel.shared.refresh()
                }
            }
        }
    }
    
    func stop() {
        tick?.invalidate()
        tick = nil
    }
    
    /// Runs in the background a few times a day: a fresh location fix so the complications follow
    /// the wearer, then a recompute. CoreLocation answers asynchronously; give it a few seconds.
    func backgroundRefresh() async {
        requestLocationIfAllowed()
        try? await Task.sleep(for: .seconds(8))
        refresh()
        scheduleBackgroundRefresh()
    }
    
    private func scheduleBackgroundRefresh() {
        let date = Date().addingTimeInterval(Self.backgroundRefreshInterval)
        // The identifier travels as userInfo and matches the app's `.backgroundTask(.appRefresh(...))` handler
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: date, userInfo: Self.backgroundRefreshIdentifier as NSString) { _ in }
    }
    
    private func requestLocationIfAllowed() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
        default:
            locationDenied = false
            // One fix is enough; the watch is not a navigation device
            locationManager.requestLocation()
        }
    }
    
    func startCompass() {
        if headingAvailable { locationManager.startUpdatingHeading() }
    }
    
    func stopCompass() {
        locationManager.stopUpdatingHeading()
    }
    
    // MARK: - Settings and location persisted on the watch
    
    private func load() {
        let defaults = UserDefaults.standard
        language = defaults.string(forKey: UDKey.appLanguage.rawValue) ?? "en"
        if let names = defaults.dictionary(forKey: "watchPrayerNames") as? [String: String] { prayerNames = names }
        locationName = defaults.string(forKey: "watchLocationName") ?? ""
        if let source = LocationSource(rawValue: defaults.string(forKey: "watchLocationSource") ?? ""), source != .none {
            coordinates = (defaults.double(forKey: "watchLatitude"), defaults.double(forKey: "watchLongitude"))
            locationSource = source
        }
    }
    
    private func store(latitude: Double, longitude: Double, source: LocationSource) {
        coordinates = (latitude, longitude)
        locationSource = source
        let defaults = UserDefaults.standard
        defaults.set(latitude, forKey: "watchLatitude")
        defaults.set(longitude, forKey: "watchLongitude")
        defaults.set(source.rawValue, forKey: "watchLocationSource")
    }
    
    /// Settings and progress sent by the phone
    func apply(_ payload: WatchSyncPayload) {
        let defaults = UserDefaults.standard
        if let method = payload.calculationMethod { defaults.set(method, forKey: UDKey.calculationMethod.rawValue) }
        if let madhab = payload.madhab { defaults.set(madhab, forKey: UDKey.madhab.rawValue) }
        if let lang = payload.language {
            defaults.set(lang, forKey: UDKey.appLanguage.rawValue)
            language = lang
        }
        if let names = payload.prayerNames {
            defaults.set(names, forKey: "watchPrayerNames")
            prayerNames = names
        }
        // The phone's location only stands in while the watch has none of its own
        if let lat = payload.latitude, let lon = payload.longitude, locationSource != .watch {
            store(latitude: lat, longitude: lon, source: .phone)
        }
        if payload.applyProgress() {
            HomeWidgetsData.shared.reloadFromDefaults()
        }
        refresh()
    }
    
    func name(for prayer: String) -> String {
        prayerNames[prayer] ?? AppTranslations.translate(prayer, to: language)
    }
    
    // MARK: - Calculation
    
    func refresh() {
        hijriDate = Self.hijriString(for: Date(), language: language)
        guard let coordinates else { return }
        let defaults = UserDefaults.standard
        let method = defaults.string(forKey: UDKey.calculationMethod.rawValue) ?? "muslimWorldLeague"
        let madhab = defaults.string(forKey: UDKey.madhab.rawValue) ?? "shafi"
        let parameters = PrayerSchedule.parameters(method: method, madhab: madhab)
        let now = Date()
        
        let all = PrayerSchedule.prayers(latitude: coordinates.latitude, longitude: coordinates.longitude,
                                         parameters: parameters, dayOffsets: 0...1, from: now)
        todayPrayers = all.filter { Calendar.current.isDate($0.time, inSameDayAs: now) }
        let upcoming = all.filter { $0.time > now }
        nextPrayer = upcoming.first
        followingPrayer = upcoming.dropFirst().first
        
        let here = Coordinates(latitude: coordinates.latitude, longitude: coordinates.longitude)
        qiblaDirection = Qibla(coordinates: here).direction
        distanceToKaabaMetres = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude).distance(from: Self.kaaba)
        
        // The complications read this, like the iPhone widget does
        SharedPrayerConfig(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            calculationMethod: method,
            madhab: madhab,
            language: language,
            prayerNames: prayerNames,
            header: AppTranslations.translate("Next Prayer", to: language)
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private static func hijriString(for date: Date, language: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: language)
        formatter.setLocalizedDateFormatFromTemplate("d MMMM y")
        return formatter.string(from: date)
    }
    
    /// The city for the header, looked up once per fix and remembered
    private func updateLocationName(latitude: Double, longitude: Double) {
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)) { placemarks, _ in
            let name = placemarks?.first.flatMap { $0.locality ?? $0.administrativeArea } ?? ""
            guard !name.isEmpty else { return }
            // No self capture across the actor hop: the model is a singleton
            Task { @MainActor in WatchModel.shared.setLocationName(name) }
        }
    }
    
    private func setLocationName(_ name: String) {
        locationName = name
        UserDefaults.standard.set(name, forKey: "watchLocationName")
    }
    
    // MARK: - CLLocationManagerDelegate (nonisolated: CoreLocation calls these on its own thread)
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationDenied = false
                self.locationManager.requestLocation()
            case .denied, .restricted:
                self.locationDenied = true
            default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        Task { @MainActor in
            // Skip a fix that barely moved: no recompute, no geocoding, no complication reload
            if let current = self.coordinates, self.locationSource == .watch,
               abs(current.latitude - latitude) < 0.01, abs(current.longitude - longitude) < 0.01 {
                self.lastFix = Date()
                return
            }
            self.lastFix = Date()
            self.store(latitude: latitude, longitude: longitude, source: .watch)
            self.refresh()
            self.updateLocationName(latitude: latitude, longitude: longitude)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // CoreLocation reports an invalid true heading as a negative value; exactly 0 is a valid true north.
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.currentHeading = heading }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep whatever location we had (the watch's last fix or the phone's)
    }
}
