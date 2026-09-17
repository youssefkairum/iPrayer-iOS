import Foundation
import SwiftUI
import Combine

struct AyahSnippet: Codable {
    let englishText: String
    let arabicText: String
    let reference: String
}

struct DuaSnippet: Codable {
    let text: String
    let reference: String
}

class HomeWidgetsData: ObservableObject {
    static let shared = HomeWidgetsData()
    
    // MARK: - Published properties
    @Published var dhikrCount: Int = 0 {
        didSet { UserDefaults.standard.set(dhikrCount, forKey: "dhikrCount") }
    }
    
    @Published var currentStreak: Int = 0 {
        didSet { UserDefaults.standard.set(currentStreak, forKey: "currentStreak") }
    }
    
    @Published var dailyPrayersCompleted: [Bool] = [false, false, false, false, false] {
        didSet { UserDefaults.standard.set(dailyPrayersCompleted, forKey: "dailyPrayersCompleted") }
    }
    
    private var lastCompletedStreakDateStr: String {
        get { UserDefaults.standard.string(forKey: "lastCompletedStreakDate") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastCompletedStreakDate") }
    }
    
    private var lastDhikrResetDateStr: String {
        get { UserDefaults.standard.string(forKey: "lastDhikrResetDate") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastDhikrResetDate") }
    }
    
    private var lastTrackerDateStr: String {
        get { UserDefaults.standard.string(forKey: "lastTrackerDate") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastTrackerDate") }
    }
    
    // MARK: - Curated Content
    let dailyAyahs: [AyahSnippet] = [
        AyahSnippet(englishText: "Indeed, with hardship [will be] ease.", arabicText: "إِنَّ مَعَ الْعُسْرِ يُسْرًا", reference: "Quran 94:6"),
        AyahSnippet(englishText: "So remember Me; I will remember you.", arabicText: "فَاذْكُرُونِي أَذْكُرْكُمْ", reference: "Quran 2:152"),
        AyahSnippet(englishText: "And He found you lost and guided [you].", arabicText: "وَوَجَدَكَ ضَالًّا فَهَدَىٰ", reference: "Quran 93:7"),
        AyahSnippet(englishText: "My mercy encompasses all things.", arabicText: "وَرَحْمَتِي وَسِعَتْ كُلَّ شَيْءٍ", reference: "Quran 7:156"),
        AyahSnippet(englishText: "Allah does not burden a soul beyond that it can bear.", arabicText: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا", reference: "Quran 2:286"),
        AyahSnippet(englishText: "And whoever relies upon Allah - then He is sufficient for him.", arabicText: "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ", reference: "Quran 65:3"),
        AyahSnippet(englishText: "Unquestionably, by the remembrance of Allah hearts are assured.", arabicText: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", reference: "Quran 13:28")
    ]
    
    let dailyDuas: [DuaSnippet] = [
        DuaSnippet(text: "O Allah, I ask You for beneficial knowledge, goodly provision and acceptable deeds.", reference: "Morning Supplication"),
        DuaSnippet(text: "O Allah, You are forgiving and love forgiveness, so forgive me.", reference: "Dua of Aisha (RA)"),
        DuaSnippet(text: "O turner of the hearts, keep my heart firm upon Your religion.", reference: "Dua of the Prophet (SAW)"),
        DuaSnippet(text: "O Allah, I seek refuge in You from anxiety and sorrow, weakness and laziness.", reference: "Bukhari"),
        DuaSnippet(text: "Our Lord, grant us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.", reference: "Quran 2:201"),
        DuaSnippet(text: "O Allah, guide me among those whom You have guided.", reference: "Sunan an-Nasa'i"),
        DuaSnippet(text: "O Allah, I ask You for Your love and the love of those who love You.", reference: "Tirmidhi")
    ]
    
    // Computed Properties
    var todaysAyah: AyahSnippet {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % dailyAyahs.count
        return dailyAyahs[index]
    }
    
    var todaysDua: DuaSnippet {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % dailyDuas.count
        return dailyDuas[index]
    }
    
    init() {
        self.dhikrCount = UserDefaults.standard.integer(forKey: "dhikrCount")
        self.currentStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        if let savedTracker = UserDefaults.standard.array(forKey: "dailyPrayersCompleted") as? [Bool], savedTracker.count == 5 {
            self.dailyPrayersCompleted = savedTracker
        }
        checkAndResetDhikr()
        checkAndResetTracker()
    }
    
    // MARK: - Logic
    
    func incrementDhikr() {
        checkAndResetDhikr()
        dhikrCount += 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func resetDhikr() {
        dhikrCount = 0
    }
    
    private func checkAndResetDhikr() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        if lastDhikrResetDateStr != todayStr {
            dhikrCount = 0
            lastDhikrResetDateStr = todayStr
        }
    }
    
    func togglePrayer(index: Int) {
        guard index >= 0 && index < 5 else { return }
        dailyPrayersCompleted[index].toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        evaluateStreak()
    }
    
    private func checkAndResetTracker() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        // Reset daily booleans if it's a new day
        if lastTrackerDateStr != todayStr {
            dailyPrayersCompleted = [false, false, false, false, false]
            lastTrackerDateStr = todayStr
        }
        
        // Break streak if missed yesterday
        if lastCompletedStreakDateStr != todayStr {
            if let lastDate = formatter.date(from: lastCompletedStreakDateStr) {
                let daysDifference = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                if daysDifference > 1 {
                    currentStreak = 0 // Streak broken
                }
            } else if lastCompletedStreakDateStr == "" {
                currentStreak = 0
            }
        }
    }
    
    private func evaluateStreak() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        let allCompleted = dailyPrayersCompleted.allSatisfy { $0 == true }
        
        if allCompleted {
            if lastCompletedStreakDateStr != todayStr {
                currentStreak += 1
                lastCompletedStreakDateStr = todayStr
            }
        } else {
            if lastCompletedStreakDateStr == todayStr {
                currentStreak = max(0, currentStreak - 1)
                
                // Set last completed date to yesterday so it can be re-incremented if they check it again
                if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                    lastCompletedStreakDateStr = formatter.string(from: yesterday)
                } else {
                    lastCompletedStreakDateStr = ""
                }
            }
        }
    }
}
