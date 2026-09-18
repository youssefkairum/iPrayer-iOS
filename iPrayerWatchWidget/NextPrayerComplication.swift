//
//  NextPrayerComplication.swift
//  iPrayerWatchWidget
//
//  The next prayer on the watch face. Like the iPhone widget, it computes its own timeline with Adhan
//  from the SharedPrayerConfig the watch app writes to the App Group, so it stays correct on its own.
//

import WidgetKit
import SwiftUI

struct ComplicationEntry: TimelineEntry {
    let date: Date
    var prayerKey: String = ""
    let prayerName: String
    let time: Date
    let timeString: String
    let header: String
    
    /// Higher as the prayer gets closer, so the Smart Stack brings the complication forward
    var relevance: TimelineEntryRelevance? {
        let minutesLeft = max(0, time.timeIntervalSince(date) / 60)
        let score: Float = minutesLeft <= 30 ? 100 : minutesLeft <= 90 ? 60 : 20
        return TimelineEntryRelevance(score: score, duration: time.timeIntervalSince(date))
    }
    
    static let placeholder = ComplicationEntry(date: Date(), prayerKey: "Maghrib", prayerName: "Maghrib",
                                               time: Date().addingTimeInterval(3600), timeString: "5:29 PM", header: "Next Prayer")
    static let setup = ComplicationEntry(date: Date(), prayerName: "Open iPrayer", time: Date().addingTimeInterval(3600),
                                         timeString: "--:--", header: "Setup Required")
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(entries().first ?? .placeholder)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entries = entries()
        guard !entries.isEmpty else {
            completion(Timeline(entries: [.setup], policy: .after(Date().addingTimeInterval(1800))))
            return
        }
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(24 * 3600))))
    }
    
    /// Two days of entries: each starts when the previous prayer begins and shows the one that follows
    private func entries(now: Date = Date()) -> [ComplicationEntry] {
        guard let config = SharedPrayerConfig.load() else { return [] }
        let parameters = PrayerSchedule.parameters(method: config.calculationMethod, madhab: config.madhab)
        let prayers = PrayerSchedule.prayers(latitude: config.latitude, longitude: config.longitude,
                                             parameters: parameters, dayOffsets: -1...2, from: now)
        guard prayers.count > 1 else { return [] }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: config.language)
        formatter.timeStyle = .short
        
        var entries: [ComplicationEntry] = []
        for index in 1..<prayers.count {
            let upcoming = prayers[index]
            guard upcoming.time > now else { continue }
            entries.append(ComplicationEntry(
                date: max(prayers[index - 1].time, now),
                prayerKey: upcoming.name,
                prayerName: config.prayerNames[upcoming.name] ?? upcoming.name,
                time: upcoming.time,
                timeString: formatter.string(from: upcoming.time),
                header: config.header
            ))
        }
        return entries
    }
}

struct NextPrayerComplicationView: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family
    
    private var icon: String { PrayerSchedule.icon(for: entry.prayerKey.isEmpty ? "" : entry.prayerKey) }
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(entry.timeString)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(4)
            }
            .widgetLabel { Text(entry.prayerName) }
        case .accessoryCorner:
            Image(systemName: icon)
                .font(.title3)
                .widgetLabel { Text("\(entry.prayerName) \(entry.timeString)") }
        case .accessoryInline:
            Text("\(Image(systemName: icon)) \(entry.prayerName) \(entry.timeString)")
        default:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                    Text(entry.header)
                        .font(.caption2)
                }
                .widgetAccentable()
                Text(entry.prayerName)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.timeString)
                        .font(.caption)
                    Text(timerInterval: Date()...max(entry.time, Date()), countsDown: true)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct NextPrayerComplication: Widget {
    let kind = "iPrayerWatchNextPrayer"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            NextPrayerComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Prayer")
        .description("The upcoming prayer and its time.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
