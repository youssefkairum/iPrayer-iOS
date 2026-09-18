import SwiftUI
import Combine

struct PrayerTheme {
    let gradient: LinearGradient
    let shadowColor: Color
    
    /// Colors come from PrayerPalette, which the widget and the Live Activity use too
    static func theme(for prayerName: String) -> PrayerTheme {
        let palette = PrayerPalette.palette(for: prayerName)
        return PrayerTheme(gradient: palette.gradient, shadowColor: palette.glow)
    }
}

/// Lets a screen ask for dark status bar text. The app is dark everywhere except the Quran reader's
/// paper page. The root view pins its content to the dark scheme and only flips the window's scheme,
/// which is what the status bar follows.
final class AppAppearance: ObservableObject {
    static let shared = AppAppearance()
    @Published var prefersLightStatusBar = false
    private init() {}
}
