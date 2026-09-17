//
//  QuranBookmarks.swift
//  iPrayer
//

import Foundation
import Combine

/// Verses the user bookmarked from the reader. Stored as a JSON string so it can ride
/// on the same iCloud key-value sync as the other settings.
final class QuranBookmarks: ObservableObject {
    static let shared = QuranBookmarks()
    
    @Published private(set) var items: [QuranBookmark] = []
    
    private init() {
        reload()
    }
    
    /// Re-reads UserDefaults. Also called by CloudSyncManager when bookmarks arrive from iCloud.
    func reload() {
        guard let json = UserDefaults.standard.string(forKey: UDKey.quranBookmarks.rawValue),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([QuranBookmark].self, from: data) else {
            items = []
            return
        }
        if decoded != items { items = decoded }
    }
    
    func contains(surah: Int, verse: Int) -> Bool {
        items.contains { $0.surah == surah && $0.verse == verse }
    }
    
    func toggle(_ bookmark: QuranBookmark) {
        if let index = items.firstIndex(where: { $0.id == bookmark.id }) {
            items.remove(at: index)
        } else {
            items.insert(bookmark, at: 0)
        }
        persist()
    }
    
    func remove(_ bookmark: QuranBookmark) {
        items.removeAll { $0.id == bookmark.id }
        persist()
    }
    
    private func persist() {
        guard let data = try? JSONEncoder().encode(items), let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: UDKey.quranBookmarks.rawValue)
        CloudSyncManager.shared.sync(key: UDKey.quranBookmarks.rawValue, value: json)
    }
}
