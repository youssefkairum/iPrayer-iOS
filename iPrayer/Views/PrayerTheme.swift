import SwiftUI

struct PrayerTheme {
    let gradient: LinearGradient
    let shadowColor: Color
    
    static func theme(for prayerName: String) -> PrayerTheme {
        switch prayerName {
        case "Fajr":
            return PrayerTheme(
                gradient: LinearGradient(colors: [Color(hex: "4B3B5C"), Color(hex: "E58C8A")], startPoint: .topLeading, endPoint: .bottomTrailing),
                shadowColor: Color(hex: "E58C8A")
            )
        case "Sunrise":
            return PrayerTheme(
                gradient: LinearGradient(colors: [Color(hex: "FF512F"), Color(hex: "F09819")], startPoint: .topLeading, endPoint: .bottomTrailing),
                shadowColor: Color(hex: "F09819")
            )
        case "Dhuhr":
            return PrayerTheme(
                gradient: LinearGradient(colors: [Color(hex: "2980B9"), Color(hex: "6DD5FA")], startPoint: .topLeading, endPoint: .bottomTrailing),
                shadowColor: Color(hex: "6DD5FA")
            )
        case "Asr":
            return PrayerTheme(
                gradient: LinearGradient(colors: [Color(hex: "F2994A"), Color(hex: "F2C94C")], startPoint: .topLeading, endPoint: .bottomTrailing),
                shadowColor: Color(hex: "F2994A")
            )
        case "Maghrib":
            return PrayerTheme(
                gradient: LinearGradient(colors: [Color(hex: "C33764"), Color(hex: "1D2671")], startPoint: .topLeading, endPoint: .bottomTrailing),
                shadowColor: Color(hex: "C33764")
            )
        case "Isha":
            return PrayerTheme(
                gradient: LinearGradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43")], startPoint: .topLeading, endPoint: .bottomTrailing),
                shadowColor: Color(hex: "203A43")
            )
        default:
            return PrayerTheme(
                gradient: LinearGradient(colors: [Color.teal.opacity(0.8), Color.blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                shadowColor: .teal
            )
        }
    }
}
