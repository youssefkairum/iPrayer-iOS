import Foundation
import SwiftUI
import AuthenticationServices
import Combine

class AccountManager: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: UDKey.isLoggedIn.rawValue) }
    }
    @Published var userName: String {
        didSet { 
            UserDefaults.standard.set(userName, forKey: UDKey.userName.rawValue)
            CloudSyncManager.shared.sync(key: UDKey.userName.rawValue, value: userName)
        }
    }
    @Published var userEmail: String {
        didSet { 
            UserDefaults.standard.set(userEmail, forKey: UDKey.userEmail.rawValue)
            CloudSyncManager.shared.sync(key: UDKey.userEmail.rawValue, value: userEmail)
        }
    }
    @Published var appleUserId: String {
        didSet { UserDefaults.standard.set(appleUserId, forKey: UDKey.appleUserId.rawValue) }
    }
    
    static let shared = AccountManager()
    
    private init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: UDKey.isLoggedIn.rawValue)
        self.userName = UserDefaults.standard.string(forKey: UDKey.userName.rawValue) ?? ""
        self.userEmail = UserDefaults.standard.string(forKey: UDKey.userEmail.rawValue) ?? ""
        self.appleUserId = UserDefaults.standard.string(forKey: UDKey.appleUserId.rawValue) ?? ""
        
        // Sign out if the user revokes the app's Apple ID access while it is running
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logout()
        }
    }
    
    // MARK: - Sign in with Apple (shared by Onboarding and Settings)
    
    static func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    /// Applies the result of a SignInWithAppleButton. Returns true when the user is now signed in.
    @discardableResult
    func handleSignIn(_ result: Result<ASAuthorization, Error>) -> Bool {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return false }
            
            // Start iCloud sync FIRST, so a new name/email from Apple is pushed up to iCloud
            CloudSyncManager.shared.startSyncing()
            
            appleUserId = credential.user
            isLoggedIn = true
            
            // Apple only supplies these on the very first sign-in; never overwrite with blanks
            if let fullName = credential.fullName {
                let name = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { userName = name }
            }
            if let email = credential.email {
                userEmail = email
            }
            return true
            
        case .failure(let error):
            print("Sign in failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Confirms with Apple that the stored Sign in with Apple credential is still valid.
    /// Call at launch: the user can revoke access in Settings > Apple Account while the app isn't running.
    func verifyAppleCredential() {
        guard isLoggedIn, !appleUserId.isEmpty else { return }
        
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserId) { [weak self] state, _ in
            // Only an explicit revocation signs the user out. `.notFound` and errors also occur
            // transiently (offline, Simulator), and must not log a valid user out.
            guard state == .revoked else { return }
            DispatchQueue.main.async {
                self?.logout()
            }
        }
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
