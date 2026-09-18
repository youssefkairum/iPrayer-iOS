//
//  PhoneWatchSync.swift
//  iPrayer
//
//  The iPhone side of the Apple Watch link. Settings, the phone's location and translated prayer names
//  go to the watch as the application context (delivered even when the watch app is closed); Tasbih and
//  tracker changes made on the wrist come back and are folded into the phone's state.
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
final class PhoneWatchSync: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneWatchSync()
    
    private var pushTask: Task<Void, Never>?
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    /// Coalesces a burst of changes into one context update
    func schedulePush() {
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            pushContext()
        }
    }
    
    func pushContext() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let defaults = UserDefaults.standard
        let language = defaults.string(forKey: UDKey.appLanguage.rawValue) ?? "en"
        let config = SharedPrayerConfig.load()
        
        var payload = WatchSyncPayload.localProgress()
        payload.calculationMethod = defaults.string(forKey: UDKey.calculationMethod.rawValue) ?? "muslimWorldLeague"
        payload.madhab = defaults.string(forKey: UDKey.madhab.rawValue) ?? "shafi"
        payload.language = language
        payload.prayerNames = Dictionary(uniqueKeysWithValues: PrayerSchedule.prayerNames.map { ($0, AppTranslations.translate($0, to: language)) })
        payload.latitude = config?.latitude
        payload.longitude = config?.longitude
        
        try? WCSession.default.updateApplicationContext(payload.asContext())
    }
    
    // MARK: - Receiving from the watch
    
    private func apply(_ payload: WatchSyncPayload) {
        let touchedTracker = payload.applyProgress()
        if touchedTracker {
            HomeWidgetsData.shared.reloadFromDefaults()
        }
        // Whatever the wrist changed also goes to the other iCloud devices
        let defaults = UserDefaults.standard
        CloudSyncManager.shared.sync(key: UDKey.tasbihCount.rawValue, value: defaults.integer(forKey: UDKey.tasbihCount.rawValue))
        CloudSyncManager.shared.sync(key: UDKey.tasbihTarget.rawValue, value: defaults.integer(forKey: UDKey.tasbihTarget.rawValue))
    }
    
    // MARK: - WCSessionDelegate (nonisolated: WatchConnectivity calls these on its own queue)
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in self.pushContext() }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // A new watch was paired: start again for it
        session.activate()
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }
    
    private nonisolated func receive(_ dictionary: [String: Any]) {
        // Decode here, on the session queue: the payload is Sendable, the dictionary is not
        guard let payload = WatchSyncPayload.from(dictionary) else { return }
        Task { @MainActor in self.apply(payload) }
    }
}
