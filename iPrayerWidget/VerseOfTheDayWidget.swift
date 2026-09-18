//
//  VerseOfTheDayWidget.swift
//  iPrayerWidget
//
//  The day's verse on the Home Screen. Entries come from the schedule the app shares through the
//  App Group; tapping opens the reader at that verse.
//

import WidgetKit
import SwiftUI

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: SharedDailyVerse?
    let header: String
    
    static let placeholder = VerseEntry(
        date: Date(),
        verse: SharedDailyVerse(dayNumber: 0, surahNumber: 2, numberInSurah: 286,
                                displayText: "لَا يُكَلِّفُ ٱللَّهُ نَفۡسًا إِلَّا وُسۡعَهَا", reference: "Al-Baqara 2:286"),
        header: "Verse of the Day"
    )
    static let setup = VerseEntry(date: Date(), verse: nil, header: "Verse of the Day")
}

struct VerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(entries().first ?? .placeholder)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let entries = entries()
        guard let last = entries.last else {
            // The app hasn't shared a schedule yet (first launch pending); look again soon
            completion(Timeline(entries: [.setup], policy: .after(Date().addingTimeInterval(1800))))
            return
        }
        // One entry per local day; ask again once the shared month runs out
        completion(Timeline(entries: entries, policy: .after(last.date.addingTimeInterval(24 * 3600))))
    }
    
    private func entries(now: Date = Date()) -> [VerseEntry] {
        guard let schedule = SharedVerseSchedule.load() else { return [] }
        let today = SharedVerseSchedule.dayNumber(for: now)
        return schedule.verses
            .filter { $0.dayNumber >= today }
            .sorted { $0.dayNumber < $1.dayNumber }
            .map { verse in
                VerseEntry(date: verse.dayNumber == today ? now : SharedVerseSchedule.start(ofDay: verse.dayNumber, from: now),
                           verse: verse, header: schedule.header)
            }
    }
}

struct VerseOfTheDayWidgetView: View {
    let entry: VerseEntry
    @Environment(\.widgetFamily) private var family
    
    private var isLarge: Bool { family == .systemLarge }
    
    var body: some View {
        switch family {
        case .accessoryInline:
            // One line on the Lock Screen: the reference, since a verse can't fit
            Text("\(Image(systemName: "book.fill")) \(entry.verse?.reference ?? entry.header)")
                .widgetURL(link)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption2)
                    Text(entry.verse?.reference ?? entry.header)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .widgetAccentable()
                if let verse = entry.verse {
                    Text(verse.displayText)
                        .font(.custom("KFGQPC Uthmanic Script HAFS", size: 14))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                } else {
                    Text("Open iPrayer to load today's verse")
                        .font(.caption2)
                }
            }
            .widgetURL(link)
        default:
            homeScreenBody
        }
    }
    
    private var link: URL? {
        entry.verse.flatMap { URL(string: "iprayer://verse/\($0.surahNumber)/\($0.numberInSurah)") }
    }
    
    private var homeScreenBody: some View {
        VStack(alignment: .leading, spacing: isLarge ? 12 : 8) {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.yellow)
                Text(entry.header)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let verse = entry.verse {
                    Text(verse.reference)
                        .font(.caption)
                        .foregroundStyle(.teal)
                        .lineLimit(1)
                }
            }
            
            if let verse = entry.verse {
                Text(verse.displayText)
                    .font(.custom("KFGQPC Uthmanic Script HAFS", size: isLarge ? 23 : 17))
                    .foregroundStyle(.white)
                    .lineSpacing(isLarge ? 6 : 2)
                    .lineLimit(isLarge ? 9 : 3)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Arabic reads right to left whatever the widget's layout direction is
                    .environment(\.layoutDirection, .rightToLeft)
            } else {
                Text("Open iPrayer once to load today's verse.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer(minLength: 0)
        }
        .widgetURL(link)
    }
}

struct VerseOfTheDayWidget: Widget {
    let kind = "iPrayerVerseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
            VerseOfTheDayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    // The app's own night gradient
                    LinearGradient(colors: [Color(red: 15/255, green: 32/255, blue: 39/255),
                                            Color(red: 32/255, green: 58/255, blue: 67/255),
                                            Color(red: 44/255, green: 83/255, blue: 100/255)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Verse of the Day")
        .description("A verse from the Quran, new every day. Tap to read it in context.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemMedium) {
    VerseOfTheDayWidget()
} timeline: {
    VerseEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    VerseOfTheDayWidget()
} timeline: {
    VerseEntry.placeholder
}
