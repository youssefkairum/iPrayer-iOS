//
//  iPrayerWidget.swift
//  iPrayerWidget
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), prayerName: "Maghrib", timeString: "5:29 PM", icon: "sunset.fill", headerString: "Next Prayer")
    }

struct WidgetEntryData: Codable {
    let date: Date
    let prayerName: String
    let timeString: String
    let icon: String
    let headerString: String
}

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.iPrayer.shared")
        if let data = sharedDefaults?.data(forKey: "widgetTimelineData"),
           let decoded = try? JSONDecoder().decode([WidgetEntryData].self, from: data),
           let first = decoded.first {
            let entry = SimpleEntry(date: Date(), prayerName: first.prayerName, timeString: first.timeString, icon: first.icon, headerString: first.headerString)
            completion(entry)
            return
        }
        
        let emptyEntry = SimpleEntry(date: Date(), prayerName: "Open App", timeString: "--:--", icon: "location.fill", headerString: "Setup Required")
        completion(emptyEntry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.iPrayer.shared")
        var entries: [SimpleEntry] = []
        
        if let data = sharedDefaults?.data(forKey: "widgetTimelineData"),
           let decoded = try? JSONDecoder().decode([WidgetEntryData].self, from: data) {
           
           for dataEntry in decoded {
               let entry = SimpleEntry(
                   date: dataEntry.date,
                   prayerName: dataEntry.prayerName,
                   timeString: dataEntry.timeString,
                   icon: dataEntry.icon,
                   headerString: dataEntry.headerString
               )
               entries.append(entry)
           }
        }
        
        if entries.isEmpty {
            let emptyEntry = SimpleEntry(date: Date(), prayerName: "Open App", timeString: "--:--", icon: "location.fill", headerString: "Setup Required")
            entries.append(emptyEntry)
        }
        
        // Refresh when timeline exhausts, though main app forces refresh earlier
        let nextUpdate = entries.last?.date.addingTimeInterval(3600) ?? Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
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
            if #available(iOS 16.0, *) {
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
            } else {
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
                    Image(systemName: entry.icon)
                        .foregroundColor(.teal)
                        .font(.title2)
                        .shadow(color: .teal.opacity(0.5), radius: 5, x: 0, y: 0)
                    
                    Text(entry.headerString)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
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
                    .foregroundColor(.teal)
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
            if #available(iOS 17.0, *) {
                iPrayerWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 15/255, green: 32/255, blue: 39/255), Color(red: 32/255, green: 58/255, blue: 67/255)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                iPrayerWidgetEntryView(entry: entry)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 15/255, green: 32/255, blue: 39/255), Color(red: 32/255, green: 58/255, blue: 67/255)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
    SimpleEntry(date: .now, prayerName: "Maghrib", timeString: "5:29 PM", icon: "sunset.fill", headerString: "Next Prayer")
}
