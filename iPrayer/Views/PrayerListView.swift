//
//  PrayerListView.swift
//  iPrayer
//

import SwiftUI
import Combine

struct PrayerListView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @StateObject private var accountManager = AccountManager.shared
    @Environment(\.openURL) private var openURL
    @ObservedObject private var entrance = AppEntrance.shared
    
    // Grid layout for the home widgets
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    // Coarse timer used only to recalculate once the next prayer has passed.
    // The per-second countdown lives inside HeroCard so it doesn't re-render this whole screen.
    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
    var islamicDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }
    
    private var timeGreetingString: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }
    
    /// "مساء الخير، يوسف" — the greeting, then the person.
    ///
    /// The comma is a LANGUAGE choice, not a constant. Arabic and Urdu write it ARABIC COMMA (U+060C, ،)
    /// and Chinese writes it fullwidth (U+FF0C, ，); a Latin comma in any of the three is a typographic
    /// error, and it was shipping in all eight languages because the format string was written in English.
    ///
    /// The name goes in a first-strong isolate so a Latin name beside a neutral comma cannot drag the
    /// punctuation to the wrong side of the phrase — the same rule as §3 and as the Home card's time.
    private func greeting(with name: String) -> String {
        let hello = AppTranslations.translate(timeGreetingString, to: appLanguage)
        let comma: String
        switch appLanguage {
        case "ar", "ur": comma = "،"
        case "zh-Hans":  comma = "，"
        default:         comma = ","
        }
        return "\(hello)\(comma) \u{2068}\(name)\u{2069}"
    }
    
    var body: some View {
        let name = accountManager.userName.trimmingCharacters(in: .whitespaces)
        let firstName = name.components(separatedBy: " ").first ?? name
        
        // No inner NavigationView: pushes go through the NavigationStack in ContentView,
        // whose gradient background would otherwise be hidden by the navigation container.
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 13) {
                
                // 1. DASHBOARD HEADER
                // The location pill sits on the date line so the greeting has the full width: with a name
                // it stays on one line (shrinking a little if needed) instead of wrapping and pushing the
                // Verse of the Day under the tab bar.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center) {
                        Text(islamicDate)
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer()
                        
                        // Location Pill
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.teal)
                            Text(viewModel.locationName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                    }
                    
                    Group {
                        if !firstName.isEmpty {
                            // One Text so the comma and name can't wrap onto a second line
                            Text(greeting(with: firstName))
                        } else {
                            Text(AppTranslations.translate(timeGreetingString, to: appLanguage))
                        }
                    }
                    .font(.custom("AvenirNext-Bold", size: 34))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .entrance(0, shown: entrance.contentRevealed)
                
                // 2. HERO CARD (Next Prayer) — Tappable
                Group {
                if let nextPrayer = viewModel.prayerTimes.first(where: { $0.isNext }) {
                    NavigationLink(destination: PrayerDetailView(nextPrayerName: nextPrayer.name)
                        .environmentObject(viewModel)
                    ) {
                        HeroCard(
                            prayerName: nextPrayer.name,
                            prayerTime: nextPrayer.time,
                            icon: nextPrayer.icon
                        )
                    }
                    .buttonStyle(CardPressStyle())
                    .padding(.horizontal)
                } else if viewModel.locationAuthorization == .notDetermined {
                    // Location hasn't been decided yet (the onboarding slide was skipped): ask here, with the reason
                    LocationErrorCard(
                        icon: "location.fill",
                        iconColor: .teal,
                        message: AppTranslations.translate("iPrayer uses your location to calculate prayer times and the Qibla direction.", to: appLanguage),
                        buttonTitle: AppTranslations.translate("Enable Location", to: appLanguage)
                    ) {
                        viewModel.requestLocationAccess()
                    }
                    .padding(.horizontal)
                } else if let error = viewModel.locationError {
                    LocationErrorCard(
                        message: AppTranslations.translate(error, to: appLanguage),
                        buttonTitle: AppTranslations.translate("Open Settings", to: appLanguage)
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Text("Loading Prayers...")
                        .foregroundColor(.white)
                        .padding(.top, 50)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                }
                .entrance(1, shown: entrance.contentRevealed)
                
                // 3. WIDGETS GRID
                LazyVGrid(columns: columns, spacing: 10) {
                    StreakWidgetView()
                    NavigationLink(destination: DuaLibraryView(highlightID: DuaLibraryData.shared.duaOfTheDay()?.id)) {
                        DuaOfTheDayWidgetView()
                    }
                    .buttonStyle(CardPressStyle())
                }
                .padding(.horizontal)
                .entrance(2, shown: entrance.contentRevealed)
                
                // 4. THE FOLLOWING DAY
                // The hero card already opens the current schedule, so this card looks one day further ahead
                if !viewModel.followingDayPrayerTimes.isEmpty {
                    DayScheduleCard(prayers: viewModel.followingDayPrayerTimes)
                        .padding(.horizontal)
                        .entrance(3, shown: entrance.contentRevealed)
                }
                
                // 5. VERSE OF THE DAY
                AyahWidgetView()
                    .padding(.horizontal)
                    .entrance(4, shown: entrance.contentRevealed)
            }
            .padding(.top, 12)
            .padding(.bottom, 100) // Clear the floating tab bar
        }
        .navigationBarHidden(true)
        .onReceive(refreshTimer) { _ in
            if let nextPrayer = viewModel.prayerTimes.first(where: { $0.isNext }),
               nextPrayer.time.timeIntervalSinceNow < -60 {
                viewModel.refreshPrayers()
            }
        }
    }
}

// MARK: - Subviews

struct HeroCard: View {
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    let prayerName: String
    let prayerTime: Date
    let icon: String
    
    var theme: PrayerTheme {
        PrayerTheme.theme(for: prayerName)
    }
    
    var body: some View {
        ZStack {
            // Dynamic Background inside the card
            theme.gradient
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white)
                    Spacer()
                    Text(AppTranslations.translate("NEXT", to: appLanguage))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(AppTranslations.translate(prayerName, to: appLanguage))
                            .font(.custom("AvenirNext-Bold", size: 38))
                            .foregroundColor(.white)
                        
                        // The time is wrapped in a first-strong isolate (U+2068…U+2069) so it takes its direction from its own
                        // content. Without it, Arabic rendered the pieces out of order ("at, AM, 3:49").
                        Text(verbatim: "\(AppTranslations.translate("at", to: appLanguage)) \u{2068}\(prayerTime.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: appLanguage))))\u{2069}")
                            .font(.custom("AvenirNext-Medium", size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(AppTranslations.translate("Starts in", to: appLanguage))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        // TimelineView redraws only this text once per second
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(countdown(at: context.date))
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: theme.shadowColor.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private func countdown(at date: Date) -> String {
        let diff = max(0, Int(prayerTime.timeIntervalSince(date)))
        return String(format: "%02d:%02d:%02d", diff / 3600, (diff % 3600) / 60, diff % 60)
    }
}

/// Shown in place of the hero card when location access has been denied.
struct LocationErrorCard: View {
    var icon: String = "location.slash.fill"
    var iconColor: Color = .orange
    let message: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(iconColor)
            
            Text(message)
                .font(.custom("AvenirNext-Medium", size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: action) {
                Text(buttonTitle)
                    .font(.custom("AvenirNext-Bold", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(.teal).interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Material.ultraThinMaterial)
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

/// The following day's times in one compact card, so Home shows what comes next without repeating
/// the schedule behind the hero card.
struct DayScheduleCard: View {
    let prayers: [PrayerItem]
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    private var day: Date { prayers.first?.time ?? Date() }
    
    /// "Tomorrow", or the weekday name once the hero card has itself moved on to tomorrow (after Isha)
    private var title: String {
        if Calendar.current.isDateInTomorrow(day) {
            return AppTranslations.translate("Tomorrow", to: appLanguage)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: day)
    }
    
    /// Hour and minute in the app language ("6:42", or "18:42" where the locale uses 24-hour time)
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.dateFormat = usesTwelveHourClock ? "h:mm" : "H:mm"
        return formatter
    }
    
    /// "AM" / "PM" (or the locale's equivalent), empty for 24-hour locales
    private var periodFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.dateFormat = usesTwelveHourClock ? "a" : ""
        return formatter
    }
    
    private var usesTwelveHourClock: Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale(identifier: appLanguage))?.contains("a") ?? true
    }
    
    var body: some View {
        let formatter = timeFormatter
        let period = periodFormatter
        
        // One quiet row: the day on the left, then each prayer's symbol over its time
        HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("AvenirNext-DemiBold", size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(dateText)
                    .font(.custom("AvenirNext-Medium", size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 58, alignment: .leading)
            
            ForEach(prayers) { prayer in
                VStack(spacing: 2) {
                    // The prayer's symbol in its own accent, the same tone the hero card and Live Activity use
                    Image(systemName: prayer.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PrayerPalette.palette(for: prayer.name).accent)
                        .frame(height: 14)
                    Text(formatter.string(from: prayer.time))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if usesTwelveHourClock {
                        Text(period.string(from: prayer.time))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(AppTranslations.translate(prayer.name, to: appLanguage)) \(formatter.string(from: prayer.time)) \(period.string(from: prayer.time))")
            }
        }
        .premiumWidgetCard(height: nil)
    }
}
