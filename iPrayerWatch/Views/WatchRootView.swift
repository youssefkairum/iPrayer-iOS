//
//  WatchRootView.swift
//  iPrayerWatch
//
//  Vertical pages: next prayer, today's times, tracker, Tasbih, Qibla.
//

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel
    
    var body: some View {
        NavigationStack {
            TabView {
                NextPrayerPage()
                TodayPage()
                TrackerPage()
                TasbihPage()
                QiblaPage()
            }
            .tabViewStyle(.verticalPage)
        }
        .onAppear { model.start() }
    }
}

/// The app's night gradient, used as the page background where a prayer colour doesn't apply
let watchNightGradient = LinearGradient(colors: [Color(red: 15/255, green: 32/255, blue: 39/255),
                                                 Color(red: 32/255, green: 58/255, blue: 67/255),
                                                 Color(red: 44/255, green: 83/255, blue: 100/255)],
                                        startPoint: .top, endPoint: .bottom)

// MARK: - Next prayer

struct NextPrayerPage: View {
    @EnvironmentObject private var model: WatchModel
    
    var body: some View {
        Group {
            if let next = model.nextPrayer {
                VStack(spacing: 3) {
                    // City and Hijri date, small, at the top
                    HStack(spacing: 4) {
                        if !model.locationName.isEmpty {
                            Image(systemName: "location.fill").font(.system(size: 9))
                            Text(model.locationName).lineLimit(1)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    Text(model.hijriDate)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer(minLength: 2)
                    
                    Image(systemName: next.icon)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(model.name(for: next.name))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(next.time, style: .time)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                    Text(timerInterval: Date()...next.time, countsDown: true)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 2)
                    
                    Spacer(minLength: 2)
                    
                    if let following = model.followingPrayer {
                        HStack(spacing: 4) {
                            Text(AppTranslations.translate("Then", to: model.language))
                            Text(model.name(for: following.name)).bold()
                            Text(following.time, style: .time)
                        }
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                    if model.locationSource == .phone {
                        Label(AppTranslations.translate("iPhone location", to: model.language), systemImage: "iphone")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 6)
                .accessibilityElement(children: .combine)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: model.locationDenied ? "location.slash" : "location.fill")
                        .font(.title2)
                        .foregroundStyle(.teal)
                    Text(model.locationDenied
                         ? AppTranslations.translate("Allow location in Settings, or open iPrayer on your iPhone.", to: model.language)
                         : AppTranslations.translate("Locating...", to: model.language))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .containerBackground(for: .tabView) {
            PrayerPalette.palette(for: model.nextPrayer?.name ?? "").gradient
        }
    }
}

// MARK: - Today

struct TodayPage: View {
    @EnvironmentObject private var model: WatchModel
    
    var body: some View {
        List {
            ForEach(model.todayPrayers, id: \.time) { prayer in
                let isNext = prayer.time == model.nextPrayer?.time
                let passed = prayer.time <= Date() && !isNext
                HStack(spacing: 8) {
                    Image(systemName: prayer.icon)
                        .foregroundStyle(passed ? Color.white.opacity(0.35) : PrayerPalette.palette(for: prayer.name).accent)
                        .frame(width: 20)
                    Text(model.name(for: prayer.name))
                        .font(.system(.body, design: .rounded, weight: isNext ? .bold : .regular))
                        .foregroundStyle(passed ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    if passed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                    Text(prayer.time, style: .time)
                        .font(.system(.body, design: .rounded, weight: isNext ? .bold : .regular))
                        .foregroundStyle(isNext ? .teal : (passed ? .secondary : .primary))
                }
                .listRowBackground(isNext ? Color.teal.opacity(0.18) : nil)
                .accessibilityElement(children: .combine)
            }
            if model.todayPrayers.isEmpty {
                Text(AppTranslations.translate("Locating...", to: model.language))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AppTranslations.translate("Today", to: model.language))
        .containerBackground(for: .tabView) { watchNightGradient }
    }
}

// MARK: - Tracker

struct TrackerPage: View {
    @EnvironmentObject private var model: WatchModel
    @ObservedObject private var tracker = HomeWidgetsData.shared
    private let prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("\(tracker.currentStreak) \(AppTranslations.translate("day streak", to: model.language))")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                    Spacer()
                    Text("\(tracker.dailyPrayersCompleted.filter { $0 }.count)/5")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(.teal)
                }
                .accessibilityElement(children: .combine)
            }
            Section {
                ForEach(Array(prayers.enumerated()), id: \.offset) { index, prayer in
                    let done = tracker.dailyPrayersCompleted[index]
                    Button {
                        tracker.togglePrayer(index: index)
                    } label: {
                        HStack {
                            Image(systemName: PrayerSchedule.icon(for: prayer))
                                .foregroundStyle(PrayerPalette.palette(for: prayer).accent)
                                .frame(width: 20)
                            Text(model.name(for: prayer))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(done ? .green : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .accessibilityLabel(model.name(for: prayer))
                    .accessibilityValue(done ? "1" : "0")
                }
            }
        }
        .navigationTitle(AppTranslations.translate("Tracker", to: model.language))
        .containerBackground(for: .tabView) { watchNightGradient }
        .onAppear { tracker.refreshDayState() }
    }
}
