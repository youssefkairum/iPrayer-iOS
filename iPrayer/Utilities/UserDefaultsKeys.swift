//
//  UserDefaultsKeys.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation

/// Centralized keys for UserDefaults and AppStorage to prevent typos and ensure consistency across the app and widgets.
enum UDKey: String, CaseIterable {
    // General Settings
    case appLanguage = "appLanguage"
    case hasSeenOnboarding = "hasSeenOnboarding"
    case lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"
    case installedAsUpdate = "installedAsUpdate"   // decided once: was the app already in use before this build?
    
    // Prayer Settings
    case calculationMethod = "calculationMethod"
    case madhab = "madhab"
    
    // Quran Progress
    case lastReadSurahName = "lastReadSurahName"
    case lastReadSurahEnglish = "lastReadSurahEnglish"
    case lastReadSurahNumber = "lastReadSurahNumber"
    case lastReadVerse = "lastReadVerse"
    case quranBookmarks = "quranBookmarks"          // JSON string
    
    // Quran reader appearance
    case quranFontSize = "quranFontSize"
    case quranReaderTheme = "quranReaderTheme"      // "paper" or "dark"
    case quranReciter = "quranReciter"              // QuranReciter.id
    
    // Tasbih
    case tasbihCount = "tasbihCount"
    case tasbihTarget = "tasbihTarget"
    case tasbihUpdatedAt = "tasbihUpdatedAt"
    case tasbihDhikr = "tasbihDhikr"               // Dhikr.id being counted       // when a person last changed it (phone vs watch)
    
    // Notifications
    case adhanSoundEnabled = "adhanSoundEnabled"
    case quranRemindersEnabled = "quranRemindersEnabled"
    case prePrayerReminderMinutes = "prePrayerReminderMinutes" // 0 = off
    
    // Qibla
    case compassHapticsEnabled = "compassHapticsEnabled"   // the compass's detent clicks; default on
    
    // Home tracker & streak
    case currentStreak = "currentStreak"
    case dailyPrayersCompleted = "dailyPrayersCompleted"
    case lastCompletedStreakDate = "lastCompletedStreakDate"
    case lastTrackerDate = "lastTrackerDate"
    
    // Account
    case userName = "userName"
    case userEmail = "userEmail"
    case isLoggedIn = "isLoggedIn"
    case appleUserId = "appleUserId"
}
