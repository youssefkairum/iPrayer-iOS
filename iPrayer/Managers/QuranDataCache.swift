//
//  QuranDataCache.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation

/// A thread-safe global cache for massive Quran JSON decoding.
actor QuranDataCache {
    static let shared = QuranDataCache()
    
    // Internal Models for decoding the massive structure
    private struct FullQuranResponse: Codable, Sendable {
        let data: FullQuranData
    }
    
    private struct FullQuranData: Codable, Sendable {
        let surahs: [FullSurah]
    }
    
    private struct FullSurah: Codable, Sendable {
        let number: Int
        let ayahs: [Ayah]
    }
    
    private var cachedSurahs: [SurahMetadata]?
    private var cachedFullQuran: [Int: [Ayah]]? // Dictionary mapped by Surah Number for instant O(1) lookup
    
    private init() {}
    
    private struct CacheSurahListResponse: Codable, Sendable {
        let data: [CacheSurahMetadata]
    }
    
    private struct CacheSurahMetadata: Codable, Sendable {
        let number: Int
        let name: String
        let englishName: String
        let englishNameTranslation: String
        let numberOfAyahs: Int
        let revelationType: String
        
        func toDomain() -> SurahMetadata {
            return SurahMetadata(number: number, name: name, englishName: englishName, englishNameTranslation: englishNameTranslation, numberOfAyahs: numberOfAyahs, revelationType: revelationType)
        }
    }

    /// Asynchronously fetches Surah Metadata, caching it in memory.
    func getSurahs() async throws -> [SurahMetadata] {
        if let cached = cachedSurahs {
            return cached
        }
        
        guard let url = Bundle.main.url(forResource: "surah-metadata", withExtension: "json") else {
            throw NSError(domain: "QuranDataCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "Offline Quran metadata not found in bundle."])
        }
        
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(CacheSurahListResponse.self, from: data)
        let domainModels = response.data.map { $0.toDomain() }
        self.cachedSurahs = domainModels
        return domainModels
    }
    
    /// Asynchronously fetches Ayahs for a given Surah, caching the entire 2.5MB JSON in memory once.
    func getVerses(for surahNumber: Int) async throws -> [Ayah] {
        if let cached = cachedFullQuran {
            guard let verses = cached[surahNumber] else {
                throw NSError(domain: "QuranDataCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "Surah \(surahNumber) not found in cache."])
            }
            return verses
        }
        
        // Background parsing of the massive file
        guard let url = Bundle.main.url(forResource: "quran-uthmani", withExtension: "json") else {
            throw NSError(domain: "QuranDataCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "Offline Quran text not found in bundle."])
        }
        
        let data = try Data(contentsOf: url)
        let fullQuran = try JSONDecoder().decode(FullQuranResponse.self, from: data)
        
        // Build the fast O(1) lookup dictionary
        var dictionary = [Int: [Ayah]]()
        dictionary.reserveCapacity(114)
        for surah in fullQuran.data.surahs {
            dictionary[surah.number] = surah.ayahs
        }
        
        self.cachedFullQuran = dictionary
        
        guard let verses = dictionary[surahNumber] else {
            throw NSError(domain: "QuranDataCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "Surah \(surahNumber) not found in decoded payload."])
        }
        
        return verses
    }
}
