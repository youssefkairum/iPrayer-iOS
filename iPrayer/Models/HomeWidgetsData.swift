import Foundation
import SwiftUI
import Combine

class HomeWidgetsData: ObservableObject {
    static let shared = HomeWidgetsData()
    
    // MARK: - Published properties
    // The streak and the daily tracker are synced through iCloud (see CloudSyncManager)
    @Published var currentStreak: Int = 0 {
        didSet {
            UserDefaults.standard.set(currentStreak, forKey: UDKey.currentStreak.rawValue)
            CloudSyncManager.shared.sync(key: UDKey.currentStreak.rawValue, value: currentStreak)
        }
    }
    
    @Published var dailyPrayersCompleted: [Bool] = [false, false, false, false, false] {
        didSet {
            UserDefaults.standard.set(dailyPrayersCompleted, forKey: UDKey.dailyPrayersCompleted.rawValue)
            CloudSyncManager.shared.sync(key: UDKey.dailyPrayersCompleted.rawValue, value: dailyPrayersCompleted)
        }
    }
    
    private var lastCompletedStreakDateStr: String {
        get { UserDefaults.standard.string(forKey: UDKey.lastCompletedStreakDate.rawValue) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: UDKey.lastCompletedStreakDate.rawValue)
            CloudSyncManager.shared.sync(key: UDKey.lastCompletedStreakDate.rawValue, value: newValue)
        }
    }
    
    private var lastTrackerDateStr: String {
        get { UserDefaults.standard.string(forKey: UDKey.lastTrackerDate.rawValue) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: UDKey.lastTrackerDate.rawValue)
            CloudSyncManager.shared.sync(key: UDKey.lastTrackerDate.rawValue, value: newValue)
        }
    }
    
    /// Day stamps are persisted and compared across devices, so they must not depend on the device's
    /// calendar or locale. A plain DateFormatter writes Hijri or Buddhist years on devices set to those calendars.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    init() {
        loadPersistedState()
        checkAndResetTracker()
    }
    
    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        let savedStreak = defaults.integer(forKey: UDKey.currentStreak.rawValue)
        
        // Only assign real changes so the UI and iCloud aren't poked for nothing
        if currentStreak != savedStreak { currentStreak = savedStreak }
        if let savedTracker = defaults.array(forKey: UDKey.dailyPrayersCompleted.rawValue) as? [Bool],
           savedTracker.count == 5, savedTracker != dailyPrayersCompleted {
            dailyPrayersCompleted = savedTracker
        }
    }
    
    /// Called by CloudSyncManager after it wrote tracker or streak values from iCloud into UserDefaults.
    func reloadFromDefaults() {
        loadPersistedState()
        checkAndResetTracker()
    }
    
    // MARK: - Logic
    
    /// Re-runs the day-change checks. Called when the app returns to the foreground,
    /// since init only runs once and the app may stay alive across midnight.
    func refreshDayState() {
        checkAndResetTracker()
    }
    
    func togglePrayer(index: Int) {
        guard index >= 0 && index < 5 else { return }
        dailyPrayersCompleted[index].toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        evaluateStreak()
    }
    
    private func checkAndResetTracker() {
        let formatter = Self.dayFormatter
        let todayStr = formatter.string(from: Date())
        
        // Reset daily booleans if it's a new day
        if lastTrackerDateStr != todayStr {
            dailyPrayersCompleted = [false, false, false, false, false]
            lastTrackerDateStr = todayStr
        }
        
        // Break streak if missed yesterday
        if lastCompletedStreakDateStr != todayStr {
            if let lastDate = formatter.date(from: lastCompletedStreakDateStr) {
                let daysDifference = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                if daysDifference > 1 {
                    currentStreak = 0 // Streak broken
                }
            } else if lastCompletedStreakDateStr == "" {
                currentStreak = 0
            }
        }
    }
    
    private func evaluateStreak() {
        let formatter = Self.dayFormatter
        let todayStr = formatter.string(from: Date())
        
        let allCompleted = dailyPrayersCompleted.allSatisfy { $0 == true }
        
        if allCompleted {
            if lastCompletedStreakDateStr != todayStr {
                currentStreak += 1
                lastCompletedStreakDateStr = todayStr
            }
        } else {
            if lastCompletedStreakDateStr == todayStr {
                currentStreak = max(0, currentStreak - 1)
                
                // Set last completed date to yesterday so it can be re-incremented if they check it again
                if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                    lastCompletedStreakDateStr = formatter.string(from: yesterday)
                } else {
                    lastCompletedStreakDateStr = ""
                }
            }
        }
    }
}
