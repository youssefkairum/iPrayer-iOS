//
//  QuranModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation

// MARK: - List Response (Metadata for all Surahs)
struct SurahListResponse: Codable, Sendable {
    let code: Int
    let status: String
    let data: [SurahMetadata]
}

struct SurahMetadata: Codable, Identifiable, Sendable {
    let number: Int
    let name: String                    // Arabic Name (e.g. سورة الفاتحة)
    let englishName: String             // Phonetic (e.g. Al-Fatiha)
    let englishNameTranslation: String  // Meaning (e.g. The Opening)
    let numberOfAyahs: Int
    let revelationType: String          // Meccan or Medinan
    
    var id: Int { number }
}

// MARK: - Detail Response (Verses for a specific Surah)
struct SurahDetailResponse: Codable, Sendable {
    let code: Int
    let status: String
    let data: [SurahEdition]
}

struct SurahEdition: Codable, Sendable {
    let number: Int
    let name: String
    let englishName: String
    let ayahs: [Ayah]
}

struct Ayah: Codable, Identifiable, Sendable {
    let number: Int
    let text: String
    let numberInSurah: Int
    
    var id: Int { number }
}
