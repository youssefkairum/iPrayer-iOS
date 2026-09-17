//
//  QuranModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation

// MARK: - Surah Metadata
struct SurahMetadata: Codable, Identifiable, Hashable, Sendable {
    let number: Int
    let name: String                    // Arabic Name (e.g. سورة الفاتحة)
    let englishName: String             // Phonetic (e.g. Al-Fatiha)
    let englishNameTranslation: String  // Meaning (e.g. The Opening)
    let numberOfAyahs: Int
    let revelationType: String          // Meccan or Medinan
    
    var id: Int { number }
    
    /// The Arabic name without the leading word "سورة", which every name repeats.
    /// List rows use it so long names fit on one line.
    var shortArabicName: String {
        let parts = name.split(separator: " ", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : name
    }
}

// MARK: - Verse
struct Ayah: Identifiable, Hashable, Sendable {
    let number: Int            // 1...6236 across the whole Quran
    let numberInSurah: Int
    let page: Int              // Madani mushaf page, 1...604
    let juz: Int
    /// Standard Unicode text (basmala removed from verse 1). Used for copy, share and search.
    let text: String
    /// The same verse re-encoded for the KFGQPC font. Only ever used for drawing.
    let displayText: String
    
    var id: Int { number }
}

// MARK: - Bookmarks & Search
struct QuranBookmark: Codable, Identifiable, Hashable, Sendable {
    let surah: Int
    let verse: Int
    let surahEnglishName: String
    let surahArabicName: String
    let snippet: String
    
    var id: String { "\(surah):\(verse)" }
}

struct VerseSearchResult: Identifiable, Hashable, Sendable {
    let surahNumber: Int
    let ayah: Ayah
    
    var id: Int { ayah.number }
}
