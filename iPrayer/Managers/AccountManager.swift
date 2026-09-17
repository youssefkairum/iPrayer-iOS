import Foundation
import SwiftUI
import AuthenticationServices
import Combine

class AccountManager: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn") }
    }
    @Published var userName: String {
        didSet { 
            UserDefaults.standard.set(userName, forKey: UDKey.userName.rawValue)
            CloudSyncManager.shared.sync(key: "userName", value: userName)
        }
    }
    @Published var userEmail: String {
        didSet { 
            UserDefaults.standard.set(userEmail, forKey: UDKey.userEmail.rawValue)
            CloudSyncManager.shared.sync(key: "userEmail", value: userEmail)
        }
    }
    @Published var appleUserId: String {
        didSet { UserDefaults.standard.set(appleUserId, forKey: "appleUserId") }
    }
    
    static let shared = AccountManager()
    
    private init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.userName = UserDefaults.standard.string(forKey: UDKey.userName.rawValue) ?? ""
        self.userEmail = UserDefaults.standard.string(forKey: UDKey.userEmail.rawValue) ?? ""
        self.appleUserId = UserDefaults.standard.string(forKey: "appleUserId") ?? ""
    }
    
    func logout() {
        // Stop syncing BEFORE clearing the profile: the didSet observers below would otherwise push
        // empty strings to iCloud, and Apple only supplies the name/email on the very first sign-in.
        CloudSyncManager.shared.stopSyncing()
        
        isLoggedIn = false
        userName = ""
        userEmail = ""
        appleUserId = ""
    }
}
