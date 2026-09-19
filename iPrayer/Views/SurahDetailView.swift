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
    private let focusStyle: VerseMark
    
    @StateObject private var detailVM = SurahDetailViewModel()
    @ObservedObject private var bookmarks = QuranBookmarks.shared
    @ObservedObject private var audio = QuranAudioPlayer.shared
    @ObservedObject private var downloads = QuranAudioDownloads.shared
    
    /// The reader moves to the next surah in place, so the back button always returns to the list
    @State private var currentSurah: SurahMetadata
    @State private var openAtVerse: Int?
    /// The verse marked as "you are here" when arriving from a bookmark or a search result
    @State private var focusVerse: Int?
    @State private var selectedVerse: Int?
    @State private var showCopied = false
    /// The verse at the top of the screen; the toolbar play button starts from here
    @State private var visibleVerse: Int
    
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.quranFontSize.rawValue) private var fontSize: Double = ReaderStyle.defaultFontSize
    @AppStorage(UDKey.quranReaderTheme.rawValue) private var themeRaw: String = ReaderTheme.paper.rawValue
    @AppStorage(UDKey.quranReciter.rawValue) private var reciterID: String = QuranReciter.default.id
    
    /// - Parameter mark: how to highlight `initialVerse` on arrival: `.destination` (gold) for a bookmark, search
    ///   result or link the person picked, `.resume` (green) for Continue Reading, nil for no mark.
    init(surah: SurahMetadata, initialVerse: Int? = nil, mark: VerseMark? = nil) {
        self.initialVerse = initialVerse
        self.focusStyle = mark ?? .destination
        _currentSurah = State(initialValue: surah)
        _openAtVerse = State(initialValue: initialVerse)
        _focusVerse = State(initialValue: mark != nil ? initialVerse : nil)
        _visibleVerse = State(initialValue: initialVerse ?? 1)
    }
    
    private var reciter: QuranReciter { QuranReciter.with(id: reciterID) }
    
    /// Audio belongs to the reader only while it is reciting the surah on screen
    private var isAudioForThisSurah: Bool { audio.surah?.number == currentSurah.number }
    private var playingVerse: Int? { isAudioForThisSurah ? audio.verse : nil }
    private var downloadState: QuranAudioDownloads.State { downloads.state(for: currentSurah.number, reciter: reciter) }
    
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
                    focusVerse: focusVerse,
                    focusStyle: focusStyle,
                    playingVerse: playingVerse,
                    selectedVerse: $selectedVerse,
                    onVisibleVerseChange: { verse in
                        visibleVerse = verse
                        recordLastRead(verse: verse)
                    },
                    onOpenNextSurah: {
                        guard let next = detailVM.surah(after: currentSurah.number) else { return }
                        audio.stop()
                        selectedVerse = nil
                        openAtVerse = nil
                        focusVerse = nil
                        visibleVerse = 1
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
            VStack(spacing: 8) {
                if let ayah = selectedAyah {
                    verseActionBar(for: ayah)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if case .downloading(let fraction) = downloadState {
                    downloadBar(fraction: fraction)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let error = downloads.lastError {
                    messageBar(AppTranslations.translate(error, to: appLanguage)) { downloads.lastError = nil }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if isAudioForThisSurah {
                    playbackBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedVerse)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isAudioForThisSurah)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: downloadState == .none)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Recite from the verse at the top of the screen
                Button {
                    if isAudioForThisSurah {
                        audio.togglePlayPause()
                    } else {
                        audio.play(surah: currentSurah, from: visibleVerse, reciter: reciter)
                    }
                } label: {
                    Image(systemName: isAudioForThisSurah && audio.isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityLabel(AppTranslations.translate(isAudioForThisSurah && audio.isPlaying ? "Pause" : "Play", to: appLanguage))
            }
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
            // Session and first verses ready before play is tapped
            audio.prepare(surah: currentSurah, around: openAtVerse ?? 1, reciter: reciter)
        }
        .onAppear {
            // The status bar follows the window's scheme; the app root flips it while a paper page is showing
            AppAppearance.shared.prefersLightStatusBar = theme == .paper
            // Reading is mostly hands-off: don't let the screen dim and lock mid-page
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Recitation is tied to the page on screen; there are no controls for it elsewhere in the app
            audio.stop()
            AppAppearance.shared.prefersLightStatusBar = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: selectedVerse) { _, newValue in
            // The mark has done its job once the user starts interacting with verses
            if let newValue {
                focusVerse = nil
                // A selected verse is a likely "play from here"
                audio.prefetch(surah: currentSurah, from: newValue, reciter: reciter)
            }
        }
        .onChange(of: reciterID) { _, _ in
            audio.change(reciter: reciter)
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
            
            // Menu rows have a fixed maximum width, so the labels here are kept short enough not to wrap
            // at large text sizes; the section header supplies the context.
            Section(AppTranslations.translate("Quran Audio", to: appLanguage)) {
                Picker(AppTranslations.translate("Reciter", to: appLanguage), selection: $reciterID) {
                    ForEach(QuranReciter.all) { reciter in
                        Text(reciter.name(for: appLanguage)).tag(reciter.id)
                    }
                }
                .pickerStyle(.menu)
                
                // Offline audio for this surah, with the chosen reciter
                switch downloadState {
                case .none:
                    Button {
                        downloads.download(surah: currentSurah, reciter: reciter)
                    } label: {
                        Label(AppTranslations.translate("Download", to: appLanguage), systemImage: "arrow.down.circle")
                    }
                case .downloading(let fraction):
                    Button {
                        downloads.cancel(surah: currentSurah.number, reciter: reciter)
                    } label: {
                        Label("\(AppTranslations.translate("Cancel", to: appLanguage)) \(Int(fraction * 100))%", systemImage: "xmark.circle")
                    }
                case .downloaded:
                    Button(role: .destructive) {
                        downloads.remove(surah: currentSurah.number, reciter: reciter)
                    } label: {
                        Label(AppTranslations.translate("Delete", to: appLanguage), systemImage: "trash")
                    }
                }
            }
        } label: {
            Image(systemName: "textformat.size")
        }
        // Keep the menu open while stepping the size
        .menuActionDismissBehavior(.disabled)
    }
    
    // MARK: - Verse actions
    
    private func reference(for ayah: Ayah) -> String {
        reference(verse: ayah.numberInSurah)
    }
    
    /// "Ar-Room 30:4", or the Arabic name with Arabic-Indic digits when the app is in Arabic
    private func reference(verse: Int) -> String {
        if appLanguage == "ar" {
            return "\(currentSurah.name) \(QuranTextEncoder.arabicDigits(currentSurah.number)):\(QuranTextEncoder.arabicDigits(verse))"
        }
        let name = appLanguage == "ur" ? currentSurah.name : currentSurah.englishName
        return "\(name) \(currentSurah.number):\(verse)"
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
            
            actionButton("play.fill", label: AppTranslations.translate("Play", to: appLanguage)) {
                audio.play(surah: currentSurah, from: ayah.numberInSurah, reciter: reciter)
                selectedVerse = nil
            }
            
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
        // Liquid Glass with a dark tint, so the white label and teal icons stay readable over the
        // paper theme as well as the dark one
        .glassEffect(.regular.tint(Color(red: 20/255, green: 36/255, blue: 44/255).opacity(0.75)).interactive(), in: .capsule)
    }
    
    // MARK: - Download bars
    
    private func downloadBar(fraction: Double) -> some View {
        HStack(spacing: 10) {
            ProgressView(value: fraction)
                .progressViewStyle(.circular)
                .tint(.teal)
            Text("\(AppTranslations.translate("Downloading audio", to: appLanguage)) \(Int(fraction * 100))%")
                .font(.custom("AvenirNext-DemiBold", size: 14))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            actionButton("xmark", label: AppTranslations.translate("Cancel Download", to: appLanguage)) {
                downloads.cancel(surah: currentSurah.number, reciter: reciter)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(Color(red: 20/255, green: 36/255, blue: 44/255).opacity(0.75)), in: .capsule)
    }
    
    private func messageBar(_ message: String, onClose: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.custom("AvenirNext-DemiBold", size: 14))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            actionButton("xmark", label: "Close", action: onClose)
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(Color(red: 20/255, green: 36/255, blue: 44/255).opacity(0.75)), in: .capsule)
    }
    
    // MARK: - Playback bar
    
    private var playbackStatusText: String {
        if let error = audio.errorMessage {
            return AppTranslations.translate(error, to: appLanguage)
        }
        guard let verse = audio.verse else { return reciter.name(for: appLanguage) }
        return reference(verse: verse)
    }
    
    private var playbackBar: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(playbackStatusText)
                    .font(.custom("AvenirNext-DemiBold", size: audio.errorMessage == nil ? 14 : 13))
                    .foregroundColor(audio.errorMessage == nil ? .white : .orange)
                    .lineLimit(audio.errorMessage == nil ? 1 : 2)
                    .minimumScaleFactor(0.7)
                if audio.errorMessage == nil, audio.verse != nil {
                    Text(reciter.name(for: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(.leading, 8)
            
            Spacer(minLength: 8)
            
            // Playback order follows the text, so these never mirror in right-to-left layouts
            HStack(spacing: 4) {
                actionButton("backward.end.fill", label: "Previous") { audio.previous() }
                
                if audio.isBuffering && audio.errorMessage == nil {
                    ProgressView().tint(.teal).frame(width: 42, height: 38)
                } else {
                    actionButton(audio.isPlaying ? "pause.fill" : "play.fill",
                                 label: AppTranslations.translate(audio.isPlaying ? "Pause" : "Play", to: appLanguage)) {
                        if audio.errorMessage != nil {
                            // Try again from where it stopped
                            audio.play(surah: currentSurah, from: audio.verse ?? visibleVerse, reciter: reciter)
                        } else {
                            audio.togglePlayPause()
                        }
                    }
                }
                
                actionButton("forward.end.fill", label: "Next") { audio.next() }
            }
            .environment(\.layoutDirection, .leftToRight)
            
            actionButton("xmark", label: "Close") { audio.stop() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(Color(red: 20/255, green: 36/255, blue: 44/255).opacity(0.75)).interactive(), in: .capsule)
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
