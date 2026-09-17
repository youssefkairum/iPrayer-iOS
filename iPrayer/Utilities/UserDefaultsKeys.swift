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
    
    // Tasbih
    case tasbihCount = "tasbihCount"
    case tasbihTarget = "tasbihTarget"
    
    // Notifications
    case adhanSoundEnabled = "adhanSoundEnabled"
    case quranRemindersEnabled = "quranRemindersEnabled"
    case prePrayerReminderMinutes = "prePrayerReminderMinutes" // 0 = off
    
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
