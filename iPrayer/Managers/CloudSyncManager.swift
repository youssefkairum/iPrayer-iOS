import Foundation

class CloudSyncManager {
    static let shared = CloudSyncManager()
    
    private let store = NSUbiquitousKeyValueStore.default
    
    private let stringKeys = [
        UDKey.calculationMethod.rawValue,
        UDKey.madhab.rawValue,
        UDKey.appLanguage.rawValue,
        UDKey.lastReadSurahName.rawValue,
        UDKey.lastReadSurahEnglish.rawValue,
        UDKey.userName.rawValue,
        UDKey.userEmail.rawValue,
        UDKey.lastTrackerDate.rawValue,
        UDKey.lastCompletedStreakDate.rawValue,
        UDKey.quranBookmarks.rawValue
    ]
    private let intKeys = [
        UDKey.tasbihCount.rawValue,
        UDKey.tasbihTarget.rawValue,
        UDKey.lastReadSurahNumber.rawValue,
        UDKey.lastReadVerse.rawValue,
        UDKey.currentStreak.rawValue
    ]
    private let boolArrayKeys = [
        UDKey.dailyPrayersCompleted.rawValue
    ]
    
    /// Keys that HomeWidgetsData keeps in memory; it has to be told when they change underneath it.
    private let trackerKeys: Set<String> = [
        UDKey.dailyPrayersCompleted.rawValue,
        UDKey.lastTrackerDate.rawValue,
        UDKey.currentStreak.rawValue,
        UDKey.lastCompletedStreakDate.rawValue
    ]
    
    private(set) var isSyncing = false
    
    private init() {
        // Listen to iCloud -> UserDefaults changes
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudDataDidChange(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
    }
    
    func startSyncing() {
        guard !isSyncing else { return }
        isSyncing = true
        
        // First, explicitly pull existing data from iCloud to local
        pullCloudToLocal()
        
        // Then, push any local default values to cloud ONLY if the cloud doesn't have them yet
        pushLocalToCloud()
        store.synchronize()
    }
    
    func stopSyncing() {
        isSyncing = false
    }
    
    /// Removes everything the app ever put in iCloud (profile, settings, progress, tracker) and stops
    /// syncing, so the next local change cannot push any of it back up. Used by account deletion.
    func eraseCloudData() {
        isSyncing = false
        for key in stringKeys + intKeys + boolArrayKeys {
            store.removeObject(forKey: key)
        }
        store.synchronize()
    }
    
    // Explicitly push a value to the cloud when it changes locally
    func sync(key: String, value: Any) {
        guard isSyncing else { return }
        
        // Skip unchanged values. This also prevents loops where an incoming iCloud change
        // updates local state, whose observers then try to push the same value back.
        if let existing = store.object(forKey: key) as? NSObject, let new = value as? NSObject, existing.isEqual(new) {
            return
        }
        
        store.set(value, forKey: key)
        store.synchronize()
    }
    
    // MARK: - Cloud -> Local
    
    /// The tracker and the streak are each a (value, date) pair. A pair from iCloud is only accepted
    /// when its date is at least as recent as the local one, so an older device can't undo today's progress.
    /// Dates are stored as yyyy-MM-dd, so string comparison orders them correctly.
    private func shouldAcceptCloudValue(for key: String) -> Bool {
        let dateKey: String
        switch key {
        case UDKey.dailyPrayersCompleted.rawValue, UDKey.lastTrackerDate.rawValue:
            dateKey = UDKey.lastTrackerDate.rawValue
        case UDKey.currentStreak.rawValue, UDKey.lastCompletedStreakDate.rawValue:
            dateKey = UDKey.lastCompletedStreakDate.rawValue
        default:
            return true
        }
        let cloudDate = store.string(forKey: dateKey) ?? ""
        let localDate = UserDefaults.standard.string(forKey: dateKey) ?? ""
        return cloudDate >= localDate
    }
    
    /// Copies the given keys from iCloud into UserDefaults. Returns true if a tracker key was written.
    @discardableResult
    private func applyCloudValues(for keys: [String]) -> Bool {
        let defaults = UserDefaults.standard
        
        // Decide per pair BEFORE writing anything, otherwise accepting the date first
        // would change the outcome for the value that belongs to it.
        let accepted = keys.filter { shouldAcceptCloudValue(for: $0) }
        var touchedTracker = false
        
        for key in accepted {
            if stringKeys.contains(key) {
                guard let cloudVal = store.string(forKey: key) else { continue }
                
                let isProfileKey = key == UDKey.userName.rawValue || key == UDKey.userEmail.rawValue
                // NEVER let iCloud overwrite the name or email with a blank string
                if isProfileKey && cloudVal.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }
                
                defaults.set(cloudVal, forKey: key)
                
                if key == UDKey.quranBookmarks.rawValue {
                    // The bookmarks store keeps its list in memory
                    DispatchQueue.main.async { QuranBookmarks.shared.reload() }
                }
                
                if isProfileKey {
                    // AccountManager is observed by the UI, so update it on the main thread
                    DispatchQueue.main.async {
                        if key == UDKey.userName.rawValue { AccountManager.shared.userName = cloudVal }
                        if key == UDKey.userEmail.rawValue { AccountManager.shared.userEmail = cloudVal }
                    }
                }
            } else if intKeys.contains(key) {
                guard store.object(forKey: key) != nil else { continue }
                defaults.set(Int(store.longLong(forKey: key)), forKey: key)
            } else if boolArrayKeys.contains(key) {
                guard var cloudVal = store.array(forKey: key) as? [Bool] else { continue }
                // Same day on both devices: a prayer ticked on either stays ticked
                if key == UDKey.dailyPrayersCompleted.rawValue,
                   store.string(forKey: UDKey.lastTrackerDate.rawValue) == defaults.string(forKey: UDKey.lastTrackerDate.rawValue),
                   let local = defaults.array(forKey: key) as? [Bool], local.count == cloudVal.count {
                    cloudVal = zip(cloudVal, local).map { $0 || $1 }
                }
                defaults.set(cloudVal, forKey: key)
            } else {
                continue
            }
            
            if trackerKeys.contains(key) { touchedTracker = true }
        }
        
        if touchedTracker {
            DispatchQueue.main.async {
                HomeWidgetsData.shared.reloadFromDefaults()
            }
        }
        return touchedTracker
    }
    
    private func pullCloudToLocal() {
        applyCloudValues(for: stringKeys + intKeys + boolArrayKeys)
    }
    
    @objc private func iCloudDataDidChange(_ notification: Notification) {
        guard isSyncing else { return }
        guard let userInfo = notification.userInfo else { return }
        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        
        applyCloudValues(for: changedKeys)
    }
    
    // MARK: - Local -> Cloud
    
    private func pushLocalToCloud() {
        let defaults = UserDefaults.standard
        
        for key in stringKeys {
            // Only push local if iCloud is empty for this key
            if store.object(forKey: key) == nil {
                if let val = defaults.string(forKey: key) {
                    store.set(val, forKey: key)
                }
            }
        }
        for key in intKeys {
            if store.object(forKey: key) == nil {
                // If local value doesn't explicitly exist yet, ensure we push safe defaults
                if defaults.object(forKey: key) != nil {
                    let val = defaults.integer(forKey: key)
                    store.set(val, forKey: key)
                } else {
                    if key == UDKey.tasbihTarget.rawValue {
                        store.set(Int64(33), forKey: key)
                    } else {
                        store.set(Int64(0), forKey: key)
                    }
                }
            }
        }
        for key in boolArrayKeys {
            if store.object(forKey: key) == nil, let val = defaults.array(forKey: key) {
                store.set(val, forKey: key)
            }
        }
        store.synchronize()
    }
}
