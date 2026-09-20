//
//  OnboardingView.swift
//  iPrayer
//
//  Welcome, what the app does, location (asked here, next to the reason, never at launch), and Sign in
//  with Apple. One scaffold holds the progress, the language menu and the controls, so the pages only
//  carry content and the buttons never jump between steps.
//
//  A fifth step, offering to install the watch app, appears ONLY when a watch is paired and the app is not
//  on it — the same condition as the Settings card. For everyone else the flow is the four it always was.
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @AppStorage(UDKey.hasSeenOnboarding.rawValue) private var hasSeenOnboarding: Bool = false
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @EnvironmentObject var viewModel: PrayerViewModel
    @StateObject private var accountManager = AccountManager.shared
    @State private var currentTab = OnboardingView.initialSlide
    @ObservedObject private var entrance = AppEntrance.shared
    @ObservedObject private var watchLink = PhoneWatchSync.shared
    @Environment(\.openURL) private var openURL
    /// Whether the watch step is part of this run. `WCSession` activates at launch and answers
    /// asynchronously, so this arrives while onboarding is already on screen, and the two directions are
    /// NOT symmetric — see `setWatchStep`.
    @State private var includesWatchStep = false
    /// Pending "not installed has held long enough to believe" check; cancelled whenever the state moves.
    @State private var watchSettle: Task<Void, Never>?
    
    /// The watch step's index when it exists. Everything before it is fixed, so this is a constant.
    private static let watchTab = 3
    /// How long `paired && !installed` must HOLD before the step is added. iOS installs an embedded watch
    /// app over the air, and `isWatchAppInstalled` is false for the whole transfer — so the raw flag says
    /// "not installed" loudest for exactly the people who did nothing wrong and are about to have it.
    private static let watchSettleSeconds: Double = 6
    private var syncTab: Int { includesWatchStep ? 4 : 3 }
    private var stepCount: Int { includesWatchStep ? 5 : 4 }
    
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
                // page out while the next slides in made the change feel rough. The first slide waits for the
                // splash screen to go, so its entrance is not spent underneath it.
                TabView(selection: $currentTab) {
                    WelcomeSlide(shown: entrance.splashDismissed).tag(0)
                    FeaturesSlide(shown: currentTab >= 1).tag(1)
                    LocationSlide(shown: currentTab >= 2).tag(2)
                    if includesWatchStep {
                        WatchSlide(shown: currentTab >= Self.watchTab).tag(Self.watchTab)
                    }
                    SyncSlide(shown: currentTab >= syncTab).tag(syncTab)
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
        .onAppear { refreshWatchStep() }
        .onChange(of: watchLink.isPaired) { _, _ in refreshWatchStep() }
        .onChange(of: watchLink.isWatchAppInstalled) { _, _ in refreshWatchStep() }
        .onDisappear { watchSettle?.cancel() }
    }
    
    private func refreshWatchStep() {
        #if DEBUG
        // `-debugWatchStep 1`, for staging the step without a paired watch. Ahead of everything below so
        // `-debugOnboardingSlide 3` lands straight on it.
        if UserDefaults.standard.bool(forKey: "debugWatchStep") {
            includesWatchStep = true
            return
        }
        #endif
        watchSettle?.cancel()
        guard watchLink.isPaired, !watchLink.isWatchAppInstalled else {
            setWatchStep(false)     // a correction is believed at once
            return
        }
        // Adding waits: see `watchSettleSeconds`.
        watchSettle = Task {
            try? await Task.sleep(for: .seconds(Self.watchSettleSeconds))
            guard !Task.isCancelled,
                  watchLink.isPaired, !watchLink.isWatchAppInstalled else { return }
            setWatchStep(true)
        }
    }
    
    /// ADDING and REMOVING the step are not symmetric.
    ///
    /// Adding renumbers sign-in from tag 3 to tag 4, so it may only happen while the step is still ahead of
    /// the person — otherwise someone reading the sign-in page would find a watch prompt in its place.
    ///
    /// Removing is always allowed, including while the step is on screen. If the watch app finishes
    /// installing while they are looking at a page that says it has not, the page is now a lie, and moving
    /// them on is the honest outcome: removal can only ever carry them FORWARD onto sign-in, which is where
    /// this step was leading anyway. `currentTab` is clamped because tag 4 stops existing.
    private func setWatchStep(_ wanted: Bool) {
        guard wanted != includesWatchStep else { return }
        if wanted {
            guard currentTab < Self.watchTab else { return }
            includesWatchStep = true
        } else {
            includesWatchStep = false
            if currentTab > Self.watchTab { currentTab = Self.watchTab }
        }
    }
    
    // MARK: - Top: progress and language
    
    private var topBar: some View {
        HStack(alignment: .center) {
            // Step progress: the current step is the long capsule
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { step in
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
        case Self.watchTab where includesWatchStep:
            VStack(spacing: 12) {
                // Advances before leaving, as the location step does, so coming back from the Watch app
                // lands on sign-in rather than on a prompt that has already been answered.
                primaryButton(AppTranslations.translate("Open the Watch app", to: appLanguage)) {
                    if let url = URL(string: "itms-watchs://") { openURL(url) }
                    advance()
                }
                secondaryButton(AppTranslations.translate("Not now", to: appLanguage)) { advance() }
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
            currentTab = min(currentTab + 1, stepCount - 1)
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

/// Entrance state for a slide: true only once the slide has been reached AND has rendered once, so the
/// change from hidden to shown always happens on screen and the `.animation(value:)` modifiers see it.
private struct SlideEntrance: ViewModifier {
    @Binding var appeared: Bool
    func body(content: Content) -> some View {
        content.onAppear {
            // Next run loop turn: a state change inside onAppear itself can be folded into the first render
            DispatchQueue.main.async { appeared = true }
        }
    }
}

private extension View {
    func slideEntrance(appeared: Binding<Bool>) -> some View {
        modifier(SlideEntrance(appeared: appeared))
    }
}

private struct WelcomeSlide: View {
    let shown: Bool
    @State private var appeared = false
    private var visible: Bool { shown && appeared }
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
            .scaleEffect(visible ? 1 : 0.8)
            .opacity(visible ? 1 : 0)
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
            .entrance(1, shown: visible)
            
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
            .entrance(2, shown: visible)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .slideEntrance(appeared: $appeared)
    }
}

private struct FeaturesSlide: View {
    let shown: Bool
    @State private var appeared = false
    private var visible: Bool { shown && appeared }
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
                    .entrance(index, shown: visible)
                }
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 8)
        }
        .slideEntrance(appeared: $appeared)
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

/// Offered only when a watch is paired and iPrayer is not on it — after that has held for a few seconds,
/// because an over-the-air install reports "not installed" for its whole duration.
/// Every string here is one Settings already uses, so this step added no new translation keys.
private struct WatchSlide: View {
    let shown: Bool
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    var body: some View {
        PermissionSlide(
            shown: shown,
            icon: "applewatch",
            tint: .mint,
            title: "Apple Watch",
            message: AppTranslations.translate("iPrayer isn't on your Apple Watch yet. Install it from the Watch app, under Available Apps.", to: appLanguage),
            points: [
                ("clock.fill", AppTranslations.translate("Prayer Times", to: appLanguage)),
                ("circle.grid.cross.fill", AppTranslations.translate("Tasbih", to: appLanguage)),
                ("safari.fill", AppTranslations.translate("Qibla", to: appLanguage))
            ]
        )
    }
}

/// Icon in a glass disc, a title, one explaining sentence, and a short list of what it covers
private struct PermissionSlide: View {
    let shown: Bool
    @State private var appeared = false
    private var visible: Bool { shown && appeared }
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
                .scaleEffect(visible ? 1 : 0.8)
                .opacity(visible ? 1 : 0)
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
            .entrance(1, shown: visible)
            
            HStack(spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Label(point.1, systemImage: point.0)
                        .font(.custom("AvenirNext-DemiBold", size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        // Three capsules is the widest this row gets, and the paddings do not scale with
                        // Dynamic Type while the text does. Shrink rather than truncate a translation.
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                }
            }
            .entrance(2, shown: visible)
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .slideEntrance(appeared: $appeared)
    }
}
