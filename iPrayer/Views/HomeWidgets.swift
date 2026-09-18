import SwiftUI
import Combine

// MARK: - Streak & Habit Tracker Widget
struct StreakWidgetView: View {
    @ObservedObject var data = HomeWidgetsData.shared
    @EnvironmentObject var viewModel: PrayerViewModel
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    let prayers = ["F", "D", "A", "M", "I"]
    let fullPrayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    let colors: [Color] = [.purple, .blue, .orange, .red, .indigo]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.body)
                Text("\(data.currentStreak) " + AppTranslations.translate("Day Streak", to: appLanguage))
                    .font(.custom("AvenirNext-DemiBold", size: 14))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Spacer(minLength: 0)
            
            // 5 Circles
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    let isCompleted = data.dailyPrayersCompleted[index]
                    let prayerName = fullPrayerNames[index]
                    
                    // Check if the prayer has happened yet
                    let hasHappened: Bool = {
                        if let todayItem = viewModel.todayPrayerTimes.first(where: { $0.name == prayerName }) {
                            return Date() >= todayItem.time
                        }
                        return true // Fallback to true if times aren't loaded yet
                    }()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            data.togglePrayer(index: index)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(isCompleted ? .clear : Color.white.opacity(0.3), lineWidth: 1)
                                .background(Circle().fill(isCompleted ? colors[index] : Color.clear))
                            
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text(prayers[index])
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!hasHappened)
                    .opacity(hasHappened ? 1.0 : 0.3)
                }
            }
            
            Text(AppTranslations.translate("Track today's prayers", to: appLanguage))
                .font(.custom("AvenirNext-Medium", size: 10))
                .foregroundColor(.gray)
                .padding(.top, 2)
        }
        .premiumWidgetCard()
    }
}

// MARK: - Duas Library Widget
struct DuaOfTheDayWidgetView: View {
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    // Observed only so the card re-renders when the day changes (the verse model publishes at local midnight)
    @ObservedObject private var verseOfTheDay = VerseOfTheDay.shared
    
    private var dua: AuthenticDua? { DuaLibraryData.shared.duaOfTheDay() }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.teal)
                Text(AppTranslations.translate("Dua of the Day", to: appLanguage))
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.caption2)
                    .foregroundColor(.teal.opacity(0.7))
            }
            
            if let dua {
                Text(dua.displayArabic)
                    .font(.custom("KFGQPC Uthmanic Script HAFS", size: 15))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Arabic reads right to left whatever the app's layout direction is
                    .environment(\.layoutDirection, .rightToLeft)
                
                if appLanguage == "ar" {
                    Spacer(minLength: 0)
                    Text(AppTranslations.translate(dua.category, to: appLanguage))
                        .font(.caption)
                        .foregroundColor(.teal)
                        .lineLimit(1)
                } else {
                    // The translation fills what the Arabic leaves; the library shows the rest
                    Text(AppTranslations.translate(dua.englishTranslation, to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .premiumWidgetCard()
    }
}

// MARK: - Verse of the Day
/// A verse picked from the whole Quran by date (see VerseOfTheDay). Tapping it opens the reader at that verse.
struct AyahWidgetView: View {
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @ObservedObject private var model = VerseOfTheDay.shared
    
    var body: some View {
        if let result = model.verse, let surah = model.surah {
            NavigationLink(destination: SurahDetailView(surah: surah, initialVerse: result.ayah.numberInSurah, marksInitialVerse: true)) {
                card(for: result.ayah, in: surah)
            }
            .buttonStyle(CardPressStyle())
        }
    }
    
    private func reference(for ayah: Ayah, in surah: SurahMetadata) -> String {
        appLanguage == "ar"
            ? "\(surah.name) - \(QuranTextEncoder.arabicDigits(ayah.numberInSurah))"
            : "\(surah.englishName) \(surah.number):\(ayah.numberInSurah)"
    }
    
    private func card(for ayah: Ayah, in surah: SurahMetadata) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.yellow)
                Text(AppTranslations.translate("Verse of the Day", to: appLanguage))
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
                Text(reference(for: ayah, in: surah))
                    .font(.caption)
                    .foregroundColor(.teal)
                Image(systemName: "chevron.forward")
                    .font(.caption2)
                    .foregroundColor(.teal.opacity(0.7))
            }
            
            // Long verses are cut after two lines so the card always fits above the tab bar; it opens the reader at the verse
            Text(ayah.displayText)
                .font(.custom("KFGQPC Uthmanic Script HAFS", size: 21))
                .foregroundColor(.white)
                .lineSpacing(3)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Arabic reads right to left whatever the app's layout direction is
                .environment(\.layoutDirection, .rightToLeft)
        }
        .premiumWidgetCard(height: nil)
    }
}
