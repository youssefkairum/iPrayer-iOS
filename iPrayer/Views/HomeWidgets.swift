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
struct DuasLibraryWidgetView: View {
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer(minLength: 0)
            
            Image(systemName: "hands.sparkles.fill")
                .font(.system(size: 38))
                .foregroundColor(.teal)
            
            Text(AppTranslations.translate("Duas", to: appLanguage))
                .font(.custom("AvenirNext-DemiBold", size: 16))
                .foregroundColor(.white)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .premiumWidgetCard()
    }
}

// MARK: - Ayah Widget
struct AyahWidgetView: View {
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    let ayah = HomeWidgetsData.shared.todaysAyah
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.yellow)
                Text(AppTranslations.translate("Verse of the Day", to: appLanguage))
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
            }
            
            Text(ayah.arabicText)
                .font(.custom("KFGQPC Uthmanic Script HAFS", size: 22))
                .foregroundColor(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
            
            // Only an English rendering is bundled; Arabic readers don't need it
            if appLanguage != "ar" {
                Text(ayah.englishText)
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Text(ayah.reference)
                .font(.caption)
                .foregroundColor(.teal)
        }
        .premiumWidgetCard(height: nil)
    }
}
