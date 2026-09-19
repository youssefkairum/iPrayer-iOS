//
//  QuranAudioPlayer.swift
//  iPrayer
//
//  Streams recitation one verse at a time, so the reader can follow along verse by verse.
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine
import Network

/// A reciter available from the audio source. `id` is the source's folder name.
nonisolated struct QuranReciter: Identifiable, Hashable, Sendable {
    let id: String
    let englishName: String
    let arabicName: String
    
    func name(for language: String) -> String {
        ["ar", "ur"].contains(language) ? arabicName : englishName
    }
    
    /// Each of these was checked to exist at the source.
    static let all: [QuranReciter] = [
        QuranReciter(id: "Alafasy_128kbps", englishName: "Mishary Alafasy", arabicName: "مشاري العفاسي"),
        QuranReciter(id: "Abdul_Basit_Murattal_192kbps", englishName: "Abdul Basit", arabicName: "عبد الباسط عبد الصمد"),
        QuranReciter(id: "Husary_128kbps", englishName: "Mahmoud Al-Husary", arabicName: "محمود خليل الحصري"),
        QuranReciter(id: "Minshawy_Murattal_128kbps", englishName: "Al-Minshawi", arabicName: "محمد صديق المنشاوي"),
        QuranReciter(id: "Abdurrahmaan_As-Sudais_192kbps", englishName: "Abdurrahman As-Sudais", arabicName: "عبد الرحمن السديس"),
        QuranReciter(id: "MaherAlMuaiqly128kbps", englishName: "Maher Al-Muaiqly", arabicName: "ماهر المعيقلي")
    ]
    static let `default` = all[0]
    
    static func with(id: String) -> QuranReciter {
        all.first { $0.id == id } ?? .default
    }
}

/// Where the audio comes from. One MP3 per verse, named SSSAAA.mp3 (surah and verse, zero padded).
/// Everything about the source lives here, so it can be swapped for another host or a bundled set.
nonisolated enum QuranAudioSource {
    static var baseURL: String {
        #if DEBUG
        // Debug-only: `-debugAudioBaseURL https://unreachable.invalid` as a launch argument makes every
        // verse fail to load, to test the offline handling without cutting the network
        if let override = UserDefaults.standard.string(forKey: "debugAudioBaseURL"), !override.isEmpty {
            return override
        }
        #endif
        return "https://everyayah.com/data"
    }
    
    static func remoteURL(reciter: QuranReciter, surah: Int, verse: Int) -> URL? {
        URL(string: String(format: "%@/%@/%03d%03d.mp3", baseURL, reciter.id, surah, verse))
    }
    
    /// One archive per surah with every verse file, plus SSS000.mp3, the basmala. Stored, not compressed.
    static func surahArchiveURL(reciter: QuranReciter, surah: Int) -> URL? {
        URL(string: String(format: "%@/%@/zips/%03d.zip", baseURL, reciter.id, surah))
    }
    
    /// The verse files for verse 1 do not include the basmala, so it is played first. It is Al-Fatiha 1:1.
    static func remoteBasmalaURL(reciter: QuranReciter) -> URL? {
        remoteURL(reciter: reciter, surah: 1, verse: 1)
    }
    
    // What the player uses: the downloaded file when there is one, otherwise the stream.
    
    static func url(reciter: QuranReciter, surah: Int, verse: Int) -> URL? {
        QuranAudioDownloads.existingFile(reciter: reciter, surah: surah, verse: verse)
            ?? remoteURL(reciter: reciter, surah: surah, verse: verse)
    }
    
    static func basmalaURL(reciter: QuranReciter) -> URL? {
        QuranAudioDownloads.existingBasmala(reciter: reciter) ?? remoteBasmalaURL(reciter: reciter)
    }
}

@MainActor
final class QuranAudioPlayer: ObservableObject {
    static let shared = QuranAudioPlayer()
    
    /// The surah being recited, or nil when nothing is loaded
    @Published private(set) var surah: SurahMetadata?
    /// The verse being recited right now. nil while the opening basmala plays.
    @Published private(set) var verse: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    /// AppTranslations key describing a playback problem
    @Published private(set) var errorMessage: String?
    
    var isActive: Bool { surah != nil }
    
    private let player = AVQueuePlayer()
    private var reciter = QuranReciter.default
    /// Which verse each queued item is. 0 marks the opening basmala.
    private var verseForItem: [ObjectIdentifier: Int] = [:]
    private var nextVerseToQueue = 1
    private var cancellables: Set<AnyCancellable> = []
    /// One status watcher per queued item, so a verse that fails to load is caught whether or not it is
    /// the one playing. Watching only the current item missed failures: offline, the queue player drops a
    /// failed verse and moves on before the watcher is even attached, which sent the reader racing
    /// through the surah.
    private var itemObservers: [ObjectIdentifier: AnyCancellable] = [:]
    /// Set once a queued verse failed; no more verses are added after it
    private var loadingFailed = false
    
    private let pathMonitor = NWPathMonitor()
    private var isOnline = true
    private var didConfigureRemoteCommands = false
    /// Bumped by every play(); a start that was still activating the session for an older request is dropped
    private var playRequest = 0
    /// Assets whose headers were loaded ahead of time, so the first verse starts without a round trip
    private var prefetchedAssets: [URL: AVURLAsset] = [:]
    private var isSessionActive = false
    
    private static let basmalaMarker = 0
    /// Verses kept queued ahead of the one playing, so the next starts without a gap. One is enough, and it
    /// keeps streaming within the two connections at a time that the audio source asks for.
    private static let lookahead = 1
    
    private init() {
        player.actionAtItemEnd = .advance
        
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            guard let self else { return }
            Task { @MainActor in self.isOnline = online }
        }
        pathMonitor.start(queue: DispatchQueue(label: "iPrayer.audio.path"))
        
        player.publisher(for: \.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] item in
                MainActor.assumeIsolated { self?.currentItemChanged(to: item) }
            }
            .store(in: &cancellables)
        
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                MainActor.assumeIsolated {
                    guard let self, self.isActive else { return }
                    self.isPlaying = status == .playing
                    self.isBuffering = status == .waitingToPlayAtSpecifiedRate
                    self.updateNowPlaying()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Getting ready before play is tapped
    
    /// Called when the reader opens: activates the audio session in the background now, so the tap on
    /// play doesn't have to wait for it, and warms up the verses the user is likely to start from.
    func prepare(surah: SurahMetadata, around verse: Int, reciter: QuranReciter) {
        if !isSessionActive {
            isSessionActive = true
            Task { await Self.activateSession() }
        }
        prefetch(surah: surah, from: verse, reciter: reciter)
    }
    
    /// Loads the headers of `verse` and the one after it. Playing later reuses the same asset objects,
    /// so what was fetched is not fetched again.
    func prefetch(surah: SurahMetadata, from verse: Int, reciter: QuranReciter) {
        let first = min(max(1, verse), surah.numberOfAyahs)
        var urls: [URL] = []
        if first == 1, surah.number != 1, surah.number != 9, let basmala = QuranAudioSource.basmalaURL(reciter: reciter) {
            urls.append(basmala)
        }
        for number in first...min(first + 1, surah.numberOfAyahs) {
            if let url = QuranAudioSource.url(reciter: reciter, surah: surah.number, verse: number) { urls.append(url) }
        }
        
        // Keep the cache small; it only needs to cover what plays next
        if prefetchedAssets.count > 8 { prefetchedAssets.removeAll() }
        for url in urls where prefetchedAssets[url] == nil {
            let asset = AVURLAsset(url: url)
            prefetchedAssets[url] = asset
            Task.detached(priority: .utility) {
                _ = try? await asset.load(.isPlayable)
            }
        }
    }
    
    // MARK: - Controls
    
    /// Starts reciting `surah` from `startVerse`.
    func play(surah: SurahMetadata, from startVerse: Int, reciter: QuranReciter) {
        resetQueue()
        configureRemoteCommandsIfNeeded()
        
        self.surah = surah
        self.reciter = reciter
        self.errorMessage = nil
        
        // Offline and the starting verse isn't downloaded: say so now instead of queuing verses that
        // will all fail one after another
        let first = min(max(1, startVerse), surah.numberOfAyahs)
        if !isOnline, QuranAudioDownloads.existingFile(reciter: reciter, surah: surah.number, verse: first) == nil {
            errorMessage = "Audio needs an internet connection."
            isPlaying = false
            isBuffering = false
            return
        }
        self.verse = nil
        self.isBuffering = true
        nextVerseToQueue = first
        
        playRequest += 1
        let request = playRequest
        
        Task {
            // Activating the session can block for a while, so it runs off the main thread.
            // If the reader already activated it, this returns immediately.
            if !isSessionActive {
                await Self.activateSession()
                isSessionActive = true
            }
            // A newer play() or stop() happened while the session was activating
            guard request == playRequest, self.surah?.number == surah.number else { return }
            
            if first == 1, surah.number != 1, surah.number != 9, let url = QuranAudioSource.basmalaURL(reciter: reciter) {
                enqueue(url, as: Self.basmalaMarker)
            }
            topUpQueue()
            player.play()
        }
    }
    
    /// `.playback` keeps reciting with the ringer switch off, in the background and on the Lock Screen.
    /// AVAudioSession activation is synchronous and can stall, which Xcode flags as a hang risk on the
    /// main thread, so it runs on a background task.
    private static func activateSession() async {
        await Task.detached(priority: .userInitiated) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session error: \(error)")
            }
        }.value
    }
    
    private static func deactivateSession() {
        Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    func togglePlayPause() {
        guard isActive else { return }
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }
    
    func next() {
        guard let surah, let verse, verse < surah.numberOfAyahs else { return }
        topUpQueue()
        player.advanceToNextItem()
    }
    
    func previous() {
        guard let surah else { return }
        play(surah: surah, from: max(1, (verse ?? 1) - 1), reciter: reciter)
    }
    
    /// Restarts the current verse with another reciter.
    func change(reciter newReciter: QuranReciter) {
        guard let surah, newReciter != reciter else { return }
        play(surah: surah, from: verse ?? 1, reciter: newReciter)
    }
    
    func stop() {
        playRequest += 1   // cancels a start that is still waiting for the session
        resetQueue()
        surah = nil
        verse = nil
        isPlaying = false
        isBuffering = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        isSessionActive = false
        Self.deactivateSession()
    }
    
    // MARK: - Queue
    
    private func resetQueue() {
        player.pause()
        player.removeAllItems()
        verseForItem.removeAll()
        itemObservers.removeAll()
        loadingFailed = false
    }
    
    private func enqueue(_ url: URL, as verseNumber: Int) {
        let item = AVPlayerItem(asset: prefetchedAssets[url] ?? AVURLAsset(url: url))
        // Start as soon as a couple of seconds are buffered instead of waiting for a large safety margin
        item.preferredForwardBufferDuration = 2
        let id = ObjectIdentifier(item)
        verseForItem[id] = verseNumber
        
        itemObservers[id] = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] status in
                MainActor.assumeIsolated {
                    guard let self, let item, status == .failed else { return }
                    self.itemFailedToLoad(item)
                }
            }
        
        player.insert(item, after: nil)
    }
    
    /// A verse could not be loaded, which in practice means no connection. Nothing further is queued.
    /// If it is the verse that should be playing now, playback stops here with a message; if it is a
    /// verse queued ahead, the current one is allowed to finish first.
    private func itemFailedToLoad(_ item: AVPlayerItem) {
        loadingFailed = true
        itemObservers[ObjectIdentifier(item)] = nil
        
        if item === player.currentItem {
            errorMessage = "Audio needs an internet connection."
            resetQueue()
            isPlaying = false
            isBuffering = false
        } else {
            player.remove(item)
            verseForItem[ObjectIdentifier(item)] = nil
        }
    }
    
    private func topUpQueue() {
        guard let surah, !loadingFailed else { return }
        while player.items().count <= Self.lookahead, nextVerseToQueue <= surah.numberOfAyahs {
            guard let url = QuranAudioSource.url(reciter: reciter, surah: surah.number, verse: nextVerseToQueue) else { break }
            enqueue(url, as: nextVerseToQueue)
            nextVerseToQueue += 1
        }
    }
    
    private func currentItemChanged(to item: AVPlayerItem?) {
        guard isActive else { return }
        
        guard let item else {
            // "No current item" also arrives, a moment late, after play() cleared the queue to restart
            // elsewhere (previous verse, a tapped verse, a reciter change). It also appears briefly between
            // two verses. Only an EMPTY queue counts: the surah finished, or the next verse never loaded.
            guard let surah, player.items().isEmpty, errorMessage == nil else { return }
            if nextVerseToQueue > surah.numberOfAyahs, !loadingFailed {
                stop()
            } else if loadingFailed {
                errorMessage = "Audio needs an internet connection."
                isPlaying = false
                isBuffering = false
            }
            return
        }
        
        let number = verseForItem[ObjectIdentifier(item)] ?? Self.basmalaMarker
        verse = number == Self.basmalaMarker ? nil : number
        topUpQueue()
        updateNowPlaying()
        
    }
    
    // MARK: - Lock Screen and Control Center
    
    private func updateNowPlaying() {
        guard let surah else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: verse.map { "\(surah.englishName) \(surah.number):\($0)" } ?? surah.englishName,
            MPMediaItemPropertyArtist: reciter.englishName,
            MPMediaItemPropertyAlbumTitle: surah.name,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let item = player.currentItem {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = item.currentTime().seconds
            let duration = item.duration.seconds
            if duration.isFinite { info[MPMediaItemPropertyPlaybackDuration] = duration }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func configureRemoteCommandsIfNeeded() {
        guard !didConfigureRemoteCommands else { return }
        didConfigureRemoteCommands = true
        
        let center = MPRemoteCommandCenter.shared()
        func handle(_ command: MPRemoteCommand, _ action: @escaping @MainActor (QuranAudioPlayer) -> Void) {
            command.isEnabled = true
            command.addTarget { [weak self] _ in
                // Bind before the Task: `[weak self]` is a mutable capture, and Swift 6 forbids a
                // concurrently-executing closure referencing one.
                guard let self else { return .success }
                Task { @MainActor in action(self) }
                return .success
            }
        }
        handle(center.playCommand) { $0.player.play() }
        handle(center.pauseCommand) { $0.player.pause() }
        handle(center.togglePlayPauseCommand) { $0.togglePlayPause() }
        handle(center.nextTrackCommand) { $0.next() }
        handle(center.previousTrackCommand) { $0.previous() }
    }
}
