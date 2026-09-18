//
//  iPrayerWidgetLiveActivity.swift
//  iPrayerWidget
//

import ActivityKit
import WidgetKit
import SwiftUI

private extension PrayerAttributes.ContentState {
    /// The same colors as the hero card for this prayer
    var palette: PrayerPalette {
        PrayerPalette.palette(for: prayerKey ?? PrayerPalette.prayerName(forIcon: prayerIcon) ?? "")
    }
}

struct iPrayerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerAttributes.self) { context in
            // Lock Screen UI & Notification Center
            ZStack {
                // Matches the hero card's gradient for this prayer
                context.state.palette.gradient
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        Image(systemName: context.state.prayerIcon)
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .semibold))
                        
                        Spacer()
                        
                        Text(context.state.nextString)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 4)
                    
                    Text(context.state.prayerName)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    // First-strong isolate around the time keeps "at 3:49 AM" in the right order for Arabic and Urdu
                    Text(verbatim: "\(context.state.atString) \u{2068}\(context.state.prayerTime)\u{2069}")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer(minLength: 8)
                    
                    if context.isStale {
                        // The prayer time has arrived: a countdown frozen at zero would be misleading
                        Text(context.state.nowString ?? "Now")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else {
                        Text(context.state.startsInString)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(timerInterval: context.state.timeRemaining, countsDown: true)
                            .font(.system(size: 34, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(20)
            }
            .activityBackgroundTint(Color.clear)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (when user long presses)
                
                // Leading (Top Left)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.prayerIcon)
                            .foregroundColor(context.state.palette.accent)
                        Text(context.state.prayerName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                // Trailing (Top Right)
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale {
                        Text(context.state.nowString ?? "Now")
                            .font(.headline)
                            .foregroundColor(context.state.palette.accent)
                    } else {
                        Text(timerInterval: context.state.timeRemaining, countsDown: true)
                            .font(.system(.headline, design: .monospaced, weight: .semibold))
                            .foregroundColor(context.state.palette.accent)
                    }
                }
                
                // Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.openHintString ?? "Tap to open iPrayer")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
            } compactLeading: {
                // Compact UI - Left of pill
                Image(systemName: context.state.prayerIcon)
                    .foregroundColor(context.state.palette.accent)
            } compactTrailing: {
                // Compact UI - Right of pill
                if context.isStale {
                    Text(context.state.nowString ?? "Now")
                        .font(.subheadline)
                        .foregroundColor(context.state.palette.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text(timerInterval: context.state.timeRemaining, countsDown: true)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(context.state.palette.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } minimal: {
                // Minimal UI - Circle icon when multiple activities exist
                Image(systemName: context.state.prayerIcon)
                    .foregroundColor(context.state.palette.accent)
            }
            .widgetURL(URL(string: "iprayer://prayers")) // Custom scheme registered in iPrayer-Info.plist
            .keylineTint(context.state.palette.accent)
        }
    }
}
