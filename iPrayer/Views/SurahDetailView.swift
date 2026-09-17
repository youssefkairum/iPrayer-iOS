//
//  SurahDetailView.swift
//  iPrayer
//
//  The Quran reader screen: text, appearance controls, and actions for a selected verse.
//

import SwiftUI

struct SurahDetailView: View {
    /// Verse to open at: the resume position, a bookmark, or a search result
    private let initialVerse: Int?
    
    @StateObject private var detailVM = SurahDetailViewModel()
    @ObservedObject private var bookmarks = QuranBookmarks.shared
    
    /// The reader moves to the next surah in place, so the back button always returns to the list
    @State private var currentSurah: SurahMetadata
    @State private var openAtVerse: Int?
    @State private var selectedVerse: Int?
    @State private var showCopied = false
    
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.quranFontSize.rawValue) private var fontSize: Double = ReaderStyle.defaultFontSize
    @AppStorage(UDKey.quranReaderTheme.rawValue) private var themeRaw: String = ReaderTheme.paper.rawValue
    
    init(surah: SurahMetadata, initialVerse: Int? = nil) {
        self.initialVerse = initialVerse
        _currentSurah = State(initialValue: surah)
        _openAtVerse = State(initialValue: initialVerse)
    }
    
    private var theme: ReaderTheme { ReaderTheme(rawValue: themeRaw) ?? .paper }
    private var style: ReaderStyle { ReaderStyle(fontSize: CGFloat(fontSize), theme: theme) }
    
    private var selectedAyah: Ayah? {
        guard let selectedVerse else { return nil }
        return detailVM.verses.first { $0.numberInSurah == selectedVerse }
    }
    
    var body: some View {
        ZStack {
            Color(theme.background).ignoresSafeArea()
            
            if let error = detailVM.errorMessage {
                Text(error)
                    .foregroundColor(Color(theme.text))
                    .multilineTextAlignment(.center)
                    .padding()
            } else if detailVM.isLoading || detailVM.loadedSurahNumber != currentSurah.number {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .teal))
                    .scaleEffect(1.5)
            } else {
                MushafTextView(
                    verses: detailVM.verses,
                    surah: currentSurah,
                    nextSurah: detailVM.surah(after: currentSurah.number),
                    style: style,
                    initialVerse: openAtVerse,
                    selectedVerse: $selectedVerse,
                    onVisibleVerseChange: { verse in
                        recordLastRead(verse: verse)
                    },
                    onOpenNextSurah: {
                        guard let next = detailVM.surah(after: currentSurah.number) else { return }
                        selectedVerse = nil
                        openAtVerse = nil
                        currentSurah = next
                    }
                )
                // A new surah gets a fresh text view rather than reusing the old one's text and scroll state
                .id(currentSurah.number)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 15)
            }
        }
        .overlay(alignment: .bottom) {
            if let ayah = selectedAyah {
                verseActionBar(for: ayah)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedVerse)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                appearanceMenu
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(theme == .paper ? .light : .dark, for: .navigationBar)
        // `.task(id:)` runs once per surah. Unlike onAppear it does not reload, and lose the reader's
        // place, when the view merely re-appears.
        .task(id: currentSurah.number) {
            await detailVM.load(surahNumber: currentSurah.number)
            recordLastRead(verse: openAtVerse ?? 1)
        }
        .onAppear {
            // The status bar follows the window's scheme; the app root flips it while a paper page is showing
            AppAppearance.shared.prefersLightStatusBar = theme == .paper
            // Reading is mostly hands-off: don't let the screen dim and lock mid-page
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            AppAppearance.shared.prefersLightStatusBar = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: themeRaw) { _, _ in
            AppAppearance.shared.prefersLightStatusBar = theme == .paper
        }
    }
    
    // MARK: - Appearance menu
    
    private var appearanceMenu: some View {
        Menu {
            Section(AppTranslations.translate("Text Size", to: appLanguage)) {
                Button {
                    fontSize = min(ReaderStyle.fontSizeRange.upperBound, fontSize + 2)
                } label: {
                    Label("A+", systemImage: "textformat.size.larger")
                }
                .disabled(fontSize >= ReaderStyle.fontSizeRange.upperBound)
                
                Button {
                    fontSize = max(ReaderStyle.fontSizeRange.lowerBound, fontSize - 2)
                } label: {
                    Label("A−", systemImage: "textformat.size.smaller")
                }
                .disabled(fontSize <= ReaderStyle.fontSizeRange.lowerBound)
            }
            
            Picker("", selection: $themeRaw) {
                Label(AppTranslations.translate("Paper", to: appLanguage), systemImage: "sun.max").tag(ReaderTheme.paper.rawValue)
                Label(AppTranslations.translate("Dark", to: appLanguage), systemImage: "moon").tag(ReaderTheme.dark.rawValue)
            }
        } label: {
            Image(systemName: "textformat.size")
        }
        // Keep the menu open while stepping the size
        .menuActionDismissBehavior(.disabled)
    }
    
    // MARK: - Verse actions
    
    private func reference(for ayah: Ayah) -> String {
        "\(currentSurah.englishName) \(currentSurah.number):\(ayah.numberInSurah)"
    }
    
    private func shareText(for ayah: Ayah) -> String {
        // The standard text, not the font-specific display encoding, so it reads correctly anywhere
        "\(ayah.text)\n[\(reference(for: ayah))]"
    }
    
    private func bookmark(for ayah: Ayah) -> QuranBookmark {
        QuranBookmark(
            surah: currentSurah.number,
            verse: ayah.numberInSurah,
            surahEnglishName: currentSurah.englishName,
            surahArabicName: currentSurah.name,
            snippet: String(ayah.text.prefix(140))
        )
    }
    
    private func verseActionBar(for ayah: Ayah) -> some View {
        let isBookmarked = bookmarks.contains(surah: currentSurah.number, verse: ayah.numberInSurah)
        
        return HStack(spacing: 4) {
            Text(showCopied ? AppTranslations.translate("Copied", to: appLanguage) : reference(for: ayah))
                .font(.custom("AvenirNext-DemiBold", size: 14))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.leading, 8)
            
            Spacer(minLength: 8)
            
            actionButton("doc.on.doc", label: AppTranslations.translate("Copy", to: appLanguage)) {
                UIPasteboard.general.string = shareText(for: ayah)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
            }
            
            ShareLink(item: shareText(for: ayah)) {
                actionIcon("square.and.arrow.up")
            }
            .accessibilityLabel(AppTranslations.translate("Share", to: appLanguage))
            
            actionButton(isBookmarked ? "bookmark.fill" : "bookmark", label: AppTranslations.translate("Bookmark", to: appLanguage)) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                bookmarks.toggle(bookmark(for: ayah))
            }
            
            actionButton("xmark", label: "Close") {
                selectedVerse = nil
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 20/255, green: 36/255, blue: 44/255).opacity(0.96))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
    }
    
    private func actionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.teal)
            .frame(width: 42, height: 38)
            .contentShape(Rectangle())
    }
    
    private func actionButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionIcon(systemName)
        }
        .accessibilityLabel(label)
    }
    
    // MARK: - Reading position
    
    private func recordLastRead(verse: Int) {
        let defaults = UserDefaults.standard
        let previousSurah = defaults.integer(forKey: UDKey.lastReadSurahNumber.rawValue)
        
        defaults.set(currentSurah.name, forKey: UDKey.lastReadSurahName.rawValue)
        defaults.set(currentSurah.englishName, forKey: UDKey.lastReadSurahEnglish.rawValue)
        defaults.set(currentSurah.number, forKey: UDKey.lastReadSurahNumber.rawValue)
        defaults.set(verse, forKey: UDKey.lastReadVerse.rawValue)
        
        // sync() skips values that haven't changed
        let cloud = CloudSyncManager.shared
        cloud.sync(key: UDKey.lastReadSurahName.rawValue, value: currentSurah.name)
        cloud.sync(key: UDKey.lastReadSurahEnglish.rawValue, value: currentSurah.englishName)
        cloud.sync(key: UDKey.lastReadSurahNumber.rawValue, value: currentSurah.number)
        cloud.sync(key: UDKey.lastReadVerse.rawValue, value: verse)
        
        // The reminders mention the surah by name, so they only need rebuilding when it changes,
        // not every time a surah is opened or scrolled
        if previousSurah != currentSurah.number {
            NotificationManager.shared.scheduleQuranReminders(surahName: currentSurah.englishName)
        }
    }
}
