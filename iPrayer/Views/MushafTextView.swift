//
//  MushafTextView.swift
//  iPrayer
//
//  The Quran reading surface: a UITextView fed page by page.
//

import SwiftUI
import UIKit

// MARK: - Appearance

nonisolated enum ReaderTheme: String, CaseIterable {
    case paper
    case dark
    
    var background: UIColor {
        switch self {
        case .paper: return UIColor(red: 250/255, green: 248/255, blue: 243/255, alpha: 1)
        case .dark: return UIColor(red: 14/255, green: 22/255, blue: 27/255, alpha: 1)
        }
    }
    var text: UIColor {
        switch self {
        case .paper: return .black
        case .dark: return UIColor(red: 236/255, green: 230/255, blue: 216/255, alpha: 1)
        }
    }
    var accent: UIColor {
        switch self {
        case .paper: return UIColor(red: 166/255, green: 124/255, blue: 36/255, alpha: 1)
        case .dark: return UIColor(red: 214/255, green: 176/255, blue: 92/255, alpha: 1)
        }
    }
    var secondary: UIColor { text.withAlphaComponent(0.55) }
    var highlight: UIColor {
        switch self {
        case .paper: return UIColor(red: 209/255, green: 226/255, blue: 238/255, alpha: 1)
        case .dark: return UIColor(red: 38/255, green: 66/255, blue: 78/255, alpha: 1)
        }
    }
}

nonisolated struct ReaderStyle: Equatable {
    var fontSize: CGFloat
    var theme: ReaderTheme
    
    static let fontSizeRange: ClosedRange<Double> = 22...46
    static let defaultFontSize: Double = 30
}

// MARK: - Attributed text builder

/// Builds the attributed text. It has no UI state, so later pages can be built off the main thread.
nonisolated struct MushafTextBuilder {
    let surah: SurahMetadata
    let nextSurah: SurahMetadata?
    let style: ReaderStyle
    
    static let nextSurahLink = "surah://next"
    static func verseLink(_ verse: Int) -> String { "verse://\(verse)" }
    
    private var quranFont: UIFont {
        // Must be the PostScript name
        UIFont(name: "KFGQPCUthmanicScriptHAFS", size: style.fontSize) ?? UIFont.systemFont(ofSize: style.fontSize)
    }
    
    private func centered(rtl: Bool, spacingBefore: CGFloat = 0, spacingAfter: CGFloat = 0) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        paragraph.paragraphSpacingBefore = spacingBefore
        paragraph.paragraphSpacing = spacingAfter
        return paragraph
    }
    
    func header() -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        result.append(NSAttributedString(string: "\(surah.name)\n", attributes: [
            .font: UIFont.systemFont(ofSize: style.fontSize * 1.33, weight: .bold),
            .foregroundColor: style.theme.accent,
            .paragraphStyle: centered(rtl: true)
        ]))
        result.append(NSAttributedString(string: "\(surah.englishName)\n", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .title3),
            .foregroundColor: style.theme.secondary,
            .paragraphStyle: centered(rtl: false)
        ]))
        result.append(NSAttributedString(string: "—\n", attributes: [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: style.theme.accent.withAlphaComponent(0.35),
            .paragraphStyle: centered(rtl: true)
        ]))
        
        // Al-Fatiha's basmala is its first verse; At-Tawba has none
        if surah.number != 1 && surah.number != 9 {
            let basmala = QuranTextEncoder.displayText(from: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
            result.append(NSAttributedString(string: "\(basmala)\n", attributes: [
                .font: quranFont.withSize(style.fontSize * 0.93),
                .foregroundColor: style.theme.accent,
                .paragraphStyle: centered(rtl: true, spacingAfter: style.fontSize * 0.8)
            ]))
        } else {
            result.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 10)]))
        }
        return result
    }
    
    /// One mushaf page: a single justified paragraph followed by the page number, as in print.
    /// Keeping each page its own paragraph also means appending a page never re-lays-out earlier text.
    func page(_ verses: [Ayah]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        guard let first = verses.first else { return result }
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineSpacing = style.fontSize * 0.5
        
        let font = quranFont
        for ayah in verses {
            let link = Self.verseLink(ayah.numberInSurah)
            let base: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: style.theme.text,
                .paragraphStyle: paragraph,
                .link: link
            ]
            // The no-break space keeps the marker on the same line as the end of its verse
            result.append(NSAttributedString(string: ayah.displayText + "\u{00A0}", attributes: base))
            
            // The KFGQPC font draws Arabic-Indic digits as complete verse-number ornaments,
            // so no image needs to be generated, cached or kept in memory.
            var marker = base
            marker[.foregroundColor] = style.theme.accent
            result.append(NSAttributedString(string: QuranTextEncoder.arabicDigits(ayah.numberInSurah), attributes: marker))
            result.append(NSAttributedString(string: " ", attributes: base))
        }
        result.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: paragraph]))
        
        let footer = "صفحة \(QuranTextEncoder.arabicDigits(first.page))  ·  الجزء \(QuranTextEncoder.arabicDigits(first.juz))\n"
        result.append(NSAttributedString(string: footer, attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: style.theme.secondary,
            .paragraphStyle: centered(rtl: true, spacingBefore: 6, spacingAfter: style.fontSize * 0.9)
        ]))
        return result
    }
    
    /// Shown after the last page: a link to the next surah, so reading can simply continue.
    func ending() -> NSAttributedString {
        let result = NSMutableAttributedString()
        guard let next = nextSurah else {
            result.append(NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: 30)]))
            return result
        }
        result.append(NSAttributedString(string: "السورة التالية\n", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: style.theme.secondary,
            .paragraphStyle: centered(rtl: true, spacingBefore: 10)
        ]))
        result.append(NSAttributedString(string: "\(next.name)  ‹\n", attributes: [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: style.theme.accent,
            .paragraphStyle: centered(rtl: true, spacingAfter: 40),
            .link: Self.nextSurahLink
        ]))
        return result
    }
    
    /// Consecutive verses that share a mushaf page.
    static func groupByPage(_ verses: [Ayah]) -> [[Ayah]] {
        var pages: [[Ayah]] = []
        for ayah in verses {
            if let last = pages.last?.last, last.page == ayah.page {
                pages[pages.count - 1].append(ayah)
            } else {
                pages.append([ayah])
            }
        }
        return pages
    }
}

// MARK: - Text view

struct MushafTextView: UIViewRepresentable {
    let verses: [Ayah]
    let surah: SurahMetadata
    let nextSurah: SurahMetadata?
    let style: ReaderStyle
    /// Verse to open at (resume reading, a bookmark, or a search result)
    let initialVerse: Int?
    @Binding var selectedVerse: Int?
    var onVisibleVerseChange: (Int) -> Void
    var onOpenNextSurah: () -> Void
    
    /// Pages rendered up front, and how many are added each time the reader nears the end
    private static let pageBatch = 2
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [:] // Keep links the same color as the text
        textView.dataDetectorTypes = []
        textView.textDragInteraction?.isEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 30, left: 0, bottom: 50, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.semanticContentAttribute = .forceRightToLeft
        textView.textAlignment = .right
        return textView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        
        // Rebuild only when the content or its appearance changed, never on unrelated SwiftUI updates
        let key = "\(surah.number)|\(verses.count)|\(style.fontSize)|\(style.theme.rawValue)"
        if coordinator.renderedKey != key, !verses.isEmpty {
            let isFirstRender = coordinator.renderedKey == nil
            // Keep the reader's place across a text size or theme change
            let anchor = isFirstRender ? initialVerse : coordinator.topVisibleVerse
            
            coordinator.renderedKey = key
            coordinator.generation += 1
            coordinator.isLoadingMore = false
            coordinator.pages = MushafTextBuilder.groupByPage(verses)
            
            let anchorPage = anchor.flatMap { verse in
                coordinator.pages.firstIndex { page in page.contains { $0.numberInSurah == verse } }
            } ?? 0
            let pageCount = min(coordinator.pages.count, max(Self.pageBatch, anchorPage + Self.pageBatch))
            
            let builder = coordinator.builder
            let text = NSMutableAttributedString(attributedString: builder.header())
            for index in 0..<pageCount {
                text.append(builder.page(coordinator.pages[index]))
            }
            if pageCount == coordinator.pages.count {
                text.append(builder.ending())
            }
            
            coordinator.loadedPageCount = pageCount
            coordinator.lastHighlightedVerse = nil
            uiView.attributedText = text
            
            if let anchor, anchor > 1 {
                coordinator.scroll(uiView, toVerse: anchor)
            } else if isFirstRender {
                uiView.setContentOffset(.zero, animated: false)
            }
        }
        
        // Only touch the highlight when the selection actually changed
        if coordinator.lastHighlightedVerse != selectedVerse {
            coordinator.updateHighlight(in: uiView, selected: selectedVerse)
            coordinator.lastHighlightedVerse = selectedVerse
        }
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MushafTextView
        var pages: [[Ayah]] = []
        var loadedPageCount = 0
        var renderedKey: String?
        /// Bumped on every rebuild so a background page build for the old appearance is discarded
        var generation = 0
        var isLoadingMore = false
        var lastHighlightedVerse: Int?
        var topVisibleVerse: Int?
        
        init(_ parent: MushafTextView) {
            self.parent = parent
        }
        
        var builder: MushafTextBuilder {
            MushafTextBuilder(surah: parent.surah, nextSurah: parent.nextSurah, style: parent.style)
        }
        
        // MARK: Loading more pages
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let textView = scrollView as? UITextView, scrollView.contentSize.height > 0 else { return }
            // Load more when within 1500pt of the bottom
            if scrollView.contentOffset.y > scrollView.contentSize.height - scrollView.frame.height - 1500 {
                loadMore(into: textView)
            }
        }
        
        func loadMore(into textView: UITextView) {
            guard !isLoadingMore, loadedPageCount < pages.count else { return }
            isLoadingMore = true
            
            let startIndex = loadedPageCount
            let endIndex = min(startIndex + MushafTextView.pageBatch, pages.count)
            let batch = Array(pages[startIndex..<endIndex])
            let reachesEnd = endIndex == pages.count
            let builder = self.builder
            let expectedGeneration = generation
            
            DispatchQueue.global(qos: .userInitiated).async {
                let addition = NSMutableAttributedString()
                for page in batch { addition.append(builder.page(page)) }
                if reachesEnd { addition.append(builder.ending()) }
                
                DispatchQueue.main.async {
                    // The text was rebuilt (size or theme changed) while this was being prepared
                    guard expectedGeneration == self.generation else { return }
                    
                    textView.textStorage.beginEditing()
                    textView.textStorage.append(addition)
                    textView.textStorage.endEditing()
                    
                    self.loadedPageCount = endIndex
                    self.isLoadingMore = false
                    
                    // The new pages arrive without a highlight; nothing to restore unless one is active
                    if let selected = self.parent.selectedVerse {
                        self.updateHighlight(in: textView, selected: selected)
                    }
                }
            }
        }
        
        // MARK: Reading position
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            reportVisibleVerse(scrollView)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { reportVisibleVerse(scrollView) }
        }
        
        private func reportVisibleVerse(_ scrollView: UIScrollView) {
            guard let textView = scrollView as? UITextView, let verse = verseAtTop(of: textView) else { return }
            if verse != topVisibleVerse {
                topVisibleVerse = verse
                parent.onVisibleVerseChange(verse)
            }
        }
        
        /// The verse whose text sits at the top of the visible area.
        private func verseAtTop(of textView: UITextView) -> Int? {
            // closestPosition works in the text view's own coordinates, which include the scroll offset
            let probe = CGPoint(x: textView.bounds.midX, y: textView.contentOffset.y + 28)
            guard let position = textView.closestPosition(to: probe) else { return nil }
            
            let storage = textView.textStorage
            var index = textView.offset(from: textView.beginningOfDocument, to: position)
            // The probe may land on a header or page number; walk forward to the next verse
            let limit = min(storage.length, index + 600)
            while index < limit {
                if let verse = Self.verseNumber(from: storage.attribute(.link, at: index, effectiveRange: nil)) {
                    return verse
                }
                index += 1
            }
            return nil
        }
        
        private static func verseNumber(from link: Any?) -> Int? {
            let string = (link as? String) ?? (link as? URL)?.absoluteString
            guard let string, string.hasPrefix("verse://") else { return nil }
            return Int(string.dropFirst("verse://".count))
        }
        
        private func range(ofVerse verse: Int, in storage: NSTextStorage) -> NSRange? {
            let target = MushafTextBuilder.verseLink(verse)
            var found: NSRange?
            storage.enumerateAttribute(.link, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
                let string = (value as? String) ?? (value as? URL)?.absoluteString
                if string == target { found = range; stop.pointee = true }
            }
            return found
        }
        
        /// Scrolls so the verse sits near the top. Text layout is lazy, so the position is
        /// re-applied a couple of times as the estimated heights above it settle.
        func scroll(_ textView: UITextView, toVerse verse: Int, attempt: Int = 0) {
            DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0 : 0.15)) { [weak self, weak textView] in
                guard let self, let textView, let range = self.range(ofVerse: verse, in: textView.textStorage) else { return }
                textView.layoutIfNeeded()
                
                guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                      let end = textView.position(from: start, offset: min(2, range.length)),
                      let textRange = textView.textRange(from: start, to: end) else { return }
                
                let rect = textView.firstRect(for: textRange)
                guard !rect.isNull, !rect.isInfinite, rect.minY.isFinite else { return }
                
                let maxOffset = max(0, textView.contentSize.height - textView.bounds.height)
                let offset = min(max(0, rect.minY - 24), maxOffset)
                textView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                self.topVisibleVerse = verse
                
                if attempt < 2 {
                    self.scroll(textView, toVerse: verse, attempt: attempt + 1)
                }
            }
        }
        
        // MARK: Selection
        
        func updateHighlight(in textView: UITextView, selected: Int?) {
            let storage = textView.textStorage
            let fullRange = NSRange(location: 0, length: storage.length)
            
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)
            if let selected {
                let target = MushafTextBuilder.verseLink(selected)
                let color = parent.style.theme.highlight
                storage.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
                    let string = (value as? String) ?? (value as? URL)?.absoluteString
                    if string == target {
                        storage.addAttribute(.backgroundColor, value: color, range: range)
                    }
                }
            }
            storage.endEditing()
        }
        
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case .link(let url) = textItem.content else { return defaultAction }
            
            if url.scheme == "verse", let host = url.host, let verse = Int(host) {
                return UIAction { [weak self] _ in
                    guard let self else { return }
                    self.parent.selectedVerse = self.parent.selectedVerse == verse ? nil : verse
                }
            }
            if url.absoluteString == MushafTextBuilder.nextSurahLink {
                return UIAction { [weak self] _ in
                    self?.parent.onOpenNextSurah()
                }
            }
            return defaultAction
        }
        
        /// Verses are links only to make them tappable; a long press must not offer "Open Link".
        func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
            nil
        }
    }
}
