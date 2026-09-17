//
//  iPrayerApp.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/23/25.
//

import SwiftUI
import UserNotifications

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
                
                // 1. The Main App (Always in background)
                ContentView()
                    .environmentObject(viewModel)
                    .environment(\.locale, Locale(identifier: appLanguage))
                    .environment(\.layoutDirection, layoutDirection)
                    // Content always renders dark; only the window (and so the status bar) can turn light
                    .environment(\.colorScheme, .dark)
                    .preferredColorScheme(appearance.prefersLightStatusBar ? .light : .dark)
                
                // 2. Onboarding (overlays the main app until dismissed).
                // Removed from the hierarchy once finished so its animated background stops rendering.
                if !hasSeenOnboarding {
                    OnboardingView()
                        .environmentObject(viewModel)
                        .environment(\.locale, Locale(identifier: appLanguage))
                        .environment(\.layoutDirection, layoutDirection)
                        .preferredColorScheme(.dark)
                        .transition(.opacity)
                        .zIndex(0.5)
                }
                
                // 3. The Splash Screen, likewise removed after it fades out
                if isSplashScreenVisible {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1) // Ensure it sits on top
                }
            }
            .onAppear {
                // Sign out if Sign in with Apple access was revoked while the app wasn't running
                accountManager.verifyAppleCredential()
                
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
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isSplashScreenVisible = false
                    }
                }
            }
            // Ask for notifications only once onboarding is done and the first prayer times are on screen,
            // so the prompt has context instead of appearing over the splash screen.
            .onChange(of: viewModel.prayerTimes.isEmpty) { _, _ in
                requestNotificationsIfReady()
            }
            .onChange(of: hasSeenOnboarding) { _, _ in
                requestNotificationsIfReady()
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
