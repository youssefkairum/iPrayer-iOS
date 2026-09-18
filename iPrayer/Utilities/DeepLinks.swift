//
//  DeepLinks.swift
//  iPrayer
//
//  `iprayer://verse/<surah>/<ayah>` opens the reader at a verse. The Verse of the Day widget uses it.
//

import Foundation
import Combine

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    struct VerseLink: Equatable {
        let surah: Int
        let verse: Int
    }
    
    /// Set when a link arrives; the Quran tab consumes it once the surah list is available
    @Published var pendingVerse: VerseLink?
    
    private init() {}
    
    /// Returns true when the URL was understood
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "iprayer", url.host?.lowercased() == "verse" else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }.compactMap(Int.init)
        guard let surah = parts.first, (1...114).contains(surah) else { return false }
        pendingVerse = VerseLink(surah: surah, verse: parts.count > 1 ? max(1, parts[1]) : 1)
        return true
    }
}
