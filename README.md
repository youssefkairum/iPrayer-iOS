# iPrayer - Modern Islamic Companion App

![Platform](https://img.shields.io/badge/Platform-iOS-blue.svg)
![Language](https://img.shields.io/badge/Language-Swift-orange.svg)
![UI Framework](https://img.shields.io/badge/UI-SwiftUI-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**iPrayer** is a comprehensive, beautifully designed iOS application built with **SwiftUI**. It serves as an all-in-one companion for daily Islamic practices, featuring accurate prayer times, a Qibla compass, a digital Quran reader, and a Tasbih counter.

The app leverages modern iOS features including `async/await`, CoreLocation, Haptic Feedback, and Glassmorphism UI design.

## ✨ Key Features

### 🕌 Prayer Times
- **Accurate Calculation:** Uses GPS location to calculate accurate times for Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha.
- **Dynamic Countdown:** A "Hero" section displaying the time remaining until the next prayer.
- **Visuals:** Custom icons and glass-morphic cards for each prayer time.
- **Notifications:** Schedules local notifications using a custom Adhan sound (`adhan.mp3`).

### 🧭 Qibla Compass
- **Real-Time Tracking:** Utilizes the device's magnetic heading and coordinates to point towards the Kaaba.
- **Visual Feedback:** The interface glows Teal and displays "You're facing Mecca" when aligned within 5 degrees of the Qibla.
- **Smooth Animations:** Custom needle and dial animations using SwiftUI.

### 📖 The Holy Quran
- **Digital Mushaf:** Access all 114 Surahs indexed by their metadata.
- **Cloud API:** Fetches Surah lists and Verses (Ayahs) dynamically from `api.alquran.cloud`.
- **Reading View:** Clean, scrollable text in Uthmani script with English names and verse counts.

### 📿 Digital Tasbih
- **Interactive Counter:** A beautiful circular progress ring tracking cycles (default: 33).
- **Haptic Feedback:** Uses `UIImpactFeedbackGenerator` for tactile feedback on every tap, with a heavier impact upon completing a cycle.
- **Persistence:** Automatically saves your count between sessions using `@AppStorage`.

### ⚙️ Settings
- **Customization:** Choose from various calculation methods (Muslim World League, ISNA, Egypt, etc.).
- **Madhab Selection:** Toggle between Standard (Shafi/Maliki/Hanbali) and Hanafi juristic methods.
- **Instant Refresh:** Changing settings immediately recalculates prayer times via `Combine` and environment objects.

---

## 🛠 Tech Stack

* **Language:** Swift 5.0+
* **UI Framework:** SwiftUI
* **Architecture:** MVVM (Model-View-ViewModel)
* **Concurrency:** Swift Concurrency (`async`/`await`), `@MainActor`
* **Networking:** `URLSession`, `Codable`
* **Persistence:** `@AppStorage`, `UserDefaults`
* **Dependencies:**
    * [Adhan Swift](https://github.com/batoulapps/adhan-swift) (BatoulApps) - For astronomical calculations.

## 🎨 Design System
Colors: The app uses a consistent Deep Blue/Teal gradient theme.

Hex Colors: #0F2027, #203A43, #2C5364

Typography: Uses System Fonts with Rounded design for headers and Serif for Quranic text.

Glassmorphism: Heavily utilizes Material.ultraThinMaterial for the tab bar and list items to create a modern, translucent look.

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👤 Author
Youssef Keram

Copyright © 2025 All rights reserved.

---

## 📂 Project Structure

The project follows a clean MVVM architecture:

```text
iPrayer/
├── App/
│   ├── iPrayerApp.swift       # Entry point, Notification Setup
│   └── SplashScreenView.swift # Custom Splash Screen with fade animation
├── Views/
│   ├── ContentView.swift      # Main Tab Container & Custom Floating Tab Bar
│   ├── PrayerListView.swift   # Home Dashboard with Countdown
│   ├── QiblaCompassView.swift # Magnetometer & UI Logic
│   ├── QuranView.swift        # List of Surahs
│   ├── SurahDetailView.swift  # Verse Reading View
│   ├── TasbihView.swift       # Interactive Counter
│   └── SettingsView.swift     # App Configuration
├── ViewModels/
│   ├── PrayerViewModel.swift  # Core Logic: Location, Adhan Calc, Notifications
│   ├── QuranViewModel.swift   # Fetches Surah List
│   └── SurahDetailViewModel.swift # Fetches Verses
├── Models/
│   ├── PrayerItem.swift       # Struct for UI presentation
│   └── QuranModel.swift       # Codable structs for API response
└── Resources/
    ├── Assets.xcassets        # Icons, Colors
    └── adhan.mp3              # Custom Notification Sound
