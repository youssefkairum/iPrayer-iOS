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
        UDKey.userEmail.rawValue
    ]
    private let intKeys = [
        UDKey.tasbihCount.rawValue,
        UDKey.tasbihTarget.rawValue,
        UDKey.lastReadSurahNumber.rawValue
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
    
    private func pullCloudToLocal() {
        let defaults = UserDefaults.standard
        
        for key in stringKeys {
            if let cloudVal = store.string(forKey: key) {
                // NEVER let iCloud overwrite the name or email with a blank string
                if (key == "userName" || key == "userEmail") && cloudVal.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }
                
                defaults.set(cloudVal, forKey: key)
                
                // Directly set the values synchronously to avoid race conditions
                if key == "userName" { AccountManager.shared.userName = cloudVal }
                if key == "userEmail" { AccountManager.shared.userEmail = cloudVal }
            }
        }
        for key in intKeys {
            if store.object(forKey: key) != nil {
                let cloudVal = Int(store.longLong(forKey: key))
                defaults.set(cloudVal, forKey: key)
            }
        }
    }
    
    func stopSyncing() {
        isSyncing = false
    }
    
    // Explicitly push a value to the cloud when it changes locally
    func sync(key: String, value: Any) {
        guard isSyncing else { return }
        
        // Prevent infinite loops if iCloud triggers local change which triggers iCloud sync
        if let existingString = store.object(forKey: key) as? String, let newString = value as? String, existingString == newString {
            return
        }
        
        store.set(value, forKey: key)
        store.synchronize()
    }
    
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
                    if key == "tasbihTarget" {
                        store.set(Int64(33), forKey: key)
                    } else {
                        store.set(Int64(0), forKey: key)
                    }
                }
            }
        }
        store.synchronize()
    }
    
    @objc private func iCloudDataDidChange(_ notification: Notification) {
        guard isSyncing else { return }
        guard let userInfo = notification.userInfo else { return }
        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        
        let defaults = UserDefaults.standard
        
        for key in changedKeys {
            if stringKeys.contains(key) {
                if let stringValue = store.string(forKey: key) {
                    defaults.set(stringValue, forKey: key)
                    
                    // Update AccountManager in memory if it's a user profile field
                    DispatchQueue.main.async {
                        if key == "userName" { AccountManager.shared.userName = stringValue }
                        if key == "userEmail" { AccountManager.shared.userEmail = stringValue }
                    }
                }
            } else if intKeys.contains(key) {
                let intValue = Int(store.longLong(forKey: key))
                defaults.set(intValue, forKey: key)
            }
        }
    }
}
