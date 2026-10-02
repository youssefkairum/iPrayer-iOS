//
//  PrayerIntents.swift
//  iPrayer
//
//  Siri, Shortcuts and Spotlight. Six actions: three that ANSWER (next prayer, a prayer's time, the Qibla
//  bearing) and three that OPEN a screen (the compass, the Quran where you left off, the Tasbih).
//
//  Three rules hold this file together, each learned by building a probe rather than by reading docs:
//
//  1. THE APP NEVER CHOOSES THE LANGUAGE. Phrases follow the Siri language, titles follow the device
//     language, and neither follows the in-app `appLanguage` setting — the system reads the bundle, not
//     our code. So every sentence Siri speaks is a `LocalizedStringResource` the SYSTEM resolves, with the
//     prayer name nested as its own resource and the time interpolated with `format:`. Passing in a
//     String we already translated, or a time we already formatted, pins those parts to the app's
//     language and produces "Das nächste Gebet ist Maghrib um 5:13 PM" — or Arabic text read aloud by an
//     English voice. `AppTranslations` therefore has no place in a dialog.
//
//  2. TWO STRING TABLES, on purpose. Everything here lives in `AppIntents.xcstrings` (table "AppIntents")
//     so it stays out of `Localizable.xcstrings`, which Xcode rewrites on every IDE build. The exception
//     is the six prayer NAMES, which stay in the default table: Siri's training step only picked up
//     spoken parameter values from there, and with a custom table Arabic Siri was trained to hear the
//     English names.
//
//  3. NO WRITES. Marking a prayer as prayed and counting a tasbih by voice are deliberately absent. Both
//     go through sync paths (iCloud, the watch) that are only started when a window appears, and the
//     tracker's ordering rules (HANDOFF §3, PR #20) were hard-won. They want a two-device test first.
//
//  Phrases are localised in `AppShortcuts.xcstrings`, for the seven of the app's nine languages that Siri
//  can listen in. Hindi and Urdu are device languages but not Siri languages, so they get titles and
//  dialog — the shortcuts appear, named in those languages, in the Shortcuts app — and no phrases.
//

import AppIntents
import Foundation
import Adhan

// MARK: - Which prayer

/// The six daily times. Raw values are the app's canonical English keys (`PrayerSchedule.prayerNames`),
/// which is what the schedule, the colours and the icons are all keyed by.
enum PrayerChoice: String, AppEnum {
    case fajr = "Fajr"
    case sunrise = "Sunrise"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Prayer", table: "AppIntents"))

    // Default table, NOT "AppIntents": see rule 2 above. These six keys already exist in
    // Localizable.xcstrings, marked manual and translated in all eight languages.
    static let caseDisplayRepresentations: [PrayerChoice: DisplayRepresentation] = [
        .fajr: "Fajr",
        .sunrise: "Sunrise",
        .dhuhr: "Dhuhr",
        .asr: "Asr",
        .maghrib: "Maghrib",
        .isha: "Isha"
    ]
}

// MARK: - Reading the schedule

/// The same three calls the widgets make, so Siri answers exactly what the Home Screen shows. No view
/// model, no location fix, no main actor: it works with the app freshly launched in the background.
nonisolated enum SiriSchedule {
    /// Yesterday's, today's and tomorrow's times, in order. Nil until the app has saved a location once.
    /// Yesterday is there because a day's Isha can fall AFTER midnight (Bordeaux in June: 00:11), and
    /// because where the civil date runs ahead of the sun (Apia) "today's" times all land tomorrow.
    static func prayers(now: Date = Date()) -> [ScheduledPrayer]? {
        guard let config = SharedPrayerConfig.load() else { return nil }
        let parameters = PrayerSchedule.parameters(method: config.calculationMethod, madhab: config.madhab)
        return PrayerSchedule.prayers(latitude: config.latitude, longitude: config.longitude,
                                      parameters: parameters, dayOffsets: -1...1, from: now)
    }

    /// The name of a prayer as a resource the SYSTEM localises, so it lands in the sentence's language.
    static func name(_ englishKey: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(englishKey))
    }

    /// Spoken when there is no saved location to compute from.
    static let needsLocation = LocalizedStringResource(
        "Location access is needed to show prayer times.", table: "AppIntents")
}

// MARK: - Answers

struct NextPrayerIntent: AppIntent {
    static let title = LocalizedStringResource("Next Prayer", table: "AppIntents")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(Self.answer()))
    }
    
    /// The sentence, unresolved: whoever speaks it decides the language.
    static func answer(now: Date = Date()) -> LocalizedStringResource {
        // Sunrise is on the timetable but it is not a prayer: it marks the END of Fajr. The Home card
        // shows it as the next TIME; asked for the next PRAYER, the honest answer skips it, as the
        // notifications do.
        guard let next = SiriSchedule.prayers(now: now)?.first(where: { $0.time > now && $0.name != "Sunrise" }) else {
            return SiriSchedule.needsLocation
        }
        let name = SiriSchedule.name(next.name)
        // "How long until the next prayer" is one of the phrases, so the answer carries the wait as well
        // as the clock time: whole minutes, never under one, in the sentence's own language and units.
        let remaining = Duration.seconds(max(60, Int(next.time.timeIntervalSince(now))))
        return LocalizedStringResource(
            "The next prayer is \(name) at \(next.time, format: .dateTime.hour().minute()), in \(remaining, format: .units(allowed: [.hours, .minutes], width: .wide, maximumUnitCount: 2)).",
            table: "AppIntents")
    }
}

struct PrayerTimeIntent: AppIntent {
    static let title = LocalizedStringResource("Prayer Time", table: "AppIntents")

    @Parameter(title: LocalizedStringResource("Prayer", table: "AppIntents"),
               requestValueDialog: IntentDialog(LocalizedStringResource("Which prayer?", table: "AppIntents")))
    var prayer: PrayerChoice

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(Self.answer(for: prayer)))
    }
    
    static func answer(for prayer: PrayerChoice, now: Date = Date()) -> LocalizedStringResource {
        // The NEXT time it comes round, and the sentence names no day. "When is Fajr" asked at night
        // means the one they will wake for, which on the night the clocks change is an hour away from
        // this morning's; and a sentence saying "today" is false for an Isha that falls after midnight.
        guard let match = SiriSchedule.prayers(now: now)?
            .first(where: { $0.name == prayer.rawValue && $0.time > now }) else {
            return SiriSchedule.needsLocation
        }
        let name = SiriSchedule.name(match.name)
        return LocalizedStringResource(
            "\(name) is at \(match.time, format: .dateTime.hour().minute()).", table: "AppIntents")
    }
}

struct QiblaDirectionIntent: AppIntent {
    static let title = LocalizedStringResource("Qibla Direction", table: "AppIntents")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(Self.answer()))
    }
    
    static func answer() -> LocalizedStringResource {
        guard let config = SharedPrayerConfig.load() else { return SiriSchedule.needsLocation }
        // A bearing needs only where you are, not which way the phone points. Live "turn left, turn
        // right" guidance needs the magnetometer, which is what the compass intent below opens.
        let bearing = Qibla(coordinates: Coordinates(latitude: config.latitude, longitude: config.longitude)).direction
        return LocalizedStringResource("The Qibla is \(Int(bearing.rounded()))° from north.", table: "AppIntents")
    }
}

// MARK: - Opening a screen

struct OpenQiblaCompassIntent: AppIntent {
    static let title = LocalizedStringResource("Qibla Compass", table: "AppIntents")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.open(.qibla)
        return .result()
    }
}

struct ContinueReadingIntent: AppIntent {
    static let title = LocalizedStringResource("Continue Reading", table: "AppIntents")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        let surah = defaults.integer(forKey: UDKey.lastReadSurahNumber.rawValue)
        // 0 means nothing has been read yet: open the Quran tab and let them choose.
        guard (1...114).contains(surah) else {
            DeepLinkRouter.shared.open(.quran)
            return .result()
        }
        let verse = max(1, defaults.integer(forKey: UDKey.lastReadVerse.rawValue))
        DeepLinkRouter.shared.open(.quran, verse: .init(surah: surah, verse: verse, isResume: true))
        return .result()
    }
}

struct OpenTasbihIntent: AppIntent {
    static let title = LocalizedStringResource("Tasbih", table: "AppIntents")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.open(.tasbih)
        return .result()
    }
}

// MARK: - What Siri listens for

/// Every phrase must contain the app name — the build fails otherwise — and at most one parameter.
/// The FIRST phrase of each shortcut is its key in AppShortcuts.xcstrings: change one, change the other.
struct IPrayerShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: [
                "When is the next prayer in \(.applicationName)",
                "Next prayer in \(.applicationName)",
                "What is the next prayer in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Next Prayer", table: "AppIntents"),
            systemImageName: "clock.fill"
        )
        AppShortcut(
            intent: PrayerTimeIntent(),
            phrases: [
                "When is \(\.$prayer) in \(.applicationName)",
                "What time is \(\.$prayer) in \(.applicationName)",
                "\(\.$prayer) time in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Prayer Time", table: "AppIntents"),
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: QiblaDirectionIntent(),
            phrases: [
                "Which way is the Qibla in \(.applicationName)",
                "Qibla direction in \(.applicationName)",
                "Where is the Qibla in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Qibla Direction", table: "AppIntents"),
            systemImageName: "location.north.line.fill"
        )
        AppShortcut(
            intent: OpenQiblaCompassIntent(),
            phrases: [
                "Open the Qibla compass in \(.applicationName)",
                "Qibla compass in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Qibla Compass", table: "AppIntents"),
            systemImageName: "safari.fill"
        )
        AppShortcut(
            intent: ContinueReadingIntent(),
            phrases: [
                "Continue reading the Quran in \(.applicationName)",
                "Open the Quran in \(.applicationName)",
                "Continue my reading in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Continue Reading", table: "AppIntents"),
            systemImageName: "book.fill"
        )
        AppShortcut(
            intent: OpenTasbihIntent(),
            phrases: [
                "Open Tasbih in \(.applicationName)",
                "Start Tasbih in \(.applicationName)",
                "Tasbih in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Tasbih", table: "AppIntents"),
            systemImageName: "circle.grid.cross.fill"
        )
    }
}


// MARK: - Debug

#if DEBUG
/// `-debugSiriDialogs 1` logs every answer in every language the app ships, resolved the way the system
/// would resolve it. Siri cannot be spoken to from a script, and the Simulator shows every result banner
/// in English whatever the device language (its own "Done" button included, on a Simulator rebooted
/// into Arabic), so this is the only way to READ the nine versions of each sentence without nine devices. Read back with `log show --predicate 'eventMessage CONTAINS "SiriDialog"'`.
nonisolated enum SiriDebug {
    static func logDialogsIfAsked() {
        guard UserDefaults.standard.integer(forKey: "debugSiriDialogs") > 0 else { return }
        let answers: [(String, LocalizedStringResource)] = [
            ("next", NextPrayerIntent.answer()),
            ("time", PrayerTimeIntent.answer(for: .maghrib)),
            ("qibla", QiblaDirectionIntent.answer()),
            ("nolocation", SiriSchedule.needsLocation)
        ]
        // What an intent run on THIS device would say, with nothing forced: the line to read when a
        // banner comes back in the wrong language.
        NSLog("[SiriDialog] device %@ app %@ locale %@: %@", Locale.preferredLanguages.first ?? "-",
              Bundle.main.preferredLocalizations.first ?? "-", Locale.current.identifier,
              String(localized: NextPrayerIntent.answer()))
        for language in ["en"] + AppTranslations.supportedLanguages.filter({ $0 != "en" }) {
            for (label, answer) in answers {
                var resource = answer
                resource.locale = Locale(identifier: language)
                NSLog("[SiriDialog] %@ %@: %@", language, label, String(localized: resource))
            }
        }
    }
}
#endif
