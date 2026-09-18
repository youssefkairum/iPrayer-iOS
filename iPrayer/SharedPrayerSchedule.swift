//
//  SharedPrayerSchedule.swift
//  iPrayer
//
//  Compiled into BOTH the app and the widget extension.
//  The app saves the inputs below to the shared App Group; the widget uses them to compute
//  prayer times on its own, so it stays correct even if the app isn't opened for weeks.
//

import Foundation
import SwiftUI
import Adhan

/// Everything the widget needs to compute prayer times without the app.
nonisolated struct SharedPrayerConfig: Codable {
    static let suiteName = "group.iPrayer.shared"
    static let defaultsKey = "sharedPrayerConfig"
    
    let latitude: Double
    let longitude: Double
    let calculationMethod: String
    let madhab: String
    /// In-app language code, used to format times.
    let language: String
    /// English prayer name -> display name in the in-app language.
    let prayerNames: [String: String]
    /// Localized "Next Prayer" header.
    let header: String
    
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.suiteName),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
    
    static func load() -> SharedPrayerConfig? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SharedPrayerConfig.self, from: data)
    }
}

nonisolated struct ScheduledPrayer {
    let name: String
    let time: Date
    
    var icon: String { PrayerSchedule.icon(for: name) }
}

nonisolated enum PrayerSchedule {
    static let prayerNames = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
    
    /// Maps the persisted settings strings to Adhan calculation parameters.
    static func parameters(method: String, madhab: String) -> CalculationParameters {
        let calculationMethod: CalculationMethod
        switch method {
        case "egyptian": calculationMethod = .egyptian
        case "karachi": calculationMethod = .karachi
        case "ummAlQura": calculationMethod = .ummAlQura
        case "dubai": calculationMethod = .dubai
        case "northAmerica": calculationMethod = .northAmerica
        case "kuwait": calculationMethod = .kuwait
        case "qatar": calculationMethod = .qatar
        case "singapore": calculationMethod = .singapore
        case "turkey": calculationMethod = .turkey
        case "tehran": calculationMethod = .tehran
        default: calculationMethod = .muslimWorldLeague
        }
        
        var params = calculationMethod.params
        // "shafi" is the standard Asr calculation (also used by Maliki & Hanbali)
        params.madhab = madhab == "hanafi" ? .hanafi : .shafi
        return params
    }
    
    static func icon(for prayerName: String) -> String {
        switch prayerName {
        case "Fajr": return "sun.haze.fill"
        case "Sunrise": return "sunrise.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.min.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.stars.fill"
        default: return "clock.fill"
        }
    }
    
    /// All six daily times for every day in `dayOffsets` (relative to `now`), sorted by time.
    static func prayers(latitude: Double, longitude: Double, parameters: CalculationParameters, dayOffsets: ClosedRange<Int>, from now: Date = Date()) -> [ScheduledPrayer] {
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        let calendar = Calendar(identifier: .gregorian)
        var result: [ScheduledPrayer] = []
        
        for offset in dayOffsets {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let times = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: parameters) else { continue }
            result.append(ScheduledPrayer(name: "Fajr", time: times.fajr))
            result.append(ScheduledPrayer(name: "Sunrise", time: times.sunrise))
            result.append(ScheduledPrayer(name: "Dhuhr", time: times.dhuhr))
            result.append(ScheduledPrayer(name: "Asr", time: times.asr))
            result.append(ScheduledPrayer(name: "Maghrib", time: times.maghrib))
            result.append(ScheduledPrayer(name: "Isha", time: times.isha))
        }
        return result.sorted { $0.time < $1.time }
    }
}

// MARK: - Colors

/// The per-prayer colors, shared so the hero card, the widget, the Live Activity and the Dynamic Island
/// always match. Keyed by the ENGLISH prayer name, never the translated one.
nonisolated struct PrayerPalette {
    let start: Color
    let end: Color
    /// Glow and highlight color used around the hero card
    let glow: Color
    /// A tone that stays readable on black, for the Dynamic Island, where a gradient can't be drawn.
    /// Same as `glow` except for Isha, whose own colors are too dark to see there.
    let accent: Color
    
    var gradient: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    static func palette(for prayerName: String) -> PrayerPalette {
        switch prayerName {
        case "Fajr":
            return PrayerPalette(start: Color(rgb: 0x4B3B5C), end: Color(rgb: 0xE58C8A), glow: Color(rgb: 0xE58C8A), accent: Color(rgb: 0xE58C8A))
        case "Sunrise":
            return PrayerPalette(start: Color(rgb: 0xFF512F), end: Color(rgb: 0xF09819), glow: Color(rgb: 0xF09819), accent: Color(rgb: 0xF09819))
        case "Dhuhr":
            return PrayerPalette(start: Color(rgb: 0x2980B9), end: Color(rgb: 0x6DD5FA), glow: Color(rgb: 0x6DD5FA), accent: Color(rgb: 0x6DD5FA))
        case "Asr":
            return PrayerPalette(start: Color(rgb: 0xF2994A), end: Color(rgb: 0xF2C94C), glow: Color(rgb: 0xF2994A), accent: Color(rgb: 0xF2B24B))
        case "Maghrib":
            return PrayerPalette(start: Color(rgb: 0xC33764), end: Color(rgb: 0x1D2671), glow: Color(rgb: 0xC33764), accent: Color(rgb: 0xE0567F))
        case "Isha":
            return PrayerPalette(start: Color(rgb: 0x0F2027), end: Color(rgb: 0x203A43), glow: Color(rgb: 0x203A43), accent: Color(rgb: 0x6FB3C8))
        default:
            return PrayerPalette(start: Color.teal.opacity(0.8), end: Color.blue.opacity(0.4), glow: .teal, accent: .teal)
        }
    }
    
    /// Live Activities started by an older build carry no prayer key, but the icon identifies the prayer.
    static func prayerName(forIcon icon: String) -> String? {
        PrayerSchedule.prayerNames.first { PrayerSchedule.icon(for: $0) == icon }
    }
}

private extension Color {
    // nonisolated: the app target defaults to MainActor isolation, and the palette is used from widget code
    nonisolated init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
