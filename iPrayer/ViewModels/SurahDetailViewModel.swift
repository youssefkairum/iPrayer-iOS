//
//  SurahDetailViewModel.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import Foundation
import Combine

class SurahDetailViewModel: ObservableObject {
    @Published var verses: [Ayah] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    
    func fetchVerses(for surahNumber: Int) {
        isLoading = true
        verses = []
        errorMessage = nil
        
        Task {
            do {
                let cachedVerses = try await QuranDataCache.shared.getVerses(for: surahNumber)
                await MainActor.run {
                    self.verses = cachedVerses
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load Quran text: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Offline detail decoding error: \(error)")
                }
            }
        }
    }
}
