//
//  iPrayerApp.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/23/25.
//

import SwiftUI
import UserNotifications
import CoreText

@main
struct iPrayerApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var viewModel = PrayerViewModel()
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.hasSeenOnboarding.rawValue) private var hasSeenOnboarding: Bool = false
    
    init() {
        if let fontURL = Bundle.main.url(forResource: "KFGQPC Uthmanic Script HAFS Regular", withExtension: "otf") {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
        }
    }
    
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
                
                // 2. Onboarding (Overlays main app until dismissed)
                OnboardingView()
                    .environmentObject(viewModel)
                    .environment(\.locale, Locale(identifier: appLanguage))
                    .preferredColorScheme(.dark)
                    .opacity(hasSeenOnboarding ? 0.0 : 1.0)
                    .allowsHitTesting(!hasSeenOnboarding)
                    .zIndex(0.5)
                
                // 2. The Splash Screen
                SplashScreenView()
                    .opacity(isSplashScreenVisible ? 1.0 : 0.0)
                    .allowsHitTesting(isSplashScreenVisible)
                    .animation(.easeInOut(duration: 0.5), value: isSplashScreenVisible)
                    .zIndex(1) // Ensure it sits on top
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
                
                // MARK: - Splash Logic
                // Wait 3 seconds, then trigger the implicit fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    isSplashScreenVisible = false
                }
            }
            // Background refresh logic
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
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
