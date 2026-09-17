import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func scheduleQuranReminders(surahName: String? = nil) {
        let center = UNUserNotificationCenter.current()
        
        // Cancel all existing Quran reminders to avoid duplicates or outdated Surah names
        center.getPendingNotificationRequests { requests in
            let quranRequestIdentifiers = requests.filter { $0.identifier.hasPrefix("quran_reminder_") }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: quranRequestIdentifiers)
            
            // Schedule new reminders
            self.scheduleNewReminders(surahName: surahName)
        }
    }
    
    private func scheduleNewReminders(surahName: String?) {
        let center = UNUserNotificationCenter.current()
        
        // We will schedule 14 daily notifications (2 weeks in advance)
        for dayOffset in 1...14 {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Daily Quran Reminder")
            
            if let surah = surahName, !surah.isEmpty {
                // The string interpolation here will trigger a localized string lookup with a '%@' format
                content.body = String(localized: "Continue your journey. Take a moment to read Surah \(surah) today.")
            } else {
                content.body = String(localized: "Take a moment to read a portion of the Quran today.")
            }
            
            content.sound = .default
            
            // Generate a random time between 9:00 AM and 8:00 PM (20:00)
            let randomHour = Int.random(in: 9...19)
            let randomMinute = Int.random(in: 0...59)
            
            // Calculate the date
            var dateComponents = DateComponents()
            dateComponents.hour = randomHour
            dateComponents.minute = randomMinute
            
            // Add day offset
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            
            let targetComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.year = targetComponents.year
            dateComponents.month = targetComponents.month
            dateComponents.day = targetComponents.day
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "quran_reminder_\(dayOffset)", content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling Quran reminder: \(error.localizedDescription)")
                }
            }
        }
        
        print("Successfully scheduled 14 daily Quran reminders with random times between 9AM and 8PM.")
    }
}
