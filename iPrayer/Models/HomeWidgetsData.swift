import Foundation
import SwiftUI
import Combine
#if os(watchOS)
import WatchKit
#endif

class HomeWidgetsData: ObservableObject {
    static let shared = HomeWidgetsData()
    
    // MARK: - Published properties
    // The streak and the daily tracker are synced through iCloud (see CloudSyncManager)
    @Published var currentStreak: Int = 0 {
        didSet {
            UserDefaults.standard.set(currentStreak, forKey: UDKey.currentStreak.rawValue)
            share(key: UDKey.currentStreak.rawValue, value: currentStreak)
        }
    }
    
    @Published var dailyPrayersCompleted: [Bool] = [false, false, false, false, false] {
        didSet {
            UserDefaults.standard.set(dailyPrayersCompleted, forKey: UDKey.dailyPrayersCompleted.rawValue)
            share(key: UDKey.dailyPrayersCompleted.rawValue, value: dailyPrayersCompleted)
        }
    }
    
    private var lastCompletedStreakDateStr: String {
        get { UserDefaults.standard.string(forKey: UDKey.lastCompletedStreakDate.rawValue) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: UDKey.lastCompletedStreakDate.rawValue)
            share(key: UDKey.lastCompletedStreakDate.rawValue, value: newValue)
        }
    }
    
    private var lastTrackerDateStr: String {
        get { UserDefaults.standard.string(forKey: UDKey.lastTrackerDate.rawValue) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: UDKey.lastTrackerDate.rawValue)
            share(key: UDKey.lastTrackerDate.rawValue, value: newValue)
        }
    }
    
    /// The phone sends changes to iCloud and the watch; the watch sends them to the phone.
    private func share(key: String, value: Any) {
        #if os(iOS)
        CloudSyncManager.shared.sync(key: key, value: value)
        PhoneWatchSync.shared.schedulePush()
        #elseif os(watchOS)
        WatchSync.shared.schedulePush()
        #endif
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
    
    private var observers: [NSObjectProtocol] = []
    
    init() {
        loadPersistedState()
        checkAndResetTracker()
        
        // The day can change while the app is alive (open, or suspended for days). Listen here, in the
        // model, so the reset never depends on which screen happens to be showing.
        var names: [Notification.Name] = [.NSCalendarDayChanged]
        #if os(iOS)
        names.append(UIApplication.willEnterForegroundNotification)
        #elseif os(watchOS)
        names.append(WKApplication.willEnterForegroundNotification)
        #endif
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkAndResetTracker() }
            })
        }
    }
    
    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        let savedStreak = defaults.integer(forKey: UDKey.currentStreak.rawValue)
        
        // Only assign real changes so the UI and iCloud aren't poked for nothing
        if currentStreak != savedStreak { currentStreak = savedStreak }
        
        // A saved tracker only counts if it is today's. Adopting yesterday's ticks here, even for a moment,
        // republished them to iCloud and the watch before the day check ran.
        if lastTrackerDateStr == Self.dayFormatter.string(from: Date()),
           let savedTracker = defaults.array(forKey: UDKey.dailyPrayersCompleted.rawValue) as? [Bool],
           savedTracker.count == 5, savedTracker != dailyPrayersCompleted {
            dailyPrayersCompleted = savedTracker
        }
    }
    
    /// Today's tracker as another device left it in iCloud, if any. Starting a new day from it, rather than
    /// from blanks, stops a device that wakes up late from wiping progress already made today.
    private static func todaysTrackerFromCloud(_ today: String) -> [Bool]? {
        #if os(iOS)
        let store = NSUbiquitousKeyValueStore.default
        guard store.string(forKey: UDKey.lastTrackerDate.rawValue) == today,
              let tracker = store.array(forKey: UDKey.dailyPrayersCompleted.rawValue) as? [Bool],
              tracker.count == 5 else { return nil }
        return tracker
        #else
        return nil
        #endif
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
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
        evaluateStreak()
    }
    
    private func checkAndResetTracker() {
        let formatter = Self.dayFormatter
        let todayStr = formatter.string(from: Date())
        
        // New day: start from today's progress on another device if iCloud has it, otherwise blank
        if lastTrackerDateStr != todayStr {
            lastTrackerDateStr = todayStr
            dailyPrayersCompleted = Self.todaysTrackerFromCloud(todayStr) ?? [false, false, false, false, false]
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
