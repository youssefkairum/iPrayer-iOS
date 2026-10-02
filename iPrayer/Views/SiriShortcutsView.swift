import SwiftUI
import AppIntents

/// Settings > Siri & Shortcuts: what to say, as the system itself phrases it.
///
/// `SiriTipView` reads each shortcut's phrase from the App Shortcuts metadata in the DEVICE language,
/// which is the language Siri actually answers to; nothing on this screen is typed in by hand, so a hint
/// cannot drift from `AppShortcuts.xcstrings`. `ShortcutsLink` opens the app's page in the Shortcuts
/// app, where a shortcut can be renamed to anything: the only way to leave the app's name out of a
/// phrase, which Apple otherwise requires of every third-party shortcut.
struct SiriShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"

    /// The two app languages Siri does not speak. Their speakers get the shortcuts and the answers, but
    /// must ask in one of Siri's languages, so the screen says so instead of showing phrases they cannot use.
    private static let languagesWithoutSiri: Set<String> = ["ur", "hi"]

    /// The direction of the language the tips are WRITTEN in: the one whose `AppShortcuts.strings` the
    /// bundle resolves to, which is Arabic or a left-to-right language. Not the device locale: an Urdu
    /// phone is right-to-left but has no Urdu phrases, so its tips are English and must lay out that way.
    private static var tipLayoutDirection: LayoutDirection {
        guard let url = Bundle.main.url(forResource: "AppShortcuts", withExtension: "strings") else { return .leftToRight }
        let language = url.deletingLastPathComponent().deletingPathExtension().lastPathComponent
        return Locale(identifier: language).language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }
    
    /// The parameterised shortcut needs a value to show a phrase; Fajr is the one everyone knows.
    private var prayerTimeExample: PrayerTimeIntent {
        var intent = PrayerTimeIntent()
        intent.prayer = .fajr
        return intent
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            BackgroundPatternView()
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Text(AppTranslations.translate("Siri & Shortcuts", to: appLanguage))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppTranslations.translate("Say “Hey Siri”, then one of these:", to: appLanguage))
                            .font(.custom("AvenirNext-Medium", size: 15))
                            .foregroundColor(.white.opacity(0.85))

                        if Self.languagesWithoutSiri.contains(appLanguage) {
                            Text(AppTranslations.translate("Siri does not speak Urdu or Hindi yet. Ask in one of Siri's languages, such as English.", to: appLanguage))
                                .font(.custom("AvenirNext-Medium", size: 13))
                                .foregroundColor(.teal)
                        }

                        // The tips are in the language their phrases resolve to, so they take THAT
                        // direction, not the app's: an English tip laid out right-to-left (app in Arabic
                        // on an English phone) put its closing quote at the start of the line.
                        VStack(spacing: 10) {
                            SiriTipView(intent: NextPrayerIntent())
                            SiriTipView(intent: prayerTimeExample)
                            SiriTipView(intent: QiblaDirectionIntent())
                            SiriTipView(intent: OpenQiblaCompassIntent())
                            SiriTipView(intent: ContinueReadingIntent())
                            SiriTipView(intent: OpenTasbihIntent())
                        }
                        .siriTipViewStyle(.dark)
                        .environment(\.layoutDirection, Self.tipLayoutDirection)

                        Text(AppTranslations.translate("Prefer a shorter phrase? In the Shortcuts app, add a shortcut from any iPrayer action and give it a name of your own, then say that name.", to: appLanguage))
                            .font(.custom("AvenirNext-Medium", size: 13))
                            .foregroundColor(.gray)
                            .padding(.top, 4)

                        HStack {
                            Spacer()
                            ShortcutsLink()
                                .shortcutsLinkStyle(.dark)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
