//
//  SharedWatchState.swift
//  iPrayer
//
//  Compiled into the iPhone app AND the watch app. What the two tell each other over WatchConnectivity:
//  the phone sends settings, translated names and its location; the watch sends what the wearer changed
//  on the wrist. Every field is optional so each side sends only what it owns.
//

import Foundation

nonisolated struct WatchSyncPayload: Codable, Sendable {
    static let contextKey = "iPrayerSync"
    
    var calculationMethod: String?
    var madhab: String?
    var language: String?
    /// English prayer name -> display name in the in-app language
    var prayerNames: [String: String]?
    var latitude: Double?
    var longitude: Double?
    
    var tasbihCount: Int?
    var tasbihTarget: Int?
    /// When the Tasbih was last changed by a person, so the newer side wins
    var tasbihUpdatedAt: Date?
    
    var dailyPrayersCompleted: [Bool]?
    var lastTrackerDate: String?
    var currentStreak: Int?
    var lastCompletedStreakDate: String?
    
    var sentAt = Date()
    
    /// Encoded as JSON under one key so the dictionary stays property-list safe
    func asContext() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.contextKey: data]
    }
    
    static func from(_ context: [String: Any]) -> WatchSyncPayload? {
        guard let data = context[Self.contextKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchSyncPayload.self, from: data)
    }
    
    /// Reads this device's own progress (Tasbih, tracker, streak) so it can be sent to the other side
    static func localProgress(defaults: UserDefaults = .standard) -> WatchSyncPayload {
        var payload = WatchSyncPayload()
        payload.tasbihCount = defaults.integer(forKey: UDKey.tasbihCount.rawValue)
        payload.tasbihTarget = defaults.object(forKey: UDKey.tasbihTarget.rawValue) == nil ? 33 : defaults.integer(forKey: UDKey.tasbihTarget.rawValue)
        payload.tasbihUpdatedAt = defaults.object(forKey: UDKey.tasbihUpdatedAt.rawValue) as? Date
        payload.dailyPrayersCompleted = defaults.array(forKey: UDKey.dailyPrayersCompleted.rawValue) as? [Bool]
        payload.lastTrackerDate = defaults.string(forKey: UDKey.lastTrackerDate.rawValue)
        payload.currentStreak = defaults.integer(forKey: UDKey.currentStreak.rawValue)
        payload.lastCompletedStreakDate = defaults.string(forKey: UDKey.lastCompletedStreakDate.rawValue)
        return payload
    }
    
    /// Writes the other side's progress into UserDefaults with the same rule iCloud sync uses: a
    /// (value, date) pair only replaces the local one when its date is at least as recent, and the
    /// Tasbih follows whichever side a person touched last. Returns true when a tracker key changed.
    @discardableResult
    func applyProgress(to defaults: UserDefaults = .standard) -> Bool {
        var touchedTracker = false
        
        if let tracker = dailyPrayersCompleted, tracker.count == 5, let date = lastTrackerDate,
           date >= (defaults.string(forKey: UDKey.lastTrackerDate.rawValue) ?? "") {
            let current = defaults.array(forKey: UDKey.dailyPrayersCompleted.rawValue) as? [Bool]
            if current != tracker || defaults.string(forKey: UDKey.lastTrackerDate.rawValue) != date {
                defaults.set(tracker, forKey: UDKey.dailyPrayersCompleted.rawValue)
                defaults.set(date, forKey: UDKey.lastTrackerDate.rawValue)
                touchedTracker = true
            }
        }
        if let streak = currentStreak, let date = lastCompletedStreakDate,
           date >= (defaults.string(forKey: UDKey.lastCompletedStreakDate.rawValue) ?? "") {
            if defaults.integer(forKey: UDKey.currentStreak.rawValue) != streak
                || defaults.string(forKey: UDKey.lastCompletedStreakDate.rawValue) != date {
                defaults.set(streak, forKey: UDKey.currentStreak.rawValue)
                defaults.set(date, forKey: UDKey.lastCompletedStreakDate.rawValue)
                touchedTracker = true
            }
        }
        if let updated = tasbihUpdatedAt {
            let local = defaults.object(forKey: UDKey.tasbihUpdatedAt.rawValue) as? Date ?? .distantPast
            if updated > local {
                if let count = tasbihCount { defaults.set(count, forKey: UDKey.tasbihCount.rawValue) }
                if let target = tasbihTarget { defaults.set(target, forKey: UDKey.tasbihTarget.rawValue) }
                defaults.set(updated, forKey: UDKey.tasbihUpdatedAt.rawValue)
            }
        }
        return touchedTracker
    }
}
