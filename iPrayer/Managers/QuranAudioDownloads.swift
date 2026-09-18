//
//  QuranAudioDownloads.swift
//  iPrayer
//
//  Downloads a surah's recitation for offline listening, per reciter.
//
//  Files live in Application Support/QuranAudio/<reciter>/<SSS>/<AAA>.mp3, with a ".complete" marker once every
//  verse of the surah is there. The folder is excluded from iCloud and device backups: the audio can always be
//  downloaded again, and Apple rejects apps that back up re-downloadable content.
//

import Foundation
import Combine

@MainActor
final class QuranAudioDownloads: ObservableObject {
    static let shared = QuranAudioDownloads()
    
    enum State: Equatable {
        case none
        case downloading(Double)   // 0...1
        case downloaded
    }
    
    /// Downloads in flight, keyed by reciter and surah
    @Published private(set) var progress: [String: Double] = [:]
    /// Surahs fully downloaded, keyed by reciter and surah
    @Published private(set) var downloaded: Set<String> = []
    @Published private(set) var totalBytes: Int64 = 0
    /// Everything on disk, grouped by reciter, for the storage manager in Settings
    @Published private(set) var stored: [StoredReciter] = []
    
    /// One surah folder on disk. Partial downloads are listed too, so the user can clear them.
    struct StoredSurah: Identifiable, Equatable {
        let reciter: QuranReciter
        let surah: Int
        let bytes: Int64
        let isComplete: Bool
        var id: String { "\(reciter.id)|\(surah)" }
    }
    
    /// One reciter folder on disk. `bytes` includes the basmala file shared by every surah.
    struct StoredReciter: Identifiable, Equatable {
        let reciter: QuranReciter
        let bytes: Int64
        let surahs: [StoredSurah]
        var id: String { reciter.id }
    }
    /// AppTranslations key for the last failure, shown by the reader
    @Published var lastError: String?
    
    private var tasks: [String: Task<Void, Never>] = [:]
    
    /// Requests running at once. EveryAyah asks for a maximum of two connections at a time per person,
    /// so that downloads don't make the files hard to reach for everyone else.
    private static let concurrentRequests = 2
    
    private init() {
        rescan()
    }
    
    // MARK: - Locations (nonisolated: the player asks for these too)
    
    nonisolated static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("QuranAudio", isDirectory: true)
    }
    
    nonisolated private static func surahDirectory(reciter: QuranReciter, surah: Int) -> URL {
        root.appendingPathComponent(reciter.id, isDirectory: true)
            .appendingPathComponent(String(format: "%03d", surah), isDirectory: true)
    }
    
    nonisolated static func localURL(reciter: QuranReciter, surah: Int, verse: Int) -> URL {
        surahDirectory(reciter: reciter, surah: surah).appendingPathComponent(String(format: "%03d.mp3", verse))
    }
    
    nonisolated static func localBasmalaURL(reciter: QuranReciter) -> URL {
        root.appendingPathComponent(reciter.id, isDirectory: true).appendingPathComponent("basmala.mp3")
    }
    
    /// The downloaded file for a verse, if there is one. Partial downloads count too.
    nonisolated static func existingFile(reciter: QuranReciter, surah: Int, verse: Int) -> URL? {
        let url = localURL(reciter: reciter, surah: surah, verse: verse)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    nonisolated static func existingBasmala(reciter: QuranReciter) -> URL? {
        let url = localBasmalaURL(reciter: reciter)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    private static func key(_ reciter: QuranReciter, _ surah: Int) -> String { "\(reciter.id)|\(surah)" }
    
    // MARK: - State
    
    func state(for surah: Int, reciter: QuranReciter) -> State {
        let key = Self.key(reciter, surah)
        if let fraction = progress[key] { return .downloading(fraction) }
        return downloaded.contains(key) ? .downloaded : .none
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    /// Rebuilds the list of completed downloads, the per-reciter inventory and the space used from what is on disk.
    func rescan() {
        let manager = FileManager.default
        var found: Set<String> = []
        var bytes: Int64 = 0
        // reciter id -> (surah -> (bytes, complete)), plus bytes that belong to the reciter as a whole (basmala)
        var surahBytes: [String: [Int: (bytes: Int64, complete: Bool)]] = [:]
        var reciterBytes: [String: Int64] = [:]
        
        if let enumerator = manager.enumerator(at: Self.root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
            for case let url as URL in enumerator {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                let size = Int64(values?.fileSize ?? 0)
                bytes += size
                
                // Files are <reciter>/<SSS>/<AAA>.mp3, <reciter>/<SSS>/.complete or <reciter>/basmala.mp3.
                // Walk up from the file rather than counting from the root: on a device the enumerator can hand
                // back paths with the /private prefix resolved differently from `root`.
                let parent = url.deletingLastPathComponent()
                if url.lastPathComponent == "basmala.mp3" {
                    reciterBytes[parent.lastPathComponent, default: 0] += size
                } else if let surah = Int(parent.lastPathComponent) {
                    let reciterID = parent.deletingLastPathComponent().lastPathComponent
                    reciterBytes[reciterID, default: 0] += size
                    var entry = surahBytes[reciterID, default: [:]][surah] ?? (0, false)
                    entry.bytes += size
                    if url.lastPathComponent == ".complete" {
                        entry.complete = true
                        found.insert("\(reciterID)|\(surah)")
                    }
                    surahBytes[reciterID, default: [:]][surah] = entry
                }
            }
        }
        
        // Known reciters first, in the order the picker shows them; anything unknown (a reciter removed from
        // a later version of the app) still appears so its files can be deleted.
        let knownIDs = QuranReciter.all.map(\.id)
        let reciterIDs = reciterBytes.keys.sorted { a, b in
            let ia = knownIDs.firstIndex(of: a) ?? Int.max
            let ib = knownIDs.firstIndex(of: b) ?? Int.max
            return ia == ib ? a < b : ia < ib
        }
        stored = reciterIDs.compactMap { reciterID in
            let surahs = (surahBytes[reciterID] ?? [:]).keys.sorted().map { surah in
                let entry = surahBytes[reciterID]![surah]!
                return StoredSurah(reciter: Self.reciter(withStoredID: reciterID), surah: surah, bytes: entry.bytes, isComplete: entry.complete)
            }
            guard !surahs.isEmpty else { return nil }
            return StoredReciter(reciter: Self.reciter(withStoredID: reciterID), bytes: reciterBytes[reciterID] ?? 0, surahs: surahs)
        }
        downloaded = found
        totalBytes = bytes
    }
    
    /// The reciter for a folder name. Unknown folders get a placeholder so they can still be shown and removed.
    private static func reciter(withStoredID id: String) -> QuranReciter {
        QuranReciter.all.first { $0.id == id } ?? QuranReciter(id: id, englishName: id, arabicName: id)
    }
    
    // MARK: - Downloading
    
    func download(surah: SurahMetadata, reciter: QuranReciter) {
        let key = Self.key(reciter, surah.number)
        guard tasks[key] == nil, !downloaded.contains(key) else { return }
        
        lastError = nil
        progress[key] = 0
        
        // Everything the surah needs: each verse, plus the basmala that is recited before verse 1
        var jobs: [(remote: URL, local: URL)] = []
        for verse in 1...max(1, surah.numberOfAyahs) {
            if let remote = QuranAudioSource.remoteURL(reciter: reciter, surah: surah.number, verse: verse) {
                jobs.append((remote, Self.localURL(reciter: reciter, surah: surah.number, verse: verse)))
            }
        }
        if let remote = QuranAudioSource.remoteBasmalaURL(reciter: reciter) {
            jobs.append((remote, Self.localBasmalaURL(reciter: reciter)))
        }
        let directory = Self.surahDirectory(reciter: reciter, surah: surah.number)
        
        tasks[key] = Task {
            // The host publishes one archive per surah: a single request instead of one per verse, which is
            // several times faster on long surahs. Anything that fails falls back to the per-verse files.
            var succeeded = false
            if let archive = QuranAudioSource.surahArchiveURL(reciter: reciter, surah: surah.number) {
                succeeded = await Self.downloadArchive(archive, into: directory, reciter: reciter) { fraction in
                    self.progress[key] = fraction
                }
            }
            if !succeeded, !Task.isCancelled {
                succeeded = await Self.run(jobs, in: directory) { fraction in
                    self.progress[key] = fraction
                }
            }
            
            progress[key] = nil
            tasks[key] = nil
            if succeeded {
                FileManager.default.createFile(atPath: directory.appendingPathComponent(".complete").path, contents: Data())
                Haptics.success()
            } else if !Task.isCancelled {
                lastError = "Download failed. Check your connection."
            }
            rescan()
        }
    }
    
    func cancel(surah: Int, reciter: QuranReciter) {
        tasks[Self.key(reciter, surah)]?.cancel()
    }
    
    /// Downloads the surah archive with progress, then unpacks its verse files into `directory`.
    /// Returns false on any failure, leaving the caller to fall back to per-verse downloads.
    private static func downloadArchive(_ url: URL, into directory: URL, reciter: QuranReciter, onProgress: @escaping @MainActor (Double) -> Void) async -> Bool {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            var rootURL = root
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? rootURL.setResourceValues(values)
        } catch {
            return false
        }
        
        // The transfer is 0...90% of the progress bar, unpacking the rest
        let downloader = ArchiveDownloader()
        guard let archiveFile = await downloader.download(url, onProgress: { fraction in
            Task { @MainActor in onProgress(fraction * 0.9) }
        }) else { return false }
        defer { try? manager.removeItem(at: archiveFile) }
        guard !Task.isCancelled else { return false }
        
        do {
            let data = try Data(contentsOf: archiveFile, options: .mappedIfSafe)
            let entries = try ZipArchive.entries(in: data)
            var written = 0
            for entry in entries {
                guard !Task.isCancelled else { return false }
                // Entries are SSSAAA.mp3; AAA = 000 is the basmala recited before verse 1
                let name = (entry.name as NSString).lastPathComponent
                guard name.hasSuffix(".mp3"), name.count == 10, let number = Int(name.dropLast(4).suffix(3)) else { continue }
                let destination = number == 0
                    ? localBasmalaURL(reciter: reciter)
                    : directory.appendingPathComponent(String(format: "%03d.mp3", number))
                if number == 0, manager.fileExists(atPath: destination.path) { continue }
                try extract(entry, from: data).write(to: destination, options: .atomic)
                written += 1
                onProgress(0.9 + 0.1 * Double(written) / Double(max(1, entries.count)))
            }
            return written > 0
        } catch {
            print("Archive unpack failed: \(error)")
            return false
        }
    }
    
    nonisolated private static func extract(_ entry: ZipArchive.Entry, from data: Data) throws -> Data {
        try ZipArchive.extract(entry, from: data)
    }
    
    /// Fetches the files a few at a time. Files already on disk are skipped, so an interrupted download resumes.
    private static func run(_ jobs: [(remote: URL, local: URL)], in directory: URL, onProgress: @escaping @MainActor (Double) -> Void) async -> Bool {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            // Re-downloadable content must stay out of backups
            var rootURL = root
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? rootURL.setResourceValues(values)
        } catch {
            return false
        }
        
        var remaining = jobs.makeIterator()
        var finished = 0
        var allSucceeded = true
        
        await withTaskGroup(of: Bool.self) { group in
            func addNext() {
                guard let job = remaining.next() else { return }
                group.addTask {
                    if FileManager.default.fileExists(atPath: job.local.path) { return true }
                    do {
                        let (temporary, response) = try await URLSession.shared.download(from: job.remote)
                        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
                        try? FileManager.default.removeItem(at: job.local)
                        try FileManager.default.moveItem(at: temporary, to: job.local)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            for _ in 0..<concurrentRequests { addNext() }
            
            for await success in group {
                finished += 1
                if !success { allSucceeded = false }
                onProgress(Double(finished) / Double(max(1, jobs.count)))
                
                if Task.isCancelled || !allSucceeded {
                    group.cancelAll()
                } else {
                    addNext()
                }
            }
        }
        return allSucceeded && !Task.isCancelled && finished == jobs.count
    }
    
    // MARK: - Removing
    
    func remove(surah: Int, reciter: QuranReciter) {
        cancel(surah: surah, reciter: reciter)
        let manager = FileManager.default
        try? manager.removeItem(at: Self.surahDirectory(reciter: reciter, surah: surah))
        
        // The basmala is only useful alongside a surah: once the last one is gone, drop the reciter folder too
        let reciterFolder = Self.root.appendingPathComponent(reciter.id, isDirectory: true)
        let remaining = (try? manager.contentsOfDirectory(at: reciterFolder, includingPropertiesForKeys: nil)) ?? []
        if !remaining.contains(where: { Int($0.lastPathComponent) != nil }) {
            try? manager.removeItem(at: reciterFolder)
        }
        rescan()
    }
    
    /// Removes every surah (and the basmala) downloaded for one reciter.
    func remove(reciter: QuranReciter) {
        for (key, task) in tasks where key.hasPrefix(reciter.id + "|") {
            task.cancel()
        }
        try? FileManager.default.removeItem(at: Self.root.appendingPathComponent(reciter.id, isDirectory: true))
        rescan()
    }
    
    func removeAll() {
        tasks.values.forEach { $0.cancel() }
        try? FileManager.default.removeItem(at: Self.root)
        rescan()
    }
}

/// A download task with progress, wrapped for async use. Cancelling the surrounding task cancels the transfer.
private final class ArchiveDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL?, Never>?
    private var onProgress: ((Double) -> Void)?
    private var task: URLSessionDownloadTask?
    
    func download(_ url: URL, onProgress: @escaping (Double) -> Void) async -> URL? {
        self.onProgress = onProgress
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                let task = session.downloadTask(with: url)
                self.task = task
                task.resume()
            }
        } onCancel: {
            task?.cancel()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The file is deleted when this returns, so move it somewhere that outlives the callback
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        let ok = (downloadTask.response as? HTTPURLResponse)?.statusCode == 200
            && (try? FileManager.default.moveItem(at: location, to: kept)) != nil
        continuation?.resume(returning: ok ? kept : nil)
        continuation = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
