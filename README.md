# iPrayer - Modern Islamic Companion App

![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-blue.svg)
![Language](https://img.shields.io/badge/Language-Swift-orange.svg)
![UI Framework](https://img.shields.io/badge/UI-SwiftUI-purple.svg)
![Version](https://img.shields.io/badge/Version-1.1.0-teal.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**iPrayer** is a comprehensive, beautifully designed iOS application built with **SwiftUI**. It is an all-in-one companion for daily Islamic practice: accurate prayer times with adhan notifications, a Qibla compass, a fully offline Quran reader, a Dua library, a Tasbih counter, Home Screen and Lock Screen widgets, and a Live Activity that counts down to the next prayer.

Everything works offline. The only network use is reverse geocoding for the city name and optional iCloud sync.

## ✨ Key Features

### 🕌 Prayer Times
- **Accurate Calculation:** Times for Fajr, Sunrise, Dhuhr, Asr, Maghrib and Isha from your location, using the [Adhan](https://github.com/batoulapps/adhan-swift) library.
- **Home Dashboard:** A themed "hero" card counting down to the next prayer, the full day's schedule at a glance, the Hijri date, and a Verse of the Day.
- **11 Calculation Methods:** Muslim World League, Egyptian, Karachi, Umm Al-Qura, Dubai, ISNA, Kuwait, Qatar, Singapore, Turkey and Tehran, with Standard or Hanafi Asr.
- **Prayer Tracker & Streak:** Mark each of the five prayers as done and build a daily streak.

### 🔔 Notifications
- **Adhan Alerts:** Prayer notifications with a custom adhan sound (`adhan.caf`), scheduled a week ahead so they keep arriving even if the app isn't opened.
- **Pre-Prayer Reminder:** An optional heads-up 5, 10, 15 or 30 minutes before each prayer.
- **Daily Quran Reminder:** A gentle reminder that mentions the surah you were reading.
- **Your Choice:** Each of these can be switched on or off in Settings, and all of them follow the in-app language.

### 📱 Widgets & Live Activity
- **Widgets:** Small and medium Home Screen widgets plus inline, circular and rectangular Lock Screen widgets showing the next prayer.
- **Self-Sufficient:** The widget computes its own timeline with Adhan from settings shared through an App Group, so it stays correct without opening the app.
- **Live Activity & Dynamic Island:** A countdown to the next prayer that switches to "Now" when the time arrives.

### 📖 The Holy Quran
- **Fully Offline:** All 114 surahs are bundled with the app. No network is needed.
- **Faithful Rendering:** Uthmani text drawn with the KFGQPC Hafs font. Recitation signs are re-encoded for the font at display time, so pause marks, open tanween, iqlab and silent-letter marks all appear. The mapping is verified against all 6,236 verses.
- **Mushaf Layout:** Justified text laid out by real Madani mushaf page, with page and juz numbers and font-drawn verse ornaments.
- **Pick Up Where You Left Off:** The reader resumes at the exact verse, and "Continue Reading" shows it.
- **Verse Actions:** Tap a verse to copy, share or bookmark it. Bookmarks appear on the Quran tab.
- **Search:** Find surahs by name or number, or search the verse text. Matching ignores vowel marks and accepts both Uthmani and modern spelling.
- **Comfortable Reading:** Adjustable text size, paper and dark themes, a link to the next surah, and the screen stays awake while you read.

### 🤲 Dua Library
- Authentic supplications grouped by occasion (morning and evening, after prayer, travel, forgiveness and more) with Arabic text, translation and source.

### 🧭 Qibla Compass
- **Real-Time Tracking:** Uses the device heading and your coordinates to point towards the Kaaba.
- **Visual & Haptic Feedback:** The dial glows and the phone taps when you are within 5 degrees of the Qibla.

### 📿 Digital Tasbih
- **Interactive Counter:** A circular bead ring tracking cycles of 33, 99 or 100.
- **Haptic Feedback:** A tap on every count and a heavier one when a cycle completes.
- **Persistence:** The count is saved automatically and synced through iCloud.

### 🌍 Languages
- **9 Languages:** English, Arabic, Urdu, French, German, Hindi, Turkish, Russian and Simplified Chinese, switchable inside the app.
- **Right-to-Left:** Arabic and Urdu mirror the whole interface.

### ☁️ Account & Sync
- **Sign in with Apple** (optional) enables iCloud key-value sync of settings, Tasbih count, reading position, bookmarks, and the prayer tracker and streak.
- **Privacy:** Location is requested during onboarding with an explanation, and is used only to calculate prayer times and the Qibla direction.

---

## 🛠 Tech Stack

* **Language:** Swift
* **UI Framework:** SwiftUI, with a `UITextView`-based reader for the Quran
* **Architecture:** MVVM (Model-View-ViewModel)
* **Concurrency:** Swift Concurrency (`async`/`await`, actors), `@MainActor` by default
* **Frameworks:** CoreLocation, MapKit, WidgetKit, ActivityKit, UserNotifications, BackgroundTasks, AuthenticationServices, StoreKit
* **Persistence:** `@AppStorage` / `UserDefaults`, `NSUbiquitousKeyValueStore` for iCloud sync, an App Group for the widget
* **Localization:** String Catalog (`Localizable.xcstrings`) plus an in-app translation table
* **Dependencies:**
    * [Adhan Swift](https://github.com/batoulapps/adhan-swift) (BatoulApps) - astronomical prayer time and Qibla calculations, used by both the app and the widget.

## 🚀 Getting Started

**Requirements:** Xcode 26 or later, iOS 26.0 or later.

1. Clone the repository and open `iPrayer.xcodeproj`. Swift Package Manager resolves Adhan automatically.
2. Select your own development team for both targets, `iPrayer` and `iPrayerWidgetExtension`.
3. The app uses these capabilities, which must exist for your team: **App Groups** (`group.iPrayer.shared`), **iCloud key-value storage**, **Sign in with Apple**, and **Background Modes** (background fetch).
4. Build and run the `iPrayer` scheme. In the Simulator, set a location under *Features > Location* so prayer times can be calculated.

### Debug launch arguments
Debug builds accept these arguments to open a specific screen, which helps with UI checks and screenshots:

| Argument | Effect |
|---|---|
| `-debugInitialTab quran` | Starts on a tab: `quran`, `tasbih`, `qibla` or `settings` |
| `-debugOpenSurah 18 -debugOpenVerse 40` | Opens that surah in the reader, optionally at a verse |
| `-debugOnboardingSlide 2` | Starts onboarding on that slide |

## 🎨 Design System
Colors: The app uses a consistent Deep Blue/Teal gradient theme.

Hex Colors: #0F2027, #203A43, #2C5364

Typography: Avenir Next for the interface and the KFGQPC Uthmanic Script HAFS font for Quranic text.

Glassmorphism: Uses `Material.ultraThinMaterial` for the tab bar and cards. Long scrolling lists use a flat translucent fill instead, which looks the same on the gradient and scrolls more smoothly.

---

## 📂 Project Structure

The project follows a clean MVVM architecture:

```text
iPrayer/
├── iPrayerApp.swift               # Entry point, permissions flow, appearance
├── PrayerAttributes.swift         # Live Activity attributes (shared with the widget)
├── SharedPrayerSchedule.swift     # Prayer calculation shared by the app and the widget
├── Views/
│   ├── ContentView.swift          # Tab container and floating tab bar
│   ├── OnboardingView.swift       # Welcome, features, location, sign-in
│   ├── SplashScreenView.swift
│   ├── PrayerListView.swift       # Home dashboard
│   ├── PrayerDetailView.swift     # Full schedule
│   ├── HomeWidgets.swift          # Tracker, streak, Verse of the Day
│   ├── QuranView.swift            # Surah list, search, bookmarks
│   ├── SurahDetailView.swift      # Reader screen and verse actions
│   ├── MushafTextView.swift       # Page-based Quran text view
│   ├── DuaLibraryView.swift
│   ├── QiblaCompassView.swift
│   ├── TasbihView.swift
│   ├── SettingsView.swift
│   └── AboutView.swift
├── ViewModels/
│   ├── PrayerViewModel.swift      # Location, calculation, notifications, Live Activity
│   ├── QuranViewModel.swift       # Surah list and search
│   └── SurahDetailViewModel.swift
├── Models/                        # Quran, Dua and Home data models
├── Managers/
│   ├── QuranDataCache.swift       # Offline Quran cache and verse search (actor)
│   ├── QuranBookmarks.swift
│   ├── CloudSyncManager.swift     # iCloud key-value sync
│   ├── AccountManager.swift       # Sign in with Apple
│   └── NotificationManager.swift  # Quran reminders
├── Utilities/
│   ├── QuranTextEncoder.swift     # Display re-encoding for the KFGQPC font
│   ├── AppTranslations.swift
│   └── UserDefaultsKeys.swift
├── Localizable.xcstrings
├── quran-uthmani.json             # Offline Quran text
├── surah-metadata.json
├── adhan.caf                      # Notification sound
└── KFGQPC Uthmanic Script HAFS Regular.otf

iPrayerWidget/
├── iPrayerWidget.swift            # Home Screen and Lock Screen widgets
├── iPrayerWidgetLiveActivity.swift
└── iPrayerWidgetBundle.swift
```

---

## 🙏 Acknowledgements
- **Quran text:** Uthmani text of the [Tanzil Project](https://tanzil.net), in the JSON layout of the [alquran.cloud](https://alquran.cloud) `quran-uthmani` edition. The verse text is bundled unmodified.
- **Quran font:** KFGQPC Uthmanic Script HAFS, by the King Fahd Glorious Quran Printing Complex.
- **Prayer times:** [Adhan Swift](https://github.com/batoulapps/adhan-swift) by Batoul Apps.

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👤 Author
Youssef Keram

Copyright © 2025 All rights reserved.
