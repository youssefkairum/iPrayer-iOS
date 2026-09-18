//
//  iPrayerWidget.swift
//  iPrayerWidget
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    private static let placeholderEntry = SimpleEntry(date: Date(), prayerKey: "Maghrib", prayerName: "Maghrib", timeString: "5:29 PM", icon: "sunset.fill", headerString: "Next Prayer")
    private static let setupEntry = SimpleEntry(date: Date(), prayerName: "Open App", timeString: "--:--", icon: "location.fill", headerString: "Setup Required")
    
    /// Builds a week of entries from the location and settings the app shared through the App Group.
    /// Each entry starts when the previous prayer begins and shows the prayer that comes next.
    private func computeEntries(now: Date = Date()) -> [SimpleEntry] {
        guard let config = SharedPrayerConfig.load() else { return [] }
        
        let parameters = PrayerSchedule.parameters(method: config.calculationMethod, madhab: config.madhab)
        let prayers = PrayerSchedule.prayers(latitude: config.latitude, longitude: config.longitude, parameters: parameters, dayOffsets: -1...7, from: now)
        guard prayers.count > 1 else { return [] }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: config.language)
        formatter.timeStyle = .short
        
        var entries: [SimpleEntry] = []
        for index in 1..<prayers.count {
            let upcoming = prayers[index]
            guard upcoming.time > now else { continue }
            entries.append(SimpleEntry(
                date: max(prayers[index - 1].time, now),
                prayerKey: upcoming.name,
                prayerName: config.prayerNames[upcoming.name] ?? upcoming.name,
                timeString: formatter.string(from: upcoming.time),
                icon: upcoming.icon,
                headerString: config.header
            ))
        }
        return entries
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        Self.placeholderEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(computeEntries().first ?? Self.setupEntry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries = computeEntries()
        
        if entries.isEmpty {
            // The app hasn't shared a location yet; check again soon.
            completion(Timeline(entries: [Self.setupEntry], policy: .after(Date().addingTimeInterval(1800))))
            return
        }
        
        // Entries cover a week; recompute well before they run out so the widget never goes stale.
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(3 * 24 * 3600))))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    /// English prayer name, used to pick the colors. Empty for the placeholder states.
    var prayerKey: String = ""
    let prayerName: String
    let timeString: String
    let icon: String
    let headerString: String
}

struct iPrayerWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(Image(systemName: entry.icon)) \(entry.prayerName) \(entry.timeString)")
            
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: entry.icon)
                        .font(.caption)
                    Text(entry.timeString)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.icon)
                        .font(.caption)
                    Text(entry.headerString)
                        .font(.headline)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                Text(entry.prayerName)
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(entry.timeString)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    // White content on the prayer's gradient, like the hero card in the app
                    Image(systemName: entry.icon)
                        .foregroundColor(.white)
                        .font(.title2)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
                    
                    Text(entry.headerString)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .textCase(.uppercase)
                        .lineLimit(2)
                        .minimumScaleFactor(0.4)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                
                Spacer()
                
                Text(entry.prayerName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                
                Text(entry.timeString)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            // Use padding safely, container background handles the edges
            .padding(4)
        }
    }
}

struct iPrayerWidget: Widget {
    let kind: String = "iPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            iPrayerWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // Follows the upcoming prayer, and changes with each timeline entry
                    PrayerPalette.palette(for: entry.prayerKey).gradient
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("Keep track of the upcoming prayer on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    iPrayerWidget()
} timeline: {
    SimpleEntry(date: .now, prayerKey: "Maghrib", prayerName: "Maghrib", timeString: "5:29 PM", icon: "sunset.fill", headerString: "Next Prayer")
}
