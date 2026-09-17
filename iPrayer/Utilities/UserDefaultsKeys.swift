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
    
    // Tasbih
    case tasbihCount = "tasbihCount"
    case tasbihTarget = "tasbihTarget"
    
    // Account
    case userName = "userName"
    case userEmail = "userEmail"
}
