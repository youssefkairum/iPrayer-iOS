//
//  QuranDataCache.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation

/// A thread-safe global cache for the offline Quran.
actor QuranDataCache {
    static let shared = QuranDataCache()
    
    // Internal models matching the bundled JSON
    private struct FullQuranResponse: Decodable { let data: FullQuranData }
    private struct FullQuranData: Decodable { let surahs: [FullSurah] }
    private struct FullSurah: Decodable { let number: Int; let ayahs: [RawAyah] }
    private struct RawAyah: Decodable {
        let number: Int
        let text: String
        let numberInSurah: Int
        let page: Int
        let juz: Int
    }
    private struct CacheSurahListResponse: Decodable { let data: [SurahMetadata] }
    
    /// One verse prepared for search. Every word is folded both ways (see QuranTextEncoder.searchKey):
    /// with the superscript alef dropped, and with it written as a full alef. A phrase can need both at
    /// once: in "ذلك الكتاب" the first word drops it and the second writes it, so matching is per word.
    private struct SearchEntry {
        let surahNumber: Int
        let ayah: Ayah
        let words: [(plain: String, modern: String)]
        
        func matches(_ query: [String]) -> Bool {
            guard let first = query.first, let last = query.last, query.count <= words.count else { return false }
            
            if query.count == 1 {
                return words.contains { $0.plain.contains(first) || $0.modern.contains(first) }
            }
            
            // A phrase matches consecutive words: the first may start mid-word, the last may end mid-word,
            // the ones between must match whole words.
            for start in 0...(words.count - query.count) {
                let head = words[start]
                guard head.plain.hasSuffix(first) || head.modern.hasSuffix(first) else { continue }
                let tail = words[start + query.count - 1]
                guard tail.plain.hasPrefix(last) || tail.modern.hasPrefix(last) else { continue }
                
                var middleMatches = true
                for offset in 1..<(query.count - 1) where query.count > 2 {
                    let word = words[start + offset]
                    if word.plain != query[offset] && word.modern != query[offset] { middleMatches = false; break }
                }
                if middleMatches { return true }
            }
            return false
        }
    }
    
    private var cachedSurahs: [SurahMetadata]?
    private var cachedFullQuran: [Int: [Ayah]]? // keyed by surah number
    private var searchIndex: [SearchEntry]?
    
    private init() {}
    
    /// Surah metadata, cached in memory.
    func getSurahs() async throws -> [SurahMetadata] {
        if let cached = cachedSurahs {
            return cached
        }
        
        guard let url = Bundle.main.url(forResource: "surah-metadata", withExtension: "json") else {
            throw NSError(domain: "QuranDataCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "Offline Quran metadata not found in bundle."])
        }
        
        let data = try Data(contentsOf: url)
        let surahs = try JSONDecoder().decode(CacheSurahListResponse.self, from: data).data
        self.cachedSurahs = surahs
        return surahs
    }
    
    /// Decodes the whole Quran once. All text preparation happens here, a single time,
    /// instead of running regex passes every time a surah is opened.
    private func loadQuran() throws -> [Int: [Ayah]] {
        if let cached = cachedFullQuran { return cached }
        
        guard let url = Bundle.main.url(forResource: "quran-uthmani", withExtension: "json") else {
            throw NSError(domain: "QuranDataCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "Offline Quran text not found in bundle."])
        }
        
        let data = try Data(contentsOf: url)
        let fullQuran = try JSONDecoder().decode(FullQuranResponse.self, from: data)
        
        var dictionary = [Int: [Ayah]]()
        dictionary.reserveCapacity(114)
        for surah in fullQuran.data.surahs {
            dictionary[surah.number] = surah.ayahs.map { raw in
                let text = QuranTextEncoder.removingBasmala(
                    from: raw.text.replacingOccurrences(of: "\u{FEFF}", with: ""),
                    surah: surah.number,
                    numberInSurah: raw.numberInSurah
                )
                return Ayah(
                    number: raw.number,
                    numberInSurah: raw.numberInSurah,
                    page: raw.page,
                    juz: raw.juz,
                    text: text,
                    displayText: QuranTextEncoder.displayText(from: text)
                )
            }
        }
        
        self.cachedFullQuran = dictionary
        return dictionary
    }
    
    /// Verses of one surah.
    func getVerses(for surahNumber: Int) async throws -> [Ayah] {
        guard let verses = try loadQuran()[surahNumber] else {
            throw NSError(domain: "QuranDataCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "Surah \(surahNumber) not found."])
        }
        return verses
    }
    
    /// Full-text search across all verses. Matching ignores vowel marks and letter variants,
    /// and accepts both Uthmani and modern spellings.
    func searchVerses(matching query: String, limit: Int = 60) async throws -> [VerseSearchResult] {
        let needle = QuranTextEncoder.searchKey(query)
        guard needle.count >= 2 else { return [] }
        let queryWords = needle.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        
        if searchIndex == nil {
            let quran = try loadQuran()
            var index: [SearchEntry] = []
            index.reserveCapacity(6236)
            for surahNumber in quran.keys.sorted() {
                for ayah in quran[surahNumber] ?? [] {
                    let words = ayah.text.split(separator: " ", omittingEmptySubsequences: true).compactMap { word -> (plain: String, modern: String)? in
                        let plain = QuranTextEncoder.searchKey(String(word))
                        // Stand-alone pause marks fold to nothing
                        guard !plain.isEmpty else { return nil }
                        return (plain, QuranTextEncoder.searchKey(String(word), daggerAlefAsAlef: true))
                    }
                    index.append(SearchEntry(surahNumber: surahNumber, ayah: ayah, words: words))
                }
            }
            searchIndex = index
        }
        
        var results: [VerseSearchResult] = []
        for entry in searchIndex ?? [] where entry.matches(queryWords) {
            results.append(VerseSearchResult(surahNumber: entry.surahNumber, ayah: entry.ayah))
            if results.count >= limit { break }
        }
        return results
    }
}
