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
    
    @StateObject private var accountManager = AccountManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Base background to prevent white flashes
                Color(hex: "0F2027").edgesIgnoringSafeArea(.all)
                
                // 1. The Main App (Always in background)
                ContentView()
                    .environmentObject(viewModel)
                    .environment(\.locale, Locale(identifier: appLanguage))
                    .preferredColorScheme(.dark)
                
                // 2. Onboarding (overlays the main app until dismissed).
                // Removed from the hierarchy once finished so its animated background stops rendering.
                if !hasSeenOnboarding {
                    OnboardingView()
                        .environmentObject(viewModel)
                        .environment(\.locale, Locale(identifier: appLanguage))
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
                // Request Notifications
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    print("Notification permission granted: \(granted)")
                    
                    if granted {
                        // Schedule initial daily Quran reminders on launch
                        let surahName = UserDefaults.standard.string(forKey: UDKey.lastReadSurahEnglish.rawValue)
                        NotificationManager.shared.scheduleQuranReminders(surahName: surahName)
                    }
                }
                
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
}
