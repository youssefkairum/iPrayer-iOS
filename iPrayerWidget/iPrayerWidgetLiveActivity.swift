//
//  iPrayerWidgetLiveActivity.swift
//  iPrayerWidget
//

import ActivityKit
import WidgetKit
import SwiftUI

struct iPrayerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerAttributes.self) { context in
            // Lock Screen UI & Notification Center
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.0, green: 0.65, blue: 0.70), Color(red: 0.0, green: 0.20, blue: 0.35)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
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
                    
                    Text("\(context.state.atString) \(context.state.prayerTime)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer(minLength: 8)
                    
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
                            .foregroundColor(.teal)
                        Text(context.state.prayerName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                // Trailing (Top Right)
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.timeRemaining, countsDown: true)
                        .font(.system(.headline, design: .monospaced, weight: .semibold))
                        .foregroundColor(.teal)
                }
                
                // Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Swipe to open iPrayer")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
            } compactLeading: {
                // Compact UI - Left of pill
                Image(systemName: context.state.prayerIcon)
                    .foregroundColor(.teal)
            } compactTrailing: {
                // Compact UI - Right of pill
                Text(timerInterval: context.state.timeRemaining, countsDown: true)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.teal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                // Minimal UI - Circle icon when multiple activities exist
                Image(systemName: context.state.prayerIcon)
                    .foregroundColor(.teal)
            }
            .widgetURL(URL(string: "http://www.apple.com")) // Deep link into app
            .keylineTint(Color.teal)
        }
    }
}
