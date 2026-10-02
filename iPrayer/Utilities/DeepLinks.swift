//
//  DeepLinks.swift
//  iPrayer
//
//  `iprayer://verse/<surah>/<ayah>` opens the reader at a verse. The Verse of the Day widget uses it.
//  `iprayer://open/<tab>` (prayers, quran, tasbih, qibla, settings) switches tab.
//
//  Siri's "open" intents go through the same router rather than through URLs: they run inside the app
//  process and set `pendingTab` / `pendingVerse` directly.
//

import Foundation
import Combine

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    struct VerseLink: Equatable {
        let surah: Int
        let verse: Int
        /// True when this is the person's own reading position ("continue reading") rather than a
        /// destination they were sent to. The reader marks the two differently — green for a resume,
        /// gold for a destination (HANDOFF §3) — and a resume at verse 1 opens at the top unmarked.
        var isResume = false
    }
    
    /// Set when a link arrives; the Quran tab consumes it once the surah list is available
    @Published var pendingVerse: VerseLink?
    
    /// Set when something outside the tab bar asks for a tab: a deep link, or one of Siri's "open"
    /// intents. ContentView consumes it. It is @Published rather than a callback so that a request made
    /// BEFORE the window exists — an intent that cold-launches the app — is still there when ContentView
    /// first subscribes.
    @Published var pendingTab: Tab?
    
    private init() {}
    
    /// Opens a tab, optionally with a verse for the reader to land on.
    func open(_ tab: Tab, verse: VerseLink? = nil) {
        if let verse { pendingVerse = verse }
        pendingTab = tab
    }
    
    /// Returns true when the URL was understood
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "iprayer" else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host?.lowercased() {
        case "verse":
            let numbers = parts.compactMap(Int.init)
            guard let surah = numbers.first, (1...114).contains(surah) else { return false }
            open(.quran, verse: VerseLink(surah: surah, verse: numbers.count > 1 ? max(1, numbers[1]) : 1))
            return true
        case "open":
            guard let name = parts.first?.lowercased(), let tab = Self.tabsByName[name] else { return false }
            open(tab)
            return true
        default:
            return false
        }
    }
    
    private static let tabsByName: [String: Tab] = [
        "prayers": .prayers, "quran": .quran, "tasbih": .tasbih, "qibla": .qibla, "settings": .settings
    ]
}
