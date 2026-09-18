//
//  OnboardingView.swift
//  iPrayer
//
//  Four steps: welcome, what the app does, location (asked here, next to the reason, never at launch),
//  and Sign in with Apple. One scaffold holds the progress, the language menu and the controls, so the
//  pages only carry content and the buttons never jump between steps.
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @AppStorage(UDKey.hasSeenOnboarding.rawValue) private var hasSeenOnboarding: Bool = false
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @EnvironmentObject var viewModel: PrayerViewModel
    @StateObject private var accountManager = AccountManager.shared
    @State private var currentTab = OnboardingView.initialSlide
    @State private var revealed = false
    
    private static let stepCount = 4
    
    private static var initialSlide: Int {
        #if DEBUG
        // Debug-only: `-debugOnboardingSlide 2` as a launch argument starts on that slide, for screenshots and UI checks
        return UserDefaults.standard.integer(forKey: "debugOnboardingSlide")
        #else
        return 0
        #endif
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            BackgroundPatternView()
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                topBar
                
                // Each slide plays its entrance once, when first reached, and stays put afterwards: fading a
                // page out while the next slides in made the change feel rough.
                TabView(selection: $currentTab) {
                    WelcomeSlide(shown: revealed).tag(0)
                    FeaturesSlide(shown: currentTab >= 1).tag(1)
                    LocationSlide(shown: currentTab >= 2).tag(2)
                    SyncSlide(shown: currentTab >= 3).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentTab) { _, _ in Haptics.selection() }
                
                // Fixed height whatever the step shows, so the page area never resizes during a swipe;
                // the buttons crossfade instead of popping.
                ZStack(alignment: .top) {
                    controls
                        .id(currentTab)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: currentTab)
                .frame(height: 104, alignment: .top)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
        .onAppear { revealed = true }
    }
    
    // MARK: - Top: progress and language
    
    private var topBar: some View {
        HStack(alignment: .center) {
            // Step progress: the current step is the long capsule
            HStack(spacing: 6) {
                ForEach(0..<Self.stepCount, id: \.self) { step in
                    Capsule()
                        .fill(step == currentTab ? Color.teal : Color.white.opacity(step < currentTab ? 0.5 : 0.18))
                        .frame(width: step == currentTab ? 26 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentTab)
                }
            }
            
            Spacer()
            
            Menu {
                Picker("Language", selection: $appLanguage) {
                    Text("🇺🇸 English").tag("en")
                    Text("🇸🇦 العربية (Arabic)").tag("ar")
                    Text("🇫🇷 Français (French)").tag("fr")
                    Text("🇩🇪 Deutsch (German)").tag("de")
                    Text("🇮🇳 हिन्दी (Hindi)").tag("hi")
                    Text("🇷🇺 Русский (Russian)").tag("ru")
                    Text("🇹🇷 Türkçe (Turkish)").tag("tr")
                    Text("🇵🇰 اردو (Urdu)").tag("ur")
                    Text("🇨🇳 中文 (Chinese)").tag("zh-Hans")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(flag(for: appLanguage))
                        .font(.title3)
                    Text(languageName(for: appLanguage))
                        .font(.custom("AvenirNext-DemiBold", size: 13))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
    
    // MARK: - Bottom: the step's actions
    
    @ViewBuilder
    private var controls: some View {
        switch currentTab {
        case 0, 1:
            primaryButton(AppTranslations.translate("Continue", to: appLanguage)) { advance() }
        case 2:
            VStack(spacing: 12) {
                let asksPermission = viewModel.locationAuthorization == .notDetermined
                primaryButton(AppTranslations.translate(asksPermission ? "Enable Location" : "Continue", to: appLanguage)) {
                    if asksPermission { viewModel.requestLocationAccess() }
                    advance()
                }
                if asksPermission {
                    secondaryButton(AppTranslations.translate("Not now", to: appLanguage)) { advance() }
                }
            }
        default:
            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    AccountManager.configure(request)
                } onCompletion: { result in
                    if accountManager.handleSignIn(result) {
                        finishOnboarding()
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                secondaryButton(AppTranslations.catalogString("Skip for now", language: appLanguage)) { finishOnboarding() }
            }
        }
    }
    
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.custom("AvenirNext-Bold", size: 17))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .glassEffect(.regular.tint(.teal).interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("AvenirNext-Medium", size: 15))
                .foregroundColor(.white.opacity(0.7))
                .frame(height: 36)
        }
    }
    
    private func advance() {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentTab = min(currentTab + 1, Self.stepCount - 1)
        }
    }
    
    private func finishOnboarding() {
        Haptics.success()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            hasSeenOnboarding = true
        }
    }
    
    private func flag(for lang: String) -> String {
        switch lang {
        case "ar": return "🇸🇦"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "hi": return "🇮🇳"
        case "ru": return "🇷🇺"
        case "tr": return "🇹🇷"
        case "ur": return "🇵🇰"
        case "zh-Hans": return "🇨🇳"
        default: return "🇺🇸"
        }
    }
    
    private func languageName(for lang: String) -> String {
        switch lang {
        case "ar": return "العربية"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "hi": return "हिन्दी"
        case "ru": return "Русский"
        case "tr": return "Türkçe"
        case "ur": return "اردو"
        case "zh-Hans": return "中文"
        default: return "English"
        }
    }
}

// MARK: - Slides

private struct WelcomeSlide: View {
    let shown: Bool
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Group {
                if let icon = Bundle.main.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .frame(width: 104, height: 104)
                        .background(Color.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .shadow(color: .teal.opacity(0.45), radius: 28, x: 0, y: 10)
            .scaleEffect(shown ? 1 : 0.8)
            .opacity(shown ? 1 : 0)
            .animation(.spring(response: 0.7, dampingFraction: 0.7), value: shown)
            
            VStack(spacing: 12) {
                Text("Welcome to iPrayer")
                    .font(.custom("AvenirNext-Bold", size: 32))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Your premium companion for daily prayers, Tasbih, and Quran reading.")
                    .font(.custom("AvenirNext-Medium", size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .entrance(1, shown: shown)
            
            // A day of prayers, in the colours the app uses for them
            HStack(spacing: 10) {
                ForEach(PrayerSchedule.prayerNames, id: \.self) { prayer in
                    Image(systemName: PrayerSchedule.icon(for: prayer))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(PrayerPalette.palette(for: prayer).gradient)
                        .clipShape(Circle())
                }
            }
            .entrance(2, shown: shown)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct FeaturesSlide: View {
    let shown: Bool
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    private var features: [(icon: String, prayer: String, title: String, description: String)] {
        [
            ("clock.fill", "Dhuhr", AppTranslations.catalogString("Accurate Prayers", language: appLanguage),
             AppTranslations.catalogString("Get precise prayer times based on your location and calculation method.", language: appLanguage)),
            ("book.fill", "Asr", AppTranslations.catalogString("The Holy Quran", language: appLanguage),
             AppTranslations.translate("Read the mushaf page by page and listen to six reciters, online or offline.", to: appLanguage)),
            ("hands.and.sparkles.fill", "Fajr", AppTranslations.translate("Duas & Tasbih", to: appLanguage),
             AppTranslations.translate("Authentic duas with their sources, and a haptic Tasbih that syncs to your watch.", to: appLanguage)),
            ("apps.iphone", "Maghrib", AppTranslations.translate("Widgets & Apple Watch", to: appLanguage),
             AppTranslations.translate("The next prayer and a Verse of the Day on your Home Screen, Lock Screen and wrist.", to: appLanguage)),
            ("safari.fill", "Isha", AppTranslations.catalogString("Qibla Compass", language: appLanguage),
             AppTranslations.translate("Find the direction of the Kaaba wherever you are.", to: appLanguage))
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(PrayerPalette.palette(for: feature.prayer).gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.custom("AvenirNext-Bold", size: 17))
                                .foregroundColor(.white)
                            Text(feature.description)
                                .font(.custom("AvenirNext-Medium", size: 13))
                                .foregroundColor(.white.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .entrance(index, shown: shown)
                }
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 8)
        }
    }
}

private struct LocationSlide: View {
    let shown: Bool
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    var body: some View {
        PermissionSlide(
            shown: shown,
            icon: "location.fill",
            tint: .teal,
            title: AppTranslations.translate("Location Access", to: appLanguage),
            message: AppTranslations.translate("iPrayer uses your location to calculate prayer times and the Qibla direction.", to: appLanguage),
            points: [
                ("clock.fill", AppTranslations.translate("Prayer Times", to: appLanguage)),
                ("safari.fill", AppTranslations.catalogString("Qibla Compass", language: appLanguage))
            ]
        )
    }
}

private struct SyncSlide: View {
    let shown: Bool
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    var body: some View {
        PermissionSlide(
            shown: shown,
            icon: "icloud.fill",
            tint: .blue,
            title: AppTranslations.catalogString("Secure Cloud Sync", language: appLanguage),
            message: AppTranslations.translate("Back up your Tasbih counts, bookmarks and progress to your own iCloud. iPrayer runs no servers of its own.", to: appLanguage),
            points: [
                ("circle.grid.cross.fill", AppTranslations.translate("Tasbih", to: appLanguage)),
                ("bookmark.fill", AppTranslations.translate("Bookmarks", to: appLanguage)),
                ("flame.fill", AppTranslations.translate("Tracker", to: appLanguage))
            ]
        )
    }
}

/// Icon in a glass disc, a title, one explaining sentence, and a short list of what it covers
private struct PermissionSlide: View {
    let shown: Bool
    let icon: String
    let tint: Color
    let title: String
    let message: String
    let points: [(String, String)]
    
    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 112, height: 112)
                .glassEffect(.regular, in: .circle)
                .shadow(color: tint.opacity(0.4), radius: 24, x: 0, y: 8)
                .scaleEffect(shown ? 1 : 0.8)
                .opacity(shown ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.7), value: shown)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.custom("AvenirNext-Bold", size: 30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .entrance(1, shown: shown)
            
            HStack(spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Label(point.1, systemImage: point.0)
                        .font(.custom("AvenirNext-DemiBold", size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                }
            }
            .entrance(2, shown: shown)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
