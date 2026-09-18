//
//  TodayPrayersWidget.swift
//  iPrayerWidget
//
//  The whole day at a glance: every prayer with its time, the ones already passed dimmed and ticked,
//  the next one highlighted. Like the other widgets it computes its own timeline with Adhan from the
//  settings the app shares, with an entry at each prayer time so the states roll forward on their own.
//

import WidgetKit
import SwiftUI

struct TodayEntry: TimelineEntry {
    struct Prayer: Identifiable {
        let key: String          // English name, for colours and icons
        let name: String         // display name in the app language
        let time: Date
        let timeString: String
        var id: String { key }
    }
    
    let date: Date
    let dateString: String
    let prayers: [Prayer]
    
    func isPassed(_ prayer: Prayer) -> Bool { prayer.time <= date }
    var next: Prayer? { prayers.first { $0.time > date } }
    
    static let placeholder: TodayEntry = {
        let now = Date()
        let names = PrayerSchedule.prayerNames
        let hours: [Double] = [-7, -5.5, 0.5, 4, 7, 8.5]
        let formatter = DateFormatter(); formatter.timeStyle = .short
        let prayers = zip(names, hours).map { name, h in
            let t = now.addingTimeInterval(h * 3600)
            return Prayer(key: name, name: name, time: t, timeString: formatter.string(from: t))
        }
        let df = DateFormatter(); df.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        return TodayEntry(date: now, dateString: df.string(from: now), prayers: prayers)
    }()
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(entries().first ?? .placeholder)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entries = entries()
        guard !entries.isEmpty else {
            completion(Timeline(entries: [.placeholder], policy: .after(Date().addingTimeInterval(1800))))
            return
        }
        // Entries run to the end of today; ask again at midnight for the new day
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 3600))
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
    
    /// One entry now, then one at each remaining prayer time today, so passed/next update without the app
    private func entries(now: Date = Date()) -> [TodayEntry] {
        guard let config = SharedPrayerConfig.load() else { return [] }
        let parameters = PrayerSchedule.parameters(method: config.calculationMethod, madhab: config.madhab)
        let today = PrayerSchedule.prayers(latitude: config.latitude, longitude: config.longitude,
                                           parameters: parameters, dayOffsets: 0...0, from: now)
        guard !today.isEmpty else { return [] }
        
        let locale = Locale(identifier: config.language)
        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.timeStyle = .short
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        
        let prayers = today.map {
            TodayEntry.Prayer(key: $0.name, name: config.prayerNames[$0.name] ?? $0.name,
                              time: $0.time, timeString: timeFormatter.string(from: $0.time))
        }
        let dateString = dateFormatter.string(from: now)
        
        var moments = [now]
        moments += today.map(\.time).filter { $0 > now }.map { $0.addingTimeInterval(1) }
        return moments.map { TodayEntry(date: $0, dateString: dateString, prayers: prayers) }
    }
}

struct TodayPrayersWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        switch family {
        case .systemLarge:
            largeBody
        default:
            mediumBody
        }
    }
    
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .foregroundStyle(.teal)
            Text(entry.dateString)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let next = entry.next {
                Text(next.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PrayerPalette.palette(for: next.key).accent)
                    .lineLimit(1)
            }
        }
    }
    
    /// Six columns: icon, name, time. Passed ones fade and tick; the next one sits on its accent tint.
    private var mediumBody: some View {
        VStack(spacing: 10) {
            header
            HStack(spacing: 4) {
                ForEach(entry.prayers) { prayer in
                    let passed = entry.isPassed(prayer)
                    let isNext = prayer.id == entry.next?.id
                    let accent = PrayerPalette.palette(for: prayer.key).accent
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: prayer.key.isEmpty ? "clock.fill" : PrayerSchedule.icon(for: prayer.key))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(passed ? .white.opacity(0.35) : accent)
                            if passed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.green)
                                    .offset(x: 5, y: 3)
                            }
                        }
                        .frame(height: 18)
                        Text(prayer.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(passed ? .white.opacity(0.4) : .white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(prayer.timeString)
                            .font(.system(size: 11, weight: isNext ? .bold : .medium, design: .rounded))
                            .foregroundStyle(passed ? .white.opacity(0.4) : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isNext ? accent.opacity(0.22) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
    
    /// One row per prayer with its status
    private var largeBody: some View {
        VStack(spacing: 8) {
            header
            ForEach(entry.prayers) { prayer in
                let passed = entry.isPassed(prayer)
                let isNext = prayer.id == entry.next?.id
                let accent = PrayerPalette.palette(for: prayer.key).accent
                HStack(spacing: 10) {
                    Image(systemName: PrayerSchedule.icon(for: prayer.key))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(passed ? .white.opacity(0.35) : accent)
                        .frame(width: 22)
                    Text(prayer.name)
                        .font(.system(size: 14, weight: isNext ? .bold : .medium, design: .rounded))
                        .foregroundStyle(passed ? .white.opacity(0.4) : .white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if passed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green.opacity(0.8))
                    }
                    Text(prayer.timeString)
                        .font(.system(size: 14, weight: isNext ? .bold : .medium, design: .rounded))
                        .foregroundStyle(passed ? .white.opacity(0.4) : .white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isNext ? accent.opacity(0.22) : Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

struct TodayPrayersWidget: Widget {
    let kind = "iPrayerTodayWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayPrayersWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 15/255, green: 32/255, blue: 39/255),
                                            Color(red: 32/255, green: 58/255, blue: 67/255),
                                            Color(red: 44/255, green: 83/255, blue: 100/255)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Today's Prayers")
        .description("All of today's prayer times, with the ones already passed ticked off and the next one highlighted.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    TodayPrayersWidget()
} timeline: {
    TodayEntry.placeholder
}
