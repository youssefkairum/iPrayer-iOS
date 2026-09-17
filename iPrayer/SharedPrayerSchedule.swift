//
//  SharedPrayerSchedule.swift
//  iPrayer
//
//  Compiled into BOTH the app and the widget extension.
//  The app saves the inputs below to the shared App Group; the widget uses them to compute
//  prayer times on its own, so it stays correct even if the app isn't opened for weeks.
//

import Foundation
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
