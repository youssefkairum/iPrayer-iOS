

//
//  QuranView.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import SwiftUI

struct QuranView: View {
    @StateObject private var quranVM = QuranViewModel()
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.lastReadSurahName.rawValue) private var lastReadName: String = ""
    @AppStorage(UDKey.lastReadSurahEnglish.rawValue) private var lastReadEnglish: String = ""
    @AppStorage(UDKey.lastReadSurahNumber.rawValue) private var lastReadNumber: Int = 0
    @State private var searchText = ""
    #if DEBUG
    /// Debug-only: `-debugOpenSurah 18` as a launch argument pushes that surah's reader, for screenshots and UI checks
    @State private var debugSurah: SurahMetadata?
    #endif
    
    var filteredSurahs: [SurahMetadata] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return quranVM.surahs
        } else {
            let search = normalizeArabic(searchText).trimmingCharacters(in: .whitespacesAndNewlines)
            return quranVM.surahs.filter { surah in
                let arabic = normalizeArabic(surah.name)
                let english = normalizeArabic(surah.englishName)
                let trans = normalizeArabic(surah.englishNameTranslation)
                
                return arabic.contains(search) || english.contains(search) || trans.contains(search) || String(surah.number) == search
            }
        }
    }
    
    private func normalizeArabic(_ text: String) -> String {
        let diacritics = CharacterSet(charactersIn: "\u{064B}"..."\u{065F}")
            .union(CharacterSet(charactersIn: "\u{0670}"))
            .union(CharacterSet(charactersIn: "\u{06D6}"..."\u{06ED}")) // Quranic symbols
        
        var str = String(text.unicodeScalars.filter { !diacritics.contains($0) }).lowercased()
        str = str.replacingOccurrences(of: "أ", with: "ا")
        str = str.replacingOccurrences(of: "إ", with: "ا")
        str = str.replacingOccurrences(of: "آ", with: "ا")
        str = str.replacingOccurrences(of: "ٱ", with: "ا") // Alef Wasla
        str = str.replacingOccurrences(of: "ى", with: "ي")
        str = str.replacingOccurrences(of: "ة", with: "ه") // Taa Marbuta to Haa
        return str
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
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            HStack {
                                Text("The Holy Quran")
                                    .font(.custom("AvenirNext-Bold", size: 34))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField(AppTranslations.translate("Search Surah (e.g. Kahf, الكهف)", to: appLanguage), text: $searchText)
                                    .foregroundColor(.white)
                                    .disableAutocorrection(true)
                                
                                if !searchText.isEmpty {
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
                            
                            // Continue Reading Card
                            if lastReadNumber != 0 {
                                if let targetSurah = quranVM.surahs.first(where: { $0.number == lastReadNumber }) {
                                    NavigationLink(destination: SurahDetailView(surah: targetSurah)) {
                                        ContinueReadingCard(
                                            surahName: lastReadName,
                                            surahEnglish: lastReadEnglish,
                                            surahNumber: lastReadNumber
                                        )
                                    }
                                    .padding(.horizontal)
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    // Fallback if surahs array is somehow empty
                                    ContinueReadingCard(
                                        surahName: lastReadName,
                                        surahEnglish: lastReadEnglish,
                                        surahNumber: lastReadNumber
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Surahs Label
                            HStack {
                                Text("Surahs")
                                    .font(.custom("AvenirNext-DemiBold", size: 20))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            // Surah List
                            LazyVStack(spacing: 12) {
                                ForEach(filteredSurahs) { surah in
                                    NavigationLink(destination: SurahDetailView(surah: surah)) {
                                        SurahRow(surah: surah)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100) // Padding for tab bar
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationBarHidden(true)
            #if DEBUG
            .navigationDestination(item: $debugSurah) { surah in
                SurahDetailView(surah: surah)
            }
            .onChange(of: quranVM.surahs.count) { _, _ in
                let number = UserDefaults.standard.integer(forKey: "debugOpenSurah")
                if number > 0, debugSurah == nil {
                    debugSurah = quranVM.surahs.first { $0.number == number }
                }
            }
            #endif
    }
}

// MARK: - Continue Reading Card
struct ContinueReadingCard: View {
    let surahName: String
    let surahEnglish: String
    let surahNumber: Int
    
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
                
                Text(surahName)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.8))
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

// MARK: - List Row Component
struct SurahRow: View {
    let surah: SurahMetadata
    
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
                
                Text("\(surah.englishNameTranslation) • \(surah.numberOfAyahs) Verses")
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Text(surah.name)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(.teal)
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Reading View (Detail)
struct SurahDetailView: View {
    let surah: SurahMetadata
    @StateObject private var detailVM = SurahDetailViewModel()
    @State private var selectedVerse: Int? = nil
    
    private func formatArabicNumber(_ number: Int) -> String {
        let englishNumbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        let arabicNumbers = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        var result = "\(number)"
        for (index, eng) in englishNumbers.enumerated() {
            result = result.replacingOccurrences(of: eng, with: arabicNumbers[index])
        }
        return result
    }
    
    var body: some View {
        ZStack {
            Color(hex: "FAF8F3").edgesIgnoringSafeArea(.all) // Classic Light Paper Background
            
            if detailVM.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .teal))
                    .scaleEffect(1.5)
            } else {
                // Title Header and Basmala are now rendered inside the UITextView for high performance native scrolling
                MushafTextView(
                    verses: detailVM.verses,
                    surahNumber: surah.number,
                    surahName: surah.name,
                    surahEnglishName: surah.englishName,
                    selectedVerse: $selectedVerse
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 15)
                .padding(.bottom, 20)
            }
        }
        // Light paper page inside a dark app: give the navigation bar a light scheme.
        // The status bar follows the WINDOW's scheme, so the app root switches the window to light
        // while this page is on screen (see AppAppearance), keeping the clock readable on paper.
        .toolbarBackground(Color(hex: "FAF8F3"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onDisappear {
            AppAppearance.shared.prefersLightStatusBar = false
        }
        .onAppear {
            AppAppearance.shared.prefersLightStatusBar = true
            detailVM.fetchVerses(for: surah.number)
            UserDefaults.standard.set(surah.name, forKey: UDKey.lastReadSurahName.rawValue)
            UserDefaults.standard.set(surah.englishName, forKey: UDKey.lastReadSurahEnglish.rawValue)
            UserDefaults.standard.set(surah.number, forKey: UDKey.lastReadSurahNumber.rawValue)
            
            CloudSyncManager.shared.sync(key: "lastReadSurahName", value: surah.name)
            CloudSyncManager.shared.sync(key: "lastReadSurahEnglish", value: surah.englishName)
            CloudSyncManager.shared.sync(key: "lastReadSurahNumber", value: surah.number)
            // Schedule reminders
            NotificationManager.shared.scheduleQuranReminders(surahName: surah.englishName)
        }
    }
}

// MARK: - Advanced CoreText Mushaf Engine
struct MushafTextView: UIViewRepresentable {
    let verses: [Ayah]
    let surahNumber: Int
    let surahName: String
    let surahEnglishName: String
    @Binding var selectedVerse: Int?
    
    // Marker images are built on a background queue by loadMore and on the main thread by updateUIView,
    // so access to the cache is serialized with a lock.
    nonisolated(unsafe) private static var markerCache: [Int: UIImage] = [:]
    nonisolated private static let markerCacheLock = NSLock()
    
    nonisolated private static func cachedMarker(_ number: Int) -> UIImage? {
        markerCacheLock.withLock { markerCache[number] }
    }
    nonisolated private static func storeMarker(_ image: UIImage, for number: Int) {
        markerCacheLock.withLock { markerCache[number] = image }
    }
    nonisolated private static func clearMarkers() {
        markerCacheLock.withLock { markerCache.removeAll() }
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [:] // Keep links same color as text
        textView.textContainerInset = UIEdgeInsets(top: 30, left: 0, bottom: 50, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.semanticContentAttribute = .forceRightToLeft
        textView.textAlignment = .right
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Initial load only — never rebuild after first population
        let isTextEmpty = uiView.attributedText?.length ?? 0 < 10
        if isTextEmpty && !verses.isEmpty {
            let initialBatchSize = 20
            let endIndex = min(initialBatchSize, verses.count)
            let batch = Array(verses[0..<endIndex])
            
            context.coordinator.loadedVerseCount = endIndex
            context.coordinator.lastHighlightedVerse = nil
            MushafTextView.clearMarkers()
            uiView.attributedText = buildNSAttributedString(for: batch, includeHeaders: true)
        }
        
        // Only update highlight if the selection actually changed
        if context.coordinator.lastHighlightedVerse != selectedVerse {
            updateHighlight(in: uiView)
            context.coordinator.lastHighlightedVerse = selectedVerse
        }
    }
    
    private func updateHighlight(in textView: UITextView) {
        let textStorage = textView.textStorage
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        textStorage.beginEditing()
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        
        if let selected = selectedVerse {
            let targetLink = "verse://\(selected)"
            let highlightColor = UIColor(red: 209/255.0, green: 226/255.0, blue: 238/255.0, alpha: 1.0)
            
            textStorage.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
                if let linkString = value as? String, linkString == targetLink {
                    textStorage.addAttribute(.backgroundColor, value: highlightColor, range: range)
                } else if let url = value as? URL, url.absoluteString == targetLink {
                    textStorage.addAttribute(.backgroundColor, value: highlightColor, range: range)
                }
            }
        }
        textStorage.endEditing()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MushafTextView
        var loadedVerseCount = 0
        var isLoadingMore = false
        var lastHighlightedVerse: Int? = nil
        
        init(_ parent: MushafTextView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let textView = scrollView as? UITextView else { return }
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let height = scrollView.frame.size.height
            
            guard contentHeight > 0 else { return }
            
            // Load more when within 1500pt of the bottom
            if offsetY > contentHeight - height - 1500 {
                loadMore(into: textView)
            }
        }
        
        func loadMore(into textView: UITextView) {
            guard !isLoadingMore else { return }
            guard loadedVerseCount < parent.verses.count else { return }
            
            isLoadingMore = true
            
            let nextBatchSize = 20
            let startIndex = self.loadedVerseCount
            let endIndex = min(startIndex + nextBatchSize, self.parent.verses.count)
            let batch = Array(self.parent.verses[startIndex..<endIndex])
            
            DispatchQueue.global(qos: .userInitiated).async {
                let newString = self.parent.buildNSAttributedString(for: batch, includeHeaders: false)
                
                DispatchQueue.main.async {
                    // Save scroll position
                    let previousOffset = textView.contentOffset
                    
                    textView.textStorage.beginEditing()
                    textView.textStorage.append(newString)
                    textView.textStorage.endEditing()
                    
                    // Restore scroll position to prevent jump
                    textView.contentOffset = previousOffset
                    
                    self.loadedVerseCount = endIndex
                    self.isLoadingMore = false
                }
            }
        }
        
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            if case .link(let url) = textItem.content {
                if url.scheme == "verse", let host = url.host, let v = Int(host) {
                    return UIAction { _ in
                        DispatchQueue.main.async {
                            if self.parent.selectedVerse == v {
                                self.parent.selectedVerse = nil
                            } else {
                                self.parent.selectedVerse = v
                            }
                        }
                    }
                }
            }
            return defaultAction
        }
        
    }
    
    private func buildNSAttributedString(for batch: [Ayah], includeHeaders: Bool) -> NSAttributedString {
        let fullString = NSMutableAttributedString()
        
        if includeHeaders {
            // --- Add Headers ---
            let headerStyle = NSMutableParagraphStyle()
            headerStyle.alignment = .center
            headerStyle.baseWritingDirection = .rightToLeft
            
            let arabicNameAttr = NSAttributedString(string: "\(surahName)\n", attributes: [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: UIColor(red: 182/255.0, green: 138/255.0, blue: 46/255.0, alpha: 1.0),
                .paragraphStyle: headerStyle
            ])
            fullString.append(arabicNameAttr)
            
            let englishNameStyle = NSMutableParagraphStyle()
            englishNameStyle.alignment = .center
            englishNameStyle.baseWritingDirection = .leftToRight
            
            let englishNameAttr = NSAttributedString(string: "\(surahEnglishName)\n", attributes: [
                .font: UIFont.preferredFont(forTextStyle: .title3),
                .foregroundColor: UIColor.black.withAlphaComponent(0.6),
                .paragraphStyle: englishNameStyle
            ])
            fullString.append(englishNameAttr)
            
            let divider = NSAttributedString(string: "—\n", attributes: [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor(red: 182/255.0, green: 138/255.0, blue: 46/255.0, alpha: 0.3),
                .paragraphStyle: headerStyle
            ])
            fullString.append(divider)
            
            if surahNumber != 9 && surahNumber != 1 {
                let basmalaHeader = NSAttributedString(string: "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ\n\n", attributes: [
                    .font: UIFont(name: "KFGQPCUthmanicScriptHAFS", size: 28) ?? UIFont.systemFont(ofSize: 28),
                    .foregroundColor: UIColor(red: 182/255.0, green: 138/255.0, blue: 46/255.0, alpha: 1.0),
                    .paragraphStyle: headerStyle
                ])
                fullString.append(basmalaHeader)
            } else {
                fullString.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 10)]))
            }
        } else {
            // Break the justification chain for the new batch!
            // This prevents CoreText from recalculating the layout of all previous verses, completely eliminating scroll lag.
            let breakStyle = NSMutableParagraphStyle()
            breakStyle.alignment = .justified
            fullString.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: breakStyle, .font: UIFont.systemFont(ofSize: 10)]))
        }
        
        let basmala = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ "
        
        // --- Add Ayahs ---
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified // True perfect Kashida alignment!
        paragraphStyle.baseWritingDirection = .rightToLeft
        paragraphStyle.lineSpacing = 16
        
        // Use KFGQPC font (must use PostScript name)
        let font = UIFont(name: "KFGQPCUthmanicScriptHAFS", size: 30) ?? UIFont.systemFont(ofSize: 30)
        
        for ayah in batch {
            var text = ayah.text
            // Strip BOM (U+FEFF) and end-of-ayah marks (U+06DD)
            text = text.replacingOccurrences(of: "\u{FEFF}", with: "")
            text = text.replacingOccurrences(of: "\u{06DD}", with: "")
            
            // Strip Tajweed annotation marks that the KFGQPC font cannot render
            // (they show as black dotted circles). These include:
            //  - Waqf/pause marks: U+06D6-U+06DC ( صلى, قلى, لا, جيم, etc.)
            //  - Small letter indicators: U+06E0, U+06E2, U+06E3, U+06E8, U+06EA-U+06ED
            //  - Small rounded zero: U+06DF
            let marks = "\u{06D6}-\u{06DC}\u{06DF}\u{06E0}\u{06E2}\u{06E3}\u{06E8}\u{06EA}-\u{06ED}"
            // First pass: strip marks that sit between spaces (e.g. " ۖ ") and collapse to single space
            text = text.replacingOccurrences(of: " [\(marks)]+ ", with: " ", options: .regularExpression)
            // Second pass: strip any remaining inline marks (e.g. stacked on a letter)
            text = text.replacingOccurrences(of: "[\(marks)]", with: "", options: .regularExpression)
            
            // Strip basmala from first ayah (using NFC normalization to handle
            // diacritics ordering differences between the JSON and this source)
            if surahNumber != 1 && surahNumber != 9 && ayah.numberInSurah == 1 {
                let normalizedText = text.precomposedStringWithCanonicalMapping
                let normalizedBasmala = basmala.precomposedStringWithCanonicalMapping
                if normalizedText.hasPrefix(normalizedBasmala) {
                    text = String(normalizedText.dropFirst(normalizedBasmala.count))
                }
            }
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle,
                .link: "verse://\(ayah.numberInSurah)"
            ]
            
            let mutableAyah = NSMutableAttributedString(string: "\(text) ", attributes: attributes)
            
            // Add custom verse marker image
            if let markerImage = generateVerseMarkerImage(number: ayah.numberInSurah, font: font) {
                let attachment = NSTextAttachment()
                attachment.image = markerImage
                
                let fontDescender = font.descender
                let fontAscender = font.ascender
                let lineHeight = fontAscender - fontDescender
                let imageSide = lineHeight * 0.9 // Scale marker slightly relative to text height
                
                attachment.bounds = CGRect(x: 0, y: fontDescender + (lineHeight - imageSide) / 2.0, width: imageSide, height: imageSide)
                
                let attachmentString = NSAttributedString(attachment: attachment)
                
                // Inherit link attribute so tapping the marker also selects the verse
                let attachmentAttrString = NSMutableAttributedString(attributedString: attachmentString)
                attachmentAttrString.addAttributes([.link: "verse://\(ayah.numberInSurah)"], range: NSRange(location: 0, length: attachmentAttrString.length))
                
                mutableAyah.append(attachmentAttrString)
                mutableAyah.append(NSAttributedString(string: " ", attributes: attributes))
            }
            
            fullString.append(mutableAyah)
        }
        
        return fullString
    }
    
    private func generateVerseMarkerImage(number: Int, font: UIFont) -> UIImage? {
        if let cached = MushafTextView.cachedMarker(number) {
            return cached
        }
        
        let englishNumbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        let arabicNumbers = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        var numStr = "\(number)"
        for (index, eng) in englishNumbers.enumerated() {
            numStr = numStr.replacingOccurrences(of: eng, with: arabicNumbers[index])
        }
        
        let markerSymbol = "\u{06DD}" // ۝
        
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.clear.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        let markerFont = font.withSize(100)
        let markerAttributes: [NSAttributedString.Key: Any] = [
            .font: markerFont,
            .foregroundColor: UIColor(red: 182/255.0, green: 138/255.0, blue: 46/255.0, alpha: 1.0)
        ]
        
        let markerString = NSAttributedString(string: markerSymbol, attributes: markerAttributes)
        let markerSize = markerString.size()
        let markerRect = CGRect(x: (size.width - markerSize.width) / 2, y: (size.height - markerSize.height) / 2, width: markerSize.width, height: markerSize.height)
        markerString.draw(in: markerRect)
        
        var numberFontSize: CGFloat = 50
        if numStr.count >= 3 {
            numberFontSize = 38
        }
        
        let numberFont = font.withSize(numberFontSize)
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: UIColor.black
        ]
        
        let numberString = NSAttributedString(string: numStr, attributes: numberAttributes)
        let numberSize = numberString.size()
        
        let numberRect = CGRect(
            x: (size.width - numberSize.width) / 2,
            y: (size.height - numberSize.height) / 2 + 5,
            width: numberSize.width,
            height: numberSize.height
        )
        
        numberString.draw(in: numberRect)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        if let img = image {
            MushafTextView.storeMarker(img, for: number)
        }
        return image
    }
}
