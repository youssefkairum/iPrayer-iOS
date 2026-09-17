//
//  SurahDetailViewModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation
import Combine

@MainActor
class SurahDetailViewModel: ObservableObject {
    @Published var verses: [Ayah] = []
    @Published var surahs: [SurahMetadata] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    
    /// The surah `verses` belongs to. The view checks it so it never shows one surah's text under another's title.
    @Published private(set) var loadedSurahNumber: Int?
    
    /// Loads a surah. Safe to call repeatedly: re-appearing with the same surah does nothing,
    /// so the reader keeps its text and scroll position.
    func load(surahNumber: Int) async {
        guard loadedSurahNumber != surahNumber else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedVerses = try await QuranDataCache.shared.getVerses(for: surahNumber)
            surahs = (try? await QuranDataCache.shared.getSurahs()) ?? []
            verses = loadedVerses
            loadedSurahNumber = surahNumber
        } catch {
            errorMessage = "Failed to load Quran text: \(error.localizedDescription)"
            print("Offline detail decoding error: \(error)")
        }
        isLoading = false
    }
    
    func surah(after number: Int) -> SurahMetadata? {
        surahs.first { $0.number == number + 1 }
    }
}
