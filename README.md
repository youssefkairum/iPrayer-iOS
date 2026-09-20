# iPrayer - Modern Islamic Companion App

![Platform](https://img.shields.io/badge/Platform-iOS%2026%2B-blue.svg)
![Language](https://img.shields.io/badge/Language-Swift-orange.svg)
![UI Framework](https://img.shields.io/badge/UI-SwiftUI-purple.svg)
![Version](https://img.shields.io/badge/Version-1.1.0-teal.svg)
![License](https://img.shields.io/badge/License-All%20rights%20reserved-lightgrey.svg)

**iPrayer** is a comprehensive, beautifully designed iOS application built with **SwiftUI**. It is an all-in-one companion for daily Islamic practice: accurate prayer times with adhan notifications, a Qibla compass, a fully offline Quran reader, a Dua library, a Tasbih counter, Home Screen and Lock Screen widgets, and a Live Activity that counts down to the next prayer.

Prayer times, the Quran text, Duas and the Tasbih all work offline. The network is used only for Quran recitation audio (unless a surah is downloaded), reverse geocoding for the city name, and optional iCloud sync.

## ✨ Key Features

### 🕌 Prayer Times
- **Accurate Calculation:** Times for Fajr, Sunrise, Dhuhr, Asr, Maghrib and Isha from your location, using the [Adhan](https://github.com/batoulapps/adhan-swift) library.
- **Home Dashboard:** Everything on one screen: the Hijri date and your location, a themed "hero" card counting down to the next prayer, the prayer tracker, a Dua of the Day, tomorrow's times as a row of coloured symbols, and a Verse of the Day.
- **11 Calculation Methods:** Muslim World League, Egyptian, Karachi, Umm Al-Qura, Dubai, ISNA, Kuwait, Qatar, Singapore, Turkey and Tehran, with Standard or Hanafi Asr.
- **Prayer Tracker & Streak:** Mark each of the five prayers as done and build a daily streak.

### 🔔 Notifications
- **Adhan Alerts:** Prayer notifications with a custom adhan sound (`adhan.caf`), scheduled a week ahead so they keep arriving even if the app isn't opened.
- **Pre-Prayer Reminder:** An optional heads-up 5, 10, 15 or 30 minutes before each prayer.
- **Daily Quran Reminder:** A gentle reminder that mentions the surah you were reading.
- **Your Choice:** Each of these can be switched on or off in Settings, and all of them follow the in-app language.

### 📱 Widgets & Live Activity
- **Next Prayer Widgets:** Small and medium Home Screen widgets plus inline, circular and rectangular Lock Screen widgets showing the next prayer.
- **Today's Prayers Widget:** Medium and large Home Screen widgets showing all six of today's times in each prayer's colour, with passed prayers dimmed and the next one highlighted.
- **Verse of the Day Widgets:** Medium and large Home Screen widgets and rectangular and inline Lock Screen widgets with the day's verse in the Quran font. Tapping opens the verse in the reader.
- **Self-Sufficient:** The widget computes its own timeline with Adhan from settings shared through an App Group, so it stays correct without opening the app.
- **Live Activity & Dynamic Island:** A countdown to the next prayer that switches to "Now" when the time arrives.

### ⌚️ Apple Watch
- **Companion App:** Next prayer with a live countdown, today's times, the prayer tracker, a Tasbih counter with haptics, and a Qibla compass, as vertical pages.
- **Works on Its Own:** The watch calculates times with Adhan from its own location (falling back to the iPhone's), so it stays correct without the phone nearby.
- **Complications:** Circular, corner, rectangular and inline watch-face complications showing the next prayer.
- **Two-Way Sync:** Settings, language and location flow to the watch; Tasbih and tracker changes made on the wrist flow back to the phone and on to iCloud.

### 📖 The Holy Quran
- **Fully Offline:** All 114 surahs are bundled with the app. No network is needed.
- **Faithful Rendering:** Uthmani text drawn with the KFGQPC Hafs font. Recitation signs are re-encoded for the font at display time, so pause marks, open tanween, iqlab and silent-letter marks all appear. The mapping is verified against all 6,236 verses.
- **Mushaf Layout:** Justified text laid out by real Madani mushaf page, with page and juz numbers and font-drawn verse ornaments.
- **Pick Up Where You Left Off:** The reader resumes at the exact verse, and "Continue Reading" shows it.
- **Verse Actions:** Tap a verse to copy, share or bookmark it. Bookmarks appear on the Quran tab.
- **Search:** Find surahs by name or number, or search the verse text. Matching ignores vowel marks and accepts both Uthmani and modern spelling.
- **Recitation:** Listen verse by verse with a choice of six reciters. The verse being recited is highlighted and the page follows along. Start from any verse, and control playback from the Lock Screen. Audio streams from the internet, or download any surah for offline listening.
- **Storage Manager:** Settings lists every downloaded surah by reciter with its size, so you can delete one surah, one reciter, or everything.
- **Comfortable Reading:** Adjustable text size, paper and dark themes, a link to the next surah, and the screen stays awake while you read.

### 🤲 Dua Library
- **50 Authentic Duas:** Grouped by occasion (morning and evening, sleep, after prayer, anxiety, protection, forgiveness, guidance, travel, home, food, parents, knowledge) with Arabic text, translation and source.
- **Morning & Evening Adhkar:** The Hisn al-Muslim adhkar in the book's order, with repeat counts and the evening wording where it differs.
- **Find and Share:** Search Arabic or translation, filter by category, and copy or share any dua. A Dua of the Day on the Home screen opens the library at that dua.

### 🧭 Qibla Compass
- **Real-Time Tracking:** Uses the device heading and your coordinates to point towards the Kaaba.
- **Visual & Haptic Feedback:** The dial clicks like a physical detent as you turn, and glows with a confirming tap when you settle within 5 degrees of the Qibla.
- **Accuracy:** True-north heading corrected for the device's orientation, iOS's figure-8 calibration prompt when the magnetometer needs it, and an in-app hint while the heading error is above 15°. Devices without a compass still get the bearing and distance.

### 📿 Digital Tasbih
- **Interactive Counter:** A circular bead ring tracking cycles of 33, 99 or 100.
- **Haptic Feedback:** A tap on every count and a heavier one when a cycle completes.
- **Persistence:** The count is saved automatically and synced through iCloud.

### 🌍 Languages
- **9 Languages:** English, Arabic, Urdu, French, German, Hindi, Turkish, Russian and Simplified Chinese, switchable inside the app.
- **Right-to-Left:** Arabic and Urdu mirror the whole interface.

### ☁️ Account & Sync
- **Sign in with Apple** (optional) enables iCloud key-value sync of settings, Tasbih count, reading position, bookmarks, and the prayer tracker and streak.
- **Sign out and delete my data** (Settings > Account) removes the profile and every synced value from iCloud and signs out; on-device data stays until the app is deleted. iPrayer runs no servers, so the Sign in with Apple grant itself is revoked from Settings > Apple Account.
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

**Requirements:** Xcode 27 (26 may work for the iPhone targets), iOS 26.0 or later, watchOS 10.0 or later for the Apple Watch app.

1. Clone the repository and open `iPrayer.xcodeproj`. Swift Package Manager resolves Adhan automatically.
2. Select your own development team for all four targets: `iPrayer`, `iPrayerWidgetExtension`, `iPrayerWatch` and `iPrayerWatchWidgetExtension`.
3. The app uses these capabilities, which must exist for your team: **App Groups** (`group.iPrayer.shared`), **iCloud key-value storage**, **Sign in with Apple**, and **Background Modes** (background fetch).
4. Build and run the `iPrayer` scheme. In the Simulator, set a location under *Features > Location* so prayer times can be calculated.

### Debug launch arguments
Debug builds accept these arguments to open a specific screen, which helps with UI checks and screenshots:

| Argument | Effect |
|---|---|
| `-debugInitialTab quran` | Starts on a tab: `quran`, `tasbih`, `qibla` or `settings` |
| `-debugOpenSurah 18 -debugOpenVerse 40` | Opens that surah in the reader, optionally at a verse |
| `-debugOnboardingSlide 2` | Starts onboarding on that slide |
| `-debugShowWhatsNew 1` | Forces the What's New sheet |
| `-debugWatchStep 1` | Forces onboarding's Apple Watch step without a paired watch |
| `-debugSpinCompass 1` | Turns the compass at 30 Hz, reporting a deliberately poor 25° accuracy |
| `-debugHeadingAccuracy 5` | Overrides that 25°, to rehearse a well-calibrated phone |
| `-debugAudioBaseURL https://unreachable.invalid` | Makes every verse fail, to test offline handling |
| `-appLanguage ar` / `-userName "Name"` | Any UserDefaults key can be overridden for one run |

Deep link: `iprayer://verse/2/255` opens the reader at a verse (used by the Verse of the Day widget).

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
├── SharedVerseOfTheDay.swift      # Daily-verse schedule shared with the widget
├── SharedWatchState.swift         # WatchConnectivity payload shared with the watch app
├── Views/
│   ├── ContentView.swift          # Tab container and floating tab bar
│   ├── OnboardingView.swift       # Welcome, features, location, sign-in
│   ├── SplashScreenView.swift
│   ├── PrayerListView.swift       # Home dashboard
│   ├── PrayerDetailView.swift     # Full schedule
│   ├── HomeWidgets.swift          # Tracker, streak, Dua of the Day, Verse of the Day
│   ├── Motion.swift               # Press style, entrance stagger, app-reveal flag
│   ├── WhatsNewView.swift
│   ├── QuranView.swift            # Surah list, search, bookmarks
│   ├── SurahDetailView.swift      # Reader screen and verse actions
│   ├── MushafTextView.swift       # Page-based Quran text view
│   ├── DuaLibraryView.swift       # Search, category chips, copy/share
│   ├── AudioStorageView.swift     # Downloaded audio manager
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
│   ├── QuranAudioPlayer.swift     # Verse-by-verse recitation, streamed or from downloads
│   ├── QuranAudioDownloads.swift  # Per-surah offline audio
│   ├── VerseOfTheDay.swift
│   ├── PhoneWatchSync.swift       # iPhone side of the Apple Watch link
│   ├── CloudSyncManager.swift     # iCloud key-value sync
│   ├── AccountManager.swift       # Sign in with Apple
│   └── NotificationManager.swift  # Quran reminders
├── Utilities/
│   ├── QuranTextEncoder.swift     # Display re-encoding for the KFGQPC font
│   ├── AppTranslations.swift
│   ├── Haptics.swift
│   ├── DeepLinks.swift            # iprayer://verse/S/A
│   ├── ZipArchive.swift
│   └── UserDefaultsKeys.swift
├── Localizable.xcstrings
├── quran-uthmani.json             # Offline Quran text
├── surah-metadata.json
├── adhan.caf                      # Notification sound
└── KFGQPC Uthmanic Script HAFS Regular.otf

iPrayerWidget/
├── iPrayerWidget.swift            # Next-prayer Home Screen and Lock Screen widgets
├── TodayPrayersWidget.swift       # Today's six prayer times, medium and large
├── VerseOfTheDayWidget.swift      # Verse of the Day Home Screen and Lock Screen widgets
├── iPrayerWidgetLiveActivity.swift
└── iPrayerWidgetBundle.swift

iPrayerWatch/                      # watchOS companion app (independent)
├── iPrayerWatchApp.swift
├── WatchModel.swift               # Location, Adhan calculation, heading, settings from the phone
├── WatchSync.swift                # Watch side of the iPhone link
└── Views/                         # Next prayer, today, tracker, Tasbih, Qibla pages

iPrayerWatchWidget/                # Watch-face complications
└── NextPrayerComplication.swift
```

---

## 🙏 Acknowledgements
- **Quran text:** Uthmani text of the [Tanzil Project](https://tanzil.net), in the JSON layout of the [alquran.cloud](https://alquran.cloud) `quran-uthmani` edition. The verse text is bundled unmodified.
- **Quran font:** KFGQPC Uthmanic Script HAFS, by the King Fahd Glorious Quran Printing Complex.
- **Recitation audio:** per-verse files from [EveryAyah](https://everyayah.com), which its About page described as licensed under Creative Commons Attribution-NonCommercial 2.5 Canada. The app keeps to the two connections at a time the site asks for.
- **Prayer times:** [Adhan Swift](https://github.com/batoulapps/adhan-swift) by Batoul Apps.

---

## 📄 License
The iPrayer source and design are © Youssef Keram, all rights reserved. The bundled Quran text, font, recitation audio and prayer-time library keep their own licences, listed under Acknowledgements; none of them is covered by this notice.

---

## 👤 Author
Youssef Keram

Copyright © 2026 Youssef Keram. All rights reserved.
