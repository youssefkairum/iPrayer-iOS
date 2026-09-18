//
//  SharedVerseOfTheDay.swift
//  iPrayer
//
//  Compiled into BOTH the app and the widget. The app picks the coming month of daily verses from the
//  bundled Quran (which the widget doesn't have) and writes them to the App Group; the widget builds
//  its timeline from that list, one entry per local day.
//

import Foundation

nonisolated struct SharedDailyVerse: Codable {
    let dayNumber: Int
    let surahNumber: Int
    let numberInSurah: Int
    /// Font-encoded Arabic, ready to draw with the KFGQPC font
    let displayText: String
    /// "An-Nahl 16:95", already in the in-app language
    let reference: String
}

nonisolated struct SharedVerseSchedule: Codable {
    static let suiteName = "group.iPrayer.shared"
    static let defaultsKey = "sharedVerseSchedule"
    
    let verses: [SharedDailyVerse]
    /// Localized "Verse of the Day"
    let header: String
    
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.suiteName),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
    
    static func load() -> SharedVerseSchedule? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SharedVerseSchedule.self, from: data)
    }
    
    /// Whole days since 1970 for the LOCAL calendar date, so everyone sees the same verse on the same date
    /// regardless of time zone, and it changes at local midnight.
    static func dayNumber(for date: Date = Date()) -> Int {
        let local = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utc.date(from: DateComponents(year: local.year, month: local.month, day: local.day)) ?? date
        return Int(midnight.timeIntervalSince1970 / 86_400)
    }
    
    /// Local midnight that starts the given day number
    static func start(ofDay dayNumber: Int, from now: Date = Date()) -> Date {
        let today = Calendar.current.startOfDay(for: now)
        return Calendar.current.date(byAdding: .day, value: dayNumber - self.dayNumber(for: now), to: today) ?? today
    }
}
