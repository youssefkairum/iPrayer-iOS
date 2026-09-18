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
    
    @AppStorage(UDKey.adhanSoundEnabled.rawValue) private var adhanSoundEnabled: Bool = true
    @AppStorage(UDKey.quranRemindersEnabled.rawValue) private var quranRemindersEnabled: Bool = true
    @AppStorage(UDKey.prePrayerReminderMinutes.rawValue) private var prePrayerReminderMinutes: Int = 0
    
    @AppStorage(UDKey.quranReciter.rawValue) private var reciterID: String = QuranReciter.default.id
    @ObservedObject private var downloads = QuranAudioDownloads.shared
    @ObservedObject private var watchLink = PhoneWatchSync.shared
    @Environment(\.openURL) private var openURL
    
    @StateObject private var accountManager = AccountManager.shared
    @State private var confirmDeleteAccount = false
    
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
                            .font(.custom("AvenirNext-Bold", size: 30))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        
                        // 1. Account Section
                        SettingsCard(title: "Account (iCloud Sync)", icon: "person.crop.circle.fill") {
                            if accountManager.isLoggedIn {
                                VStack(alignment: .leading, spacing: 6) {
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
                                            Text(accountManager.userName.isEmpty ? AppTranslations.catalogString("iCloud Account", language: appLanguage) : accountManager.userName)
                                                .font(.custom("AvenirNext-DemiBold", size: 16))
                                                .foregroundColor(.white)
                                            
                                            Text(accountManager.userEmail.isEmpty ? AppTranslations.catalogString("Connected securely", language: appLanguage) : accountManager.userEmail)
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
                                    
                                    // Account deletion (App Store guideline 5.1.1 v)
                                    Button {
                                        Haptics.warning()
                                        confirmDeleteAccount = true
                                    } label: {
                                        Label(AppTranslations.translate("Sign out and delete my data", to: appLanguage), systemImage: "trash")
                                            .font(.custom("AvenirNext-Medium", size: 13))
                                            .foregroundColor(.red.opacity(0.85))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 2)
                                    .alert(AppTranslations.translate("Delete your iPrayer data?", to: appLanguage), isPresented: $confirmDeleteAccount) {
                                        Button(AppTranslations.translate("Delete", to: appLanguage), role: .destructive) {
                                            withAnimation { accountManager.deleteAccount() }
                                        }
                                        Button(AppTranslations.translate("Cancel", to: appLanguage), role: .cancel) {}
                                    } message: {
                                        Text(AppTranslations.translate("Removes your name, email, bookmarks, reading position, Tasbih and prayer tracker from iCloud and signs you out. What is on this device stays until you delete the app. To stop using your Apple Account with iPrayer, see Settings > Apple Account > Sign in with Apple.", to: appLanguage))
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Syncs your Tasbih counts and bookmarks across your devices.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    SignInWithAppleButton(.signIn) { request in
                                        AccountManager.configure(request)
                                    } onCompletion: { result in
                                        withAnimation {
                                            _ = accountManager.handleSignIn(result)
                                        }
                                    }
                                    .signInWithAppleButtonStyle(.white)
                                    .frame(height: 40)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        
                        // 2. Calculation Section
                        SettingsCard(title: "Prayer Calculation", icon: "globe") {
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Method")
                                        .font(.custom("AvenirNext-Medium", size: 15))
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
                                                .font(.custom("AvenirNext-Medium", size: 15))
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
                                        .font(.custom("AvenirNext-Medium", size: 15))
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
                                                .font(.custom("AvenirNext-Medium", size: 15))
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
                                            .font(.custom("AvenirNext-Medium", size: 15))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.teal)
                                    }
                                }
                            }
                        }
                        
                        // Notifications Section
                        notificationsCard
                        
                        // Quran Audio Section
                        quranAudioCard
                        
                        // Apple Watch: only when a watch is paired but the app isn't on it
                        if watchLink.isPaired && !watchLink.isWatchAppInstalled {
                            appleWatchCard
                        }
                        
                        // 3. General Section (language + about)
                        SettingsCard(title: "General", icon: "info.circle.fill") {
                            VStack(spacing: 6) {
                            HStack {
                                Text("App Language")
                                    .font(.custom("AvenirNext-Medium", size: 15))
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
                                            .font(.custom("AvenirNext-Medium", size: 15))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.teal)
                                }
                            }
                                
                                Divider().background(Color.white.opacity(0.2))
                                
                                NavigationLink(destination: AboutView()) {
                                    HStack {
                                        Text("App Version & Info")
                                            .font(.custom("AvenirNext-Medium", size: 15))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(appVersion)
                                            .font(.custom("AvenirNext-Medium", size: 15))
                                            .foregroundColor(.gray)
                                        Image(systemName: "chevron.forward")
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
                                            .font(.custom("AvenirNext-Medium", size: 15))
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
                                            .font(.custom("AvenirNext-Medium", size: 15))
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
        .onChange(of: adhanSoundEnabled) { _, _ in
            viewModel.forceReschedule()
        }
        .onChange(of: prePrayerReminderMinutes) { _, _ in
            viewModel.forceReschedule()
        }
        .onChange(of: quranRemindersEnabled) { _, _ in
            let surahName = UserDefaults.standard.string(forKey: UDKey.lastReadSurahEnglish.rawValue)
            NotificationManager.shared.scheduleQuranReminders(surahName: surahName)
        }
        .onChange(of: appLanguage) { _, newValue in
            viewModel.refreshPrayers()
            CloudSyncManager.shared.sync(key: "appLanguage", value: newValue)
        }
    }
    
    // MARK: - Notifications Card
    
    private func reminderLabel(for minutes: Int) -> String {
        minutes == 0
            ? AppTranslations.translate("Off", to: appLanguage)
            : String(format: AppTranslations.minutesFormat("%lld min before", minutes: minutes, language: appLanguage), minutes)
    }
    
    private var notificationsCard: some View {
        SettingsCard(title: AppTranslations.translate("Notifications", to: appLanguage), icon: "bell.badge.fill") {
            VStack(spacing: 6) {
                Toggle(isOn: $adhanSoundEnabled) {
                    Text(AppTranslations.translate("Adhan Sound", to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundColor(.white)
                }
                .tint(.teal)
                
                Divider().background(Color.white.opacity(0.2))
                
                HStack {
                    Text(AppTranslations.translate("Pre-Prayer Reminder", to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Menu {
                        Picker("", selection: $prePrayerReminderMinutes) {
                            ForEach([0, 5, 10, 15, 30], id: \.self) { minutes in
                                Text(reminderLabel(for: minutes)).tag(minutes)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(reminderLabel(for: prePrayerReminderMinutes))
                                .font(.custom("AvenirNext-Medium", size: 15))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.teal)
                    }
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                Toggle(isOn: $quranRemindersEnabled) {
                    Text(AppTranslations.catalogString("Daily Quran Reminder", language: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundColor(.white)
                }
                .tint(.teal)
            }
        }
    }
    
    // MARK: - Apple Watch Card
    
    private var appleWatchCard: some View {
        SettingsCard(title: "Apple Watch", icon: "applewatch") {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppTranslations.translate("iPrayer isn't on your Apple Watch yet. Install it from the Watch app, under Available Apps.", to: appLanguage))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button {
                    Haptics.tap()
                    // Opens Apple's Watch app on the iPhone, where the app can be installed
                    if let url = URL(string: "itms-watchs://") { openURL(url) }
                } label: {
                    HStack {
                        Text(AppTranslations.translate("Open the Watch app", to: appLanguage))
                            .font(.custom("AvenirNext-Medium", size: 15))
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
    
    // MARK: - Quran Audio Card
    
    private var quranAudioCard: some View {
        SettingsCard(title: AppTranslations.translate("Quran Audio", to: appLanguage), icon: "headphones") {
            VStack(spacing: 6) {
                HStack {
                    Text(AppTranslations.translate("Reciter", to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Menu {
                        Picker("", selection: $reciterID) {
                            ForEach(QuranReciter.all) { reciter in
                                Text(reciter.name(for: appLanguage)).tag(reciter.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(QuranReciter.with(id: reciterID).name(for: appLanguage))
                                .font(.custom("AvenirNext-Medium", size: 15))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.teal)
                    }
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                if downloads.totalBytes > 0 {
                    // One row: the size is the link to the storage manager
                    NavigationLink(destination: AudioStorageView()) {
                        HStack {
                            Text(AppTranslations.translate("Downloaded Audio", to: appLanguage))
                                .font(.custom("AvenirNext-Medium", size: 15))
                                .foregroundColor(.white)
                            Spacer()
                            Text(downloads.formattedTotalSize)
                                .font(.custom("AvenirNext-Medium", size: 15))
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.forward")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Text(AppTranslations.translate("Download surahs from the reader to listen offline.", to: appLanguage))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { downloads.rescan() }
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
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundColor(.teal)
            }
            .padding(.bottom, 2)
            
            content
        }
        .padding(.vertical, 10)
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
