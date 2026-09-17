//
//  QuranModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation

// MARK: - Surah Metadata
struct SurahMetadata: Codable, Identifiable, Sendable {
    let number: Int
    let name: String                    // Arabic Name (e.g. سورة الفاتحة)
    let englishName: String             // Phonetic (e.g. Al-Fatiha)
    let englishNameTranslation: String  // Meaning (e.g. The Opening)
    let numberOfAyahs: Int
    let revelationType: String          // Meccan or Medinan
    
    var id: Int { number }
}

// MARK: - Verse
struct Ayah: Codable, Identifiable, Sendable {
    let number: Int
    let text: String
    let numberInSurah: Int
    
    var id: Int { number }
}
