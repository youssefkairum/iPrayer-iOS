//
//  QuranView.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import SwiftUI

struct QuranView: View {
    @StateObject private var quranVM = QuranViewModel()
    @ObservedObject private var bookmarks = QuranBookmarks.shared
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.lastReadSurahName.rawValue) private var lastReadName: String = ""
    @AppStorage(UDKey.lastReadSurahEnglish.rawValue) private var lastReadEnglish: String = ""
    @AppStorage(UDKey.lastReadSurahNumber.rawValue) private var lastReadNumber: Int = 0
    @AppStorage(UDKey.lastReadVerse.rawValue) private var lastReadVerse: Int = 0
    @State private var searchText = ""
    #if DEBUG
    /// Debug-only: `-debugOpenSurah 18 -debugOpenVerse 40` as launch arguments pushes that surah's reader
    /// at that verse, for screenshots and UI checks
    @State private var debugSurah: SurahMetadata?
    #endif
    
    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        // No inner NavigationView: pushes go through the NavigationStack in ContentView.
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            if quranVM.isLoading {
                ProgressView("Loading Quran...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .teal))
                    .foregroundColor(.white)
            } else if let error = quranVM.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error).foregroundColor(.white)
                    Button("Retry") { quranVM.fetchSurahList() }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
            } else {
                VStack(spacing: 14) {
                    // The title and search field stay put; only the results scroll
                    header
                    searchBar
                    
                    ScrollView {
                        if isSearchActive {
                            searchResults
                        } else {
                            browseContent
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: searchText) { _, newValue in
            quranVM.updateSearch(newValue)
        }
        #if DEBUG
        .navigationDestination(item: $debugSurah) { surah in
            let verse = UserDefaults.standard.integer(forKey: "debugOpenVerse")
            SurahDetailView(surah: surah, initialVerse: verse > 0 ? verse : nil)
        }
        .onChange(of: quranVM.surahs.count) { _, _ in
            let number = UserDefaults.standard.integer(forKey: "debugOpenSurah")
            if number > 0, debugSurah == nil {
                debugSurah = quranVM.surah(number: number)
            }
        }
        #endif
    }
    
    // MARK: - Pinned header
    
    private var header: some View {
        HStack {
            Text("The Holy Quran")
                .font(.custom("AvenirNext-Bold", size: 34))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField(AppTranslations.translate("Search Surah (e.g. Kahf, الكهف)", to: appLanguage), text: $searchText)
                .foregroundColor(.white)
                .disableAutocorrection(true)
            
            if quranVM.isSearching {
                ProgressView().tint(.gray)
            } else if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    // MARK: - Browsing
    
    private var browseContent: some View {
        VStack(spacing: 20) {
            // Continue Reading Card
            if lastReadNumber != 0, let target = quranVM.surah(number: lastReadNumber) {
                NavigationLink(destination: SurahDetailView(surah: target, initialVerse: lastReadVerse > 1 ? lastReadVerse : nil)) {
                    ContinueReadingCard(
                        surahName: lastReadName,
                        surahEnglish: lastReadEnglish,
                        verse: lastReadVerse,
                        appLanguage: appLanguage
                    )
                }
                .padding(.horizontal)
                .buttonStyle(PlainButtonStyle())
            }
            
            // Bookmarks
            if !bookmarks.items.isEmpty {
                sectionTitle(AppTranslations.translate("Bookmarks", to: appLanguage))
                LazyVStack(spacing: 10) {
                    ForEach(bookmarks.items) { bookmark in
                        if let surah = quranVM.surah(number: bookmark.surah) {
                            NavigationLink(destination: SurahDetailView(surah: surah, initialVerse: bookmark.verse)) {
                                VerseRow(
                                    arabicText: bookmark.snippet,
                                    reference: "\(bookmark.surahEnglishName) \(bookmark.surah):\(bookmark.verse)",
                                    icon: "bookmark.fill"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    bookmarks.remove(bookmark)
                                } label: {
                                    Label(AppTranslations.translate("Remove", to: appLanguage), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            sectionTitle(Text("Surahs"))
            surahList(quranVM.surahs)
                .padding(.bottom, 100) // Padding for tab bar
        }
        .padding(.top, 6)
    }
    
    // MARK: - Search results
    
    private var searchResults: some View {
        VStack(spacing: 20) {
            if quranVM.matchingSurahs.isEmpty && quranVM.matchingVerses.isEmpty && !quranVM.isSearching {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundColor(.gray)
                    Text(AppTranslations.translate("No results found", to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 16))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
            
            if !quranVM.matchingSurahs.isEmpty {
                sectionTitle(Text("Surahs"))
                surahList(quranVM.matchingSurahs)
            }
            
            if !quranVM.matchingVerses.isEmpty {
                sectionTitle(AppTranslations.catalogString("Verses", language: appLanguage))
                LazyVStack(spacing: 10) {
                    ForEach(quranVM.matchingVerses) { result in
                        if let surah = quranVM.surah(number: result.surahNumber) {
                            NavigationLink(destination: SurahDetailView(surah: surah, initialVerse: result.ayah.numberInSurah)) {
                                VerseRow(
                                    arabicText: result.ayah.text,
                                    reference: "\(surah.englishName) \(surah.number):\(result.ayah.numberInSurah)",
                                    icon: "text.quote"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Color.clear.frame(height: 100) // Padding for tab bar
        }
        .padding(.top, 6)
    }
    
    // MARK: - Building blocks
    
    private func sectionTitle(_ title: String) -> some View {
        sectionTitle(Text(verbatim: title))
    }
    
    private func sectionTitle(_ title: Text) -> some View {
        HStack {
            title
                .font(.custom("AvenirNext-DemiBold", size: 20))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func surahList(_ surahs: [SurahMetadata]) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(surahs) { surah in
                NavigationLink(destination: SurahDetailView(surah: surah)) {
                    SurahRow(surah: surah, appLanguage: appLanguage)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Continue Reading Card
struct ContinueReadingCard: View {
    let surahName: String
    let surahEnglish: String
    let verse: Int
    let appLanguage: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "book.fill")
                        .foregroundColor(.teal)
                        .font(.caption)
                    Text("CONTINUE READING")
                        .font(.custom("AvenirNext-Bold", size: 12))
                        .foregroundColor(.teal)
                }
                
                Text(surahEnglish)
                    .font(.custom("AvenirNext-Bold", size: 24))
                    .foregroundColor(.white)
                
                HStack(spacing: 10) {
                    Text(surahName)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if verse > 1 {
                        Text("\(AppTranslations.translate("Verse", to: appLanguage)) \(verse)")
                            .font(.custom("AvenirNext-DemiBold", size: 13))
                            .foregroundColor(.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.teal.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            
            Image(systemName: "chevron.forward.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(
            ZStack {
                Color.teal.opacity(0.2)
                LinearGradient(
                    gradient: Gradient(colors: [Color.teal.opacity(0.3), Color.blue.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(25)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.teal.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - List Rows

/// A flat translucent fill. The rows used a blur material, which makes every visible row composite
/// its own backdrop blur while the list scrolls; on a plain gradient the two look almost identical.
private let rowFill = Color.white.opacity(0.07)

struct SurahRow: View {
    let surah: SurahMetadata
    let appLanguage: String
    
    var body: some View {
        HStack(spacing: 15) {
            // Number Box
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 45, height: 45)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.teal.opacity(0.3), lineWidth: 1))
                
                Text("\(surah.number)")
                    .font(.custom("AvenirNext-Bold", size: 16))
                    .foregroundColor(.teal)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(surah.englishName)
                    .font(.custom("AvenirNext-DemiBold", size: 18))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // The inner Text keeps using the translated "%@ • %lld Verses" catalog entry
                Text("\(Text("\(surah.englishNameTranslation) • \(surah.numberOfAyahs) Verses")) • \(AppTranslations.translate(surah.revelationType, to: appLanguage))")
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Without the repeated word "سورة" every name fits on one line, keeping row heights even
            Text(surah.shortArabicName)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(.teal)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding()
        .background(rowFill)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

/// A verse shown in search results and bookmarks.
struct VerseRow: View {
    /// Standard text; re-encoded here for the Quran font
    let arabicText: String
    let reference: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(QuranTextEncoder.displayText(from: arabicText))
                .font(.custom("KFGQPC Uthmanic Script HAFS", size: 22))
                .foregroundColor(.white)
                .lineLimit(2)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Arabic reads right to left whatever the app's layout direction is
                .environment(\.layoutDirection, .rightToLeft)
            
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(reference)
                    .font(.custom("AvenirNext-DemiBold", size: 13))
                Spacer()
            }
            .foregroundColor(.teal)
        }
        .padding(14)
        .background(rowFill)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
