//
//  VerseOfTheDay.swift
//  iPrayer
//
//  Picks the day's verse from the whole bundled Quran and keeps it current when the date changes,
//  even if the app is left open overnight.
//

import Foundation
import UIKit
import Combine
import WidgetKit

@MainActor
final class VerseOfTheDay: ObservableObject {
    static let shared = VerseOfTheDay()
    
    @Published private(set) var verse: VerseSearchResult?
    @Published private(set) var surah: SurahMetadata?
    
    private var loadedDay: Int?
    private var observers: [NSObjectProtocol] = []
    
    private init() {
        // .NSCalendarDayChanged fires at midnight. significantTimeChange also covers a time zone or clock
        // change, and returning to the foreground covers a day that passed while the app was suspended.
        let names: [Notification.Name] = [
            .NSCalendarDayChanged,
            UIApplication.significantTimeChangeNotification,
            UIApplication.willEnterForegroundNotification
        ]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // Delivered on the main queue (see `queue: .main`), so this is already the main actor
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        refresh()
    }
    
    /// Whole days since 1970 for the LOCAL calendar date, so everyone sees the same verse on the same date
    /// regardless of time zone, and it changes at local midnight.
    static func dayNumber(for date: Date = Date()) -> Int {
        SharedVerseSchedule.dayNumber(for: date)
    }
    
    /// Re-shares the widget's verses in the current language (called when settings change)
    func shareSchedule() {
        Task {
            guard let surahs = try? await QuranDataCache.shared.getSurahs() else { return }
            await shareSchedule(from: Self.dayNumber(), surahs: surahs)
        }
    }
    
    /// Writes the next month of daily verses to the App Group for the Home Screen widget,
    /// with references in the in-app language, then asks the widget to rebuild its timeline.
    private func shareSchedule(from today: Int, surahs: [SurahMetadata]) async {
        let language = UserDefaults.standard.string(forKey: UDKey.appLanguage.rawValue) ?? "en"
        var verses: [SharedDailyVerse] = []
        for day in today..<(today + 31) {
            guard let result = try? await QuranDataCache.shared.verseOfTheDay(dayNumber: day),
                  let surah = surahs.first(where: { $0.number == result.surahNumber }) else { continue }
            let reference = language == "ar"
                ? "\(surah.name) \(QuranTextEncoder.arabicDigits(surah.number)):\(QuranTextEncoder.arabicDigits(result.ayah.numberInSurah))"
                : "\(language == "ur" ? surah.name : surah.englishName) \(surah.number):\(result.ayah.numberInSurah)"
            verses.append(SharedDailyVerse(dayNumber: day, surahNumber: surah.number, numberInSurah: result.ayah.numberInSurah,
                                           displayText: result.ayah.displayText, reference: reference))
        }
        guard !verses.isEmpty else { return }
        SharedVerseSchedule(verses: verses, header: AppTranslations.translate("Verse of the Day", to: language)).save()
        WidgetCenter.shared.reloadTimelines(ofKind: "iPrayerVerseWidget")
    }
    
    /// Loads today's verse if the day has changed since the last load.
    func refresh() {
        let today = Self.dayNumber()
        guard today != loadedDay else { return }
        loadedDay = today
        
        Task {
            do {
                let result = try await QuranDataCache.shared.verseOfTheDay(dayNumber: today)
                let surahs = try await QuranDataCache.shared.getSurahs()
                // Ignore a result that arrives after the day has moved on again
                guard loadedDay == today else { return }
                verse = result
                surah = surahs.first { $0.number == result.surahNumber }
                await shareSchedule(from: today, surahs: surahs)
            } catch {
                loadedDay = nil // try again on the next trigger
                print("Verse of the Day failed to load: \(error)")
            }
        }
    }
}
