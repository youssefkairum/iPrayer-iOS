
//
//  PrayerDetailView.swift
//  iPrayer
//

import SwiftUI

struct PrayerDetailView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    let nextPrayerName: String

    var theme: PrayerTheme {
        PrayerTheme.theme(for: nextPrayerName)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppTranslations.translate("Prayer Times", to: appLanguage))
                        .font(.custom("AvenirNext-Bold", size: 32))
                        .foregroundColor(.white)
                    Text(AppTranslations.translate("Today's full schedule", to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 16))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Themed divider bar
                theme.gradient
                    .frame(height: 3)
                    .cornerRadius(2)
                    .padding(.horizontal)

                // Timeline
                VStack(spacing: 12) {
                    ForEach(viewModel.prayerTimes) { prayer in
                        DetailTimelineRow(prayer: prayer)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "0F2027").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "0F2027"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct DetailTimelineRow: View {
    let prayer: PrayerItem
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"

    var isPast: Bool {
        return !prayer.isNext && prayer.time < Date()
    }

    var theme: PrayerTheme {
        PrayerTheme.theme(for: prayer.name)
    }

    var body: some View {
        HStack(spacing: 16) {

            // Icon circle with theme color
            ZStack {
                Circle()
                    .fill(
                        prayer.isNext
                        ? theme.shadowColor
                        : (isPast ? Color.gray.opacity(0.2) : Color.white.opacity(0.08))
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: prayer.isNext ? theme.shadowColor.opacity(0.5) : .clear, radius: 8)

                Image(systemName: prayer.icon)
                    .foregroundColor(prayer.isNext ? .white : (isPast ? .gray : .white.opacity(0.7)))
                    .font(.system(size: 16, weight: .semibold))
            }

            // Name + badge
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(prayer.name))
                    .font(.custom("AvenirNext-DemiBold", size: 19))
                    .foregroundColor(isPast ? .gray : .white)

                if prayer.isNext {
                    Text(AppTranslations.translate("Up next", to: appLanguage))
                        .font(.caption)
                        .foregroundColor(theme.shadowColor)
                } else if isPast {
                    Text(AppTranslations.translate("Passed", to: appLanguage))
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }

            Spacer()

            // Time
            Text(prayer.time, style: .time)
                .font(.system(size: 18, weight: prayer.isNext ? .bold : .medium, design: .monospaced))
                .foregroundColor(prayer.isNext ? theme.shadowColor : (isPast ? .gray : .white.opacity(0.8)))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Material.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            prayer.isNext ? theme.shadowColor.opacity(0.4) : Color.white.opacity(0.05),
                            lineWidth: 1
                        )
                )
        )
        .opacity(isPast ? 0.65 : 1.0)
        .scaleEffect(prayer.isNext ? 1.02 : 1.0)
        .animation(.spring(response: 0.4), value: prayer.isNext)
    }
}
