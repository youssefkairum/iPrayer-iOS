//
//  QuranViewModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation
import Combine

@MainActor
class QuranViewModel: ObservableObject {
    @Published var surahs: [SurahMetadata] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    /// Results of the current search. Empty query means "show everything".
    @Published private(set) var matchingSurahs: [SurahMetadata] = []
    @Published private(set) var matchingVerses: [VerseSearchResult] = []
    @Published private(set) var isSearching = false
    
    /// Folded surah names, built once instead of on every keystroke.
    private var surahSearchKeys: [Int: String] = [:]
    private var searchTask: Task<Void, Never>?
    
    init() {
        fetchSurahList()
    }
    
    func fetchSurahList() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loaded = try await QuranDataCache.shared.getSurahs()
                surahs = loaded
                matchingSurahs = loaded
                surahSearchKeys = Dictionary(uniqueKeysWithValues: loaded.map { surah in
                    (surah.number, [surah.name, surah.englishName, surah.englishNameTranslation]
                        .map { QuranTextEncoder.searchKey($0) }
                        .joined(separator: "\n"))
                })
                isLoading = false
            } catch {
                errorMessage = "Failed to read offline Quran data."
                isLoading = false
                print("Offline decoding error: \(error)")
            }
        }
    }
    
    func surah(number: Int) -> SurahMetadata? {
        surahs.first { $0.number == number }
    }
    
    /// Surah names filter instantly; the verse search is debounced and runs off the main thread.
    func updateSearch(_ text: String) {
        searchTask?.cancel()
        let query = QuranTextEncoder.searchKey(text)
        
        guard !query.isEmpty else {
            matchingSurahs = surahs
            matchingVerses = []
            isSearching = false
            return
        }
        
        matchingSurahs = surahs.filter { surah in
            String(surah.number) == query || (surahSearchKeys[surah.number]?.contains(query) ?? false)
        }
        
        guard query.count >= 2 else {
            matchingVerses = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let verses = (try? await QuranDataCache.shared.searchVerses(matching: text)) ?? []
            guard !Task.isCancelled else { return }
            matchingVerses = verses
            isSearching = false
        }
    }
}
