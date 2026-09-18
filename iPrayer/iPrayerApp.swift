//
//  iPrayerApp.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/23/25.
//

import SwiftUI
import Combine
import UserNotifications
import CoreLocation

@main
struct iPrayerApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var viewModel = PrayerViewModel()
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.hasSeenOnboarding.rawValue) private var hasSeenOnboarding: Bool = false
    
    // The KFGQPC font is registered through UIAppFonts in Info.plist.
    // Registering it again with CoreText here logged a "file already registered" fault at every launch.
    
    // MARK: - Splash Screen State
    @State private var isSplashScreenVisible: Bool = true
    @State private var didHandleNotificationPermission = false
    
    // MARK: - What's New (shown once after an update)
    @AppStorage(UDKey.lastSeenWhatsNewVersion.rawValue) private var lastSeenWhatsNewVersion: String = ""
    @State private var showWhatsNew = false
    
    /// Was the app already in use on this device before this build? Decided once, at the first launch,
    /// and remembered.
    ///
    /// "Has finished onboarding" is NOT a usable test: version 1.0 had no onboarding, so everyone updating
    /// from it looks exactly like a new install on that measure. What a 1.0 user does have is an answered
    /// location prompt (1.0 asked at first launch) and possibly saved settings. A fresh install has neither.
    private static let isUpdateFromOlderVersion: Bool = {
        let defaults = UserDefaults.standard
        if let decided = defaults.object(forKey: UDKey.installedAsUpdate.rawValue) as? Bool {
            return decided
        }
        let earlierKeys: [UDKey] = [.hasSeenOnboarding, .calculationMethod, .madhab, .tasbihCount, .appLanguage, .lastReadSurahNumber]
        let hasEarlierData = earlierKeys.contains { defaults.object(forKey: $0.rawValue) != nil }
        let locationAlreadyAnswered = CLLocationManager().authorizationStatus != .notDetermined
        
        let isUpdate = hasEarlierData || locationAlreadyAnswered
        defaults.set(isUpdate, forKey: UDKey.installedAsUpdate.rawValue)
        return isUpdate
    }()
    
    init() {
        // Evaluate at launch, before onboarding can grant location and blur the distinction
        _ = Self.isUpdateFromOlderVersion
    }
    
    /// Arabic and Urdu read right to left; the locale alone does not flip the layout.
    private var layoutDirection: LayoutDirection {
        ["ar", "ur"].contains(appLanguage) ? .rightToLeft : .leftToRight
    }
    
    @StateObject private var accountManager = AccountManager.shared
    @StateObject private var appearance = AppAppearance.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Base background to prevent white flashes
                Color(hex: "0F2027").edgesIgnoringSafeArea(.all)
                
                // 1. The Main App (Always in background). It settles into place from slightly smaller
                // while the splash screen or onboarding fades away over it.
                let isCovered = isSplashScreenVisible || !hasSeenOnboarding
                ContentView()
                    .environmentObject(viewModel)
                    .environment(\.locale, Locale(identifier: appLanguage))
                    .environment(\.layoutDirection, layoutDirection)
                    // Content always renders dark; only the window (and so the status bar) can turn light
                    .environment(\.colorScheme, .dark)
                    .preferredColorScheme(appearance.prefersLightStatusBar ? .light : .dark)
                    .scaleEffect(isCovered ? 0.94 : 1)
                    .opacity(isCovered ? 0 : 1)
                    .animation(.spring(response: 0.65, dampingFraction: 0.85), value: isCovered)
                    .onChange(of: isCovered, initial: true) { _, covered in
                        AppEntrance.shared.contentRevealed = !covered
                    }
                    .sheet(isPresented: $showWhatsNew, onDismiss: {
                        lastSeenWhatsNewVersion = WhatsNewView.contentVersion
                    }) {
                        WhatsNewView()
                            .environment(\.locale, Locale(identifier: appLanguage))
                            .environment(\.layoutDirection, layoutDirection)
                            .environment(\.colorScheme, .dark)
                    }
                
                // 2. Onboarding (overlays the main app until dismissed).
                // Removed from the hierarchy once finished so its animated background stops rendering.
                if !hasSeenOnboarding {
                    OnboardingView()
                        .environmentObject(viewModel)
                        .environment(\.locale, Locale(identifier: appLanguage))
                        .environment(\.layoutDirection, layoutDirection)
                        .preferredColorScheme(.dark)
                        .transition(.opacity.combined(with: .scale(scale: 1.06)))
                        .zIndex(0.5)
                }
                
                // 3. The Splash Screen, likewise removed after it fades out
                if isSplashScreenVisible {
                    SplashScreenView()
                        .transition(.opacity.combined(with: .scale(scale: 1.08)))
                        .zIndex(1) // Ensure it sits on top
                }
            }
            .onAppear {
                // Sign out if Sign in with Apple access was revoked while the app wasn't running
                accountManager.verifyAppleCredential()
                
                // Apple Watch link: settings and location down, Tasbih and tracker changes up
                PhoneWatchSync.shared.activate()
                
                // MARK: - iCloud Auto-Sync
                if accountManager.isLoggedIn {
                    CloudSyncManager.shared.startSyncing()
                }
                
                // Warm the Quran cache off the main thread so the first surah opens without a decode delay
                Task.detached(priority: .background) {
                    _ = try? await QuranDataCache.shared.getSurahs()
                    _ = try? await QuranDataCache.shared.getVerses(for: 1)
                }
                
                // MARK: - Splash Logic
                // Wait 3 seconds, then fade the splash out and drop it from the hierarchy
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isSplashScreenVisible = false
                    }
                    Haptics.soft()
                    presentWhatsNewIfNeeded()
                }
            }
            // Ask for notifications only once onboarding is done and the first prayer times are on screen,
            // so the prompt has context instead of appearing over the splash screen.
            .onChange(of: viewModel.prayerTimes.isEmpty) { _, _ in
                requestNotificationsIfReady()
            }
            .onChange(of: hasSeenOnboarding) { _, finished in
                requestNotificationsIfReady()
                guard finished else { return }
                if Self.isUpdateFromOlderVersion {
                    // Updating from a version that had no onboarding: they still get the list of changes,
                    // once the onboarding screen has faded out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        presentWhatsNewIfNeeded()
                    }
                } else {
                    // A genuinely new user doesn't need a list of changes
                    lastSeenWhatsNewVersion = WhatsNewView.contentVersion
                }
            }
            // Midnight with the app left open: reset the daily tracker and recalculate, which also moves the
            // Hijri date and the "Tomorrow" card on. (The Verse of the Day listens for this itself.)
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
                HomeWidgetsData.shared.refreshDayState()
                viewModel.forceReschedule()
            }
            // Foreground refresh logic
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Reset the daily tracker if the app stayed alive across midnight
                    HomeWidgetsData.shared.refreshDayState()
                    viewModel.refreshPrayers()
                }
            }
        }
        .backgroundTask(.appRefresh("com.youssefkairum.iPrayer.refresh")) {
            await MainActor.run {
                viewModel.refreshPrayers()
            }
        }
    }
    
    /// People updating from an earlier version have finished onboarding but have not seen this page.
    private func presentWhatsNewIfNeeded() {
        #if DEBUG
        // Debug-only: `-debugShowWhatsNew 1` as a launch argument always shows the page
        if UserDefaults.standard.bool(forKey: "debugShowWhatsNew") {
            showWhatsNew = true
            return
        }
        #endif
        guard hasSeenOnboarding, WhatsNewView.shouldShow(after: lastSeenWhatsNewVersion) else { return }
        showWhatsNew = true
    }
    
    private func requestNotificationsIfReady() {
        guard hasSeenOnboarding, !viewModel.prayerTimes.isEmpty, !didHandleNotificationPermission else { return }
        didHandleNotificationPermission = true
        
        let center = UNUserNotificationCenter.current()
        let model = viewModel
        let scheduleQuranReminders = {
            let surahName = UserDefaults.standard.string(forKey: UDKey.lastReadSurahEnglish.rawValue)
            NotificationManager.shared.scheduleQuranReminders(surahName: surahName)
        }
        
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    scheduleQuranReminders()
                    // Prayer notifications added before permission existed were dropped; schedule them again
                    Task { @MainActor in model.forceReschedule() }
                }
            case .authorized, .provisional, .ephemeral:
                scheduleQuranReminders()
            default:
                break
            }
        }
    }
}
