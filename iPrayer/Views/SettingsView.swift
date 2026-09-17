//
//  SettingsView.swift
//  iPrayer
//

import SwiftUI
import AuthenticationServices
import StoreKit

struct SettingsView: View {
    // 1. Persist settings automatically using AppStorage
    @AppStorage(UDKey.calculationMethod.rawValue) private var calculationMethodValue: String = "muslimWorldLeague"
    @AppStorage(UDKey.madhab.rawValue) private var madhabValue: String = "shafi" // 'shafi' is Standard (Maliki, Hanbali, Shafi)
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    @StateObject private var accountManager = AccountManager.shared
    
    @EnvironmentObject var viewModel: PrayerViewModel
    @Environment(\.requestReview) var requestReview
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.custom("AvenirNext-Bold", size: 34))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        
                        // 1. Account Section
                        SettingsCard(title: "Account (iCloud Sync)", icon: "person.crop.circle.fill") {
                            if accountManager.isLoggedIn {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Signed in securely with Apple")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    HStack(spacing: 15) {
                                        // Profile Picture (Initials Avatar or Apple Logo)
                                        ZStack {
                                            Circle()
                                                .fill(Color.teal.opacity(0.2))
                                                .frame(width: 45, height: 45)
                                            
                                            if accountManager.userName.isEmpty {
                                                Image(systemName: "applelogo")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.teal)
                                            } else {
                                                Text(getInitials(name: accountManager.userName))
                                                    .font(.custom("AvenirNext-Bold", size: 18))
                                                    .foregroundColor(.teal)
                                            }
                                        }
                                        
                                        // Name and Email
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(accountManager.userName.isEmpty ? String(localized: "iCloud Account") : accountManager.userName)
                                                .font(.custom("AvenirNext-DemiBold", size: 16))
                                                .foregroundColor(.white)
                                            
                                            Text(accountManager.userEmail.isEmpty ? String(localized: "Connected securely") : accountManager.userEmail)
                                                .font(.custom("AvenirNext-Medium", size: 13))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Compact Sign Out Button
                                        Button(action: {
                                            withAnimation {
                                                accountManager.logout()
                                            }
                                        }) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.red)
                                                .padding(10)
                                                .background(Color.red.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Sign in to automatically sync your Tasbih counts and bookmarks across all your Apple devices.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    SignInWithAppleButton(.signIn) { request in
                                        request.requestedScopes = [.fullName, .email]
                                    } onCompletion: { result in
                                        switch result {
                                        case .success(let authorization):
                                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                                
                                                // Start iCloud Sync FIRST, so that any new name/email we get from Apple is pushed UP to iCloud
                                                CloudSyncManager.shared.startSyncing()
                                                
                                                withAnimation {
                                                    accountManager.appleUserId = appleIDCredential.user
                                                    accountManager.isLoggedIn = true
                                                    
                                                    if let fullName = appleIDCredential.fullName {
                                                        let given = fullName.givenName ?? ""
                                                        let family = fullName.familyName ?? ""
                                                        let name = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                                                        if !name.isEmpty {
                                                            accountManager.userName = name
                                                        }
                                                    }
                                                    if let email = appleIDCredential.email {
                                                        accountManager.userEmail = email
                                                    }
                                                }
                                            }
                                        case .failure(let error):
                                            print("Sign in failed: \(error.localizedDescription)")
                                        }
                                    }
                                    .signInWithAppleButtonStyle(.white)
                                    .frame(height: 45)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        
                        // 2. Calculation Section
                        SettingsCard(title: "Prayer Calculation", icon: "globe") {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Method")
                                        .font(.custom("AvenirNext-Medium", size: 16))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Menu {
                                        Picker("Method", selection: $calculationMethodValue) {
                                            Text("Muslim World League").tag("muslimWorldLeague")
                                            Text("Egyptian General Authority").tag("egyptian")
                                            Text("Karachi").tag("karachi")
                                            Text("Umm Al-Qura").tag("ummAlQura")
                                            Text("Dubai").tag("dubai")
                                            Text("ISNA").tag("northAmerica")
                                            Text("Kuwait").tag("kuwait")
                                            Text("Qatar").tag("qatar")
                                            Text("Singapore").tag("singapore")
                                            Text("Turkey").tag("turkey")
                                            Text("Tehran").tag("tehran")
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(methodName(for: calculationMethodValue))
                                                .font(.custom("AvenirNext-Medium", size: 16))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.teal)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.2))
                                
                                HStack {
                                    Text("Madhab (Asr)")
                                        .font(.custom("AvenirNext-Medium", size: 16))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Menu {
                                        Picker("Madhab", selection: $madhabValue) {
                                            Text("Standard").tag("shafi")
                                            Text("Hanafi").tag("hanafi")
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(madhabName(for: madhabValue))
                                                .font(.custom("AvenirNext-Medium", size: 16))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.teal)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.2))
                                
                                Button(action: {
                                    viewModel.updateLocation()
                                }) {
                                    HStack {
                                        Text("Refresh Location Data")
                                            .font(.custom("AvenirNext-Medium", size: 16))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.teal)
                                    }
                                }
                            }
                        }
                        
                        // 2. Language Section
                        SettingsCard(title: "Language", icon: "character.book.closed.fill") {
                            HStack {
                                Text("App Language")
                                    .font(.custom("AvenirNext-Medium", size: 16))
                                    .foregroundColor(.white)
                                Spacer()
                                Menu {
                                    Picker("Language", selection: $appLanguage) {
                                        Text("English").tag("en")
                                        Text("العربية (Arabic)").tag("ar")
                                        Text("اردو (Urdu)").tag("ur")
                                        Text("Français (French)").tag("fr")
                                        Text("中文 (Chinese)").tag("zh-Hans")
                                        Text("Deutsch (German)").tag("de")
                                        Text("हिन्दी (Hindi)").tag("hi")
                                        Text("Türkçe (Turkish)").tag("tr")
                                        Text("Русский (Russian)").tag("ru")
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(languageName(for: appLanguage))
                                            .font(.custom("AvenirNext-Medium", size: 16))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.teal)
                                }
                            }
                        }
                        

                        // 3. About Section
                        SettingsCard(title: "About", icon: "info.circle.fill") {
                            VStack(spacing: 10) {
                                NavigationLink(destination: AboutView()) {
                                    HStack {
                                        Text("App Version & Info")
                                            .font(.custom("AvenirNext-Medium", size: 16))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(appVersion)
                                            .font(.custom("AvenirNext-Medium", size: 16))
                                            .foregroundColor(.gray)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.2))
                                
                                Button(action: {
                                    requestReview()
                                }) {
                                    HStack {
                                        Text("Rate iPrayer")
                                            .font(.custom("AvenirNext-Medium", size: 16))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.2))
                                
                                Button(action: {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Text(AppTranslations.translate("Manage Notifications & Location", to: appLanguage))
                                            .font(.custom("AvenirNext-Medium", size: 16))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 95) // Space for TabBar
                }
                }
            }
            .navigationBarHidden(true)
        .onChange(of: calculationMethodValue) { _, newValue in
            viewModel.refreshPrayers()
            CloudSyncManager.shared.sync(key: "calculationMethod", value: newValue)
        }
        .onChange(of: madhabValue) { _, newValue in
            viewModel.refreshPrayers()
            CloudSyncManager.shared.sync(key: "madhab", value: newValue)
        }
        .onChange(of: appLanguage) { _, newValue in
            viewModel.refreshPrayers()
            CloudSyncManager.shared.sync(key: "appLanguage", value: newValue)
        }
    }
    
    // MARK: - Helpers
    private func getInitials(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "AU" }
        
        let components = trimmed.components(separatedBy: " ")
        if components.count > 1 {
            let first = components[0].prefix(1)
            let last = components.last?.prefix(1) ?? ""
            return String(first + last).uppercased()
        } else if components.count == 1 {
            return String(components[0].prefix(1)).uppercased()
        }
        return "AU"
    }
    
    private func methodName(for value: String) -> LocalizedStringKey {
        switch value {
        case "muslimWorldLeague": return "Muslim World League"
        case "egyptian": return "Egyptian General Authority"
        case "karachi": return "Karachi"
        case "ummAlQura": return "Umm Al-Qura"
        case "dubai": return "Dubai"
        case "northAmerica": return "ISNA"
        case "kuwait": return "Kuwait"
        case "qatar": return "Qatar"
        case "singapore": return "Singapore"
        case "turkey": return "Turkey"
        case "tehran": return "Tehran"
        default: return "Muslim World League"
        }
    }
    
    private func madhabName(for value: String) -> LocalizedStringKey {
        return value == "hanafi" ? "Hanafi" : "Standard"
    }
    
    private func languageName(for value: String) -> String {
        switch value {
        case "en": return "English"
        case "ar": return "العربية (Arabic)"
        case "ur": return "اردو (Urdu)"
        case "fr": return "Français (French)"
        case "zh-Hans": return "中文 (Chinese)"
        case "de": return "Deutsch (German)"
        case "hi": return "हिन्दी (Hindi)"
        case "tr": return "Türkçe (Turkish)"
        case "ru": return "Русский (Russian)"
        default: return "English"
        }
    }
}

// MARK: - Subcomponents

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.teal)
                Text(LocalizedStringKey(title))
                    .font(.custom("AvenirNext-DemiBold", size: 17))
                    .foregroundColor(.teal)
            }
            .padding(.bottom, 2)
            
            content
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .background(Material.ultraThinMaterial)
        .cornerRadius(25)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
