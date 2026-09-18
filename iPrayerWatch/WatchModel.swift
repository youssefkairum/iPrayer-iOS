//
//  WatchModel.swift
//  iPrayerWatch
//
//  Location, prayer calculation, compass heading and the settings received from the phone.
//  Also writes SharedPrayerConfig to the App Group so the complications compute their own timeline,
//  exactly as the iPhone widget does.
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
    @Published var currentHeading: Double = 0
    @Published private(set) var qiblaDirection: Double = 0
    @Published private(set) var locationSource: LocationSource = .none
    @Published private(set) var locationDenied = false
    @Published private(set) var language = "en"
    @Published private(set) var prayerNames: [String: String] = [:]
    
    private let locationManager = CLLocationManager()
    private var tick: Timer?
    private var coordinates: (latitude: Double, longitude: Double)?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        load()
        refresh()
    }
    
    // MARK: - Lifecycle
    
    func start() {
        WatchSync.shared.activate()
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
        default:
            locationManager.requestLocation()
        }
        refresh()
        
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
    
    func startCompass() {
        if CLLocationManager.headingAvailable() { locationManager.startUpdatingHeading() }
    }
    
    func stopCompass() {
        locationManager.stopUpdatingHeading()
    }
    
    // MARK: - Settings and location persisted on the watch
    
    private func load() {
        let defaults = UserDefaults.standard
        language = defaults.string(forKey: UDKey.appLanguage.rawValue) ?? "en"
        if let names = defaults.dictionary(forKey: "watchPrayerNames") as? [String: String] { prayerNames = names }
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
        guard let coordinates else { return }
        let defaults = UserDefaults.standard
        let method = defaults.string(forKey: UDKey.calculationMethod.rawValue) ?? "muslimWorldLeague"
        let madhab = defaults.string(forKey: UDKey.madhab.rawValue) ?? "shafi"
        let parameters = PrayerSchedule.parameters(method: method, madhab: madhab)
        let now = Date()
        
        let all = PrayerSchedule.prayers(latitude: coordinates.latitude, longitude: coordinates.longitude,
                                         parameters: parameters, dayOffsets: 0...1, from: now)
        todayPrayers = all.filter { Calendar.current.isDate($0.time, inSameDayAs: now) }
        nextPrayer = all.first { $0.time > now }
        qiblaDirection = Qibla(coordinates: Coordinates(latitude: coordinates.latitude, longitude: coordinates.longitude)).direction
        
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
            self.store(latitude: latitude, longitude: longitude, source: .watch)
            self.refresh()
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
