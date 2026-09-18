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
        TabView {
            NextPrayerPage()
            TodayPage()
            TrackerPage()
            TasbihPage()
            QiblaPage()
        }
        .tabViewStyle(.verticalPage)
        .onAppear { model.start() }
    }
}

// MARK: - Next prayer

struct NextPrayerPage: View {
    @EnvironmentObject private var model: WatchModel
    
    var body: some View {
        ZStack {
            PrayerPalette.palette(for: model.nextPrayer?.name ?? "").gradient
                .ignoresSafeArea()
            
            if let next = model.nextPrayer {
                VStack(spacing: 4) {
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
                    if model.locationSource == .phone {
                        Label(AppTranslations.translate("iPhone location", to: model.language), systemImage: "iphone")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.top, 4)
                    }
                }
                .padding()
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
    }
}

// MARK: - Today

struct TodayPage: View {
    @EnvironmentObject private var model: WatchModel
    
    var body: some View {
        List {
            ForEach(model.todayPrayers, id: \.time) { prayer in
                let isNext = prayer.time == model.nextPrayer?.time
                HStack(spacing: 8) {
                    Image(systemName: prayer.icon)
                        .foregroundStyle(PrayerPalette.palette(for: prayer.name).accent)
                        .frame(width: 20)
                    Text(model.name(for: prayer.name))
                        .font(.system(.body, design: .rounded, weight: isNext ? .bold : .regular))
                        .lineLimit(1)
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.system(.body, design: .rounded, weight: isNext ? .bold : .regular))
                        .foregroundStyle(isNext ? .teal : .primary)
                }
                .listRowBackground(isNext ? Color.teal.opacity(0.18) : nil)
            }
            if model.todayPrayers.isEmpty {
                Text(AppTranslations.translate("Locating...", to: model.language))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AppTranslations.translate("Today", to: model.language))
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
                }
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
                        }
                    }
                }
            }
        }
        .navigationTitle(AppTranslations.translate("Tracker", to: model.language))
        .onAppear { tracker.refreshDayState() }
    }
}
