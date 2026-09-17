//
//  QuranViewModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation
import Combine

class QuranViewModel: ObservableObject {
    @Published var surahs: [SurahMetadata] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    init() {
        fetchSurahList()
    }
    
    func fetchSurahList() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let cachedSurahs = try await QuranDataCache.shared.getSurahs()
                await MainActor.run {
                    self.surahs = cachedSurahs
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to read offline Quran data."
                    self.isLoading = false
                    print("Offline decoding error: \(error)")
                }
            }
        }
    }
}
