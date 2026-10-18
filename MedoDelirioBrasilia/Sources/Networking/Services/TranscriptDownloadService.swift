//
//  TranscriptDownloadService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/03/26.
//

import CryptoKit
import Foundation
import UIKit

// MARK: - Manifest Models

struct TranscriptManifest: Codable, Sendable {
    let version: Int
    let files: [TranscriptFileEntry]
}

struct TranscriptFileEntry: Codable, Sendable {
    let episodeId: String
    let hash: String
    let size: Int
}

// MARK: - Log Model

struct TranscriptLogEntry: Codable, Identifiable {
    let date: Date
    let message: String
    var id: Date { date }
}

// MARK: - Service

/// Main-actor isolated: every entry point already ran there, and the backgrounding
/// watcher needs `self` to be safe to reference from the notification callback.
@MainActor
@Observable
final class TranscriptDownloadService {

    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case completed
        case failed(message: String)
    }

    private(set) var state: State = .idle
    private(set) var transcriptsDownloaded: Bool
    private(set) var operationLog: [TranscriptLogEntry] = []

    /// Public so the grace-period watcher can tell when the work is done. `state` can't
    /// serve that purpose: a sync of fewer than `visibleSyncThreshold` files never
    /// enters `.downloading`, on purpose, to keep small syncs invisible.
    private(set) var isDownloading = false

    private let userDefaultsKey = "transcriptsDownloaded"
    private let session = URLSession(configuration: .default)

    /// The ETag of the last manifest every local file was confirmed to match. Sent back
    /// on the next check, so an unchanged catalog costs a bodiless 304 instead of the
    /// whole manifest and a diff.
    ///
    /// Only stored after a run that left nothing behind — a run that stopped early or
    /// had a file fail keeps the previous one, or a later 304 would hide the gap for good.
    private let confirmedManifestETagKey = "transcriptManifestConfirmedETag"

    /// How stale a manifest check has to be before a throttled caller gets another one.
    ///
    /// Much longer than the chapters equivalent, deliberately. That one polls a fixed
    /// few-hundred-byte version file; this one, whenever the catalog changed, pulls a
    /// manifest that grows with it. There is nothing to gain from checking often anyway:
    /// transcripts are generated hours after an episode goes out, not minutes.
    static let minimumCheckInterval: TimeInterval = 30 * 60

    /// In-memory on purpose: a fresh process always checks on launch.
    @ObservationIgnored private var lastManifestCheck: Date?

    /// Set when the grace period or a background refresh runs out of time, and cleared
    /// at the start of each run. The download loops check it between files so an
    /// interrupted sync stops at a whole file rather than being killed mid-write.
    @ObservationIgnored private var shouldStopForBackground = false

    /// What's known to be on disk, as `episodeId → SHA-256` of each transcript file,
    /// recorded when the file is written. Lets the diff skip reading and hashing the
    /// whole catalog (tens of megabytes) on every check. Loaded on first use; `nil`
    /// until then.
    @ObservationIgnored private var hashIndex: [String: String]?
    @ObservationIgnored private var hashIndexNeedsSaving = false

    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?

    static let transcriptsDidUpdate = Notification.Name("TranscriptDownloadService.transcriptsDidUpdate")

    /// The one the app runs on. A scheduled background refresh has no view hierarchy to
    /// pull it from the environment, so it reaches it here.
    static let shared = TranscriptDownloadService()

    init() {
        transcriptsDownloaded = UserDefaults.standard.bool(forKey: userDefaultsKey)
        operationLog = Self.loadLog()
    }

    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }

    // MARK: - Public

    private static let visibleSyncThreshold = 5

    /// How a sync ended, for callers that report on it — the background refresh logs it,
    /// since nobody is looking at the app when that one runs.
    enum SyncOutcome: Equatable {
        /// Not opted in, already running, or checked recently enough.
        case skipped
        /// The server says the catalog hasn't changed since the last complete sync.
        case unchanged
        /// The catalog changed, but every file on disk already matches it.
        case upToDate
        case downloaded(succeeded: Int, failed: Int)
        case stopped(downloaded: Int, of: Int)
        /// Transcripts were switched off while it ran; what it wrote is gone again.
        case disabled
        case failed

        var debugLabel: String {
            switch self {
            case .skipped: "pulado"
            case .unchanged: "sem mudanças"
            case .upToDate: "tudo atualizado"
            case .downloaded(let succeeded, let failed): "\(succeeded) baixado(s), \(failed) falha(s)"
            case .stopped(let downloaded, let total): "interrompido com \(downloaded) de \(total)"
            case .disabled: "desativado"
            case .failed: "falhou"
            }
        }
    }

    /// - Parameter minimumInterval: skips the round trip when the last successful manifest
    ///   check is more recent than this. Zero — the launch sync — always checks.
    @MainActor
    @discardableResult
    func syncNewTranscriptsIfNeeded(minimumInterval: TimeInterval = 0) async -> SyncOutcome {
        guard transcriptsDownloaded, !isDownloading, TranscriptPreferences.isEnabled else { return .skipped }

        if minimumInterval > 0,
           let lastManifestCheck,
           Date().timeIntervalSince(lastManifestCheck) < minimumInterval {
            return .skipped
        }

        isDownloading = true
        shouldStopForBackground = false
        observeBackgroundingIfNeeded()

        defer {
            isDownloading = false
            saveHashIndexIfNeeded()
        }

        do {
            let fetchResult = try await fetchManifest(
                ifNoneMatch: UserDefaults.standard.string(forKey: confirmedManifestETagKey)
            )

            // Only a check that reached the server counts as fresh, so being offline for
            // a while doesn't leave the next online trigger throttled out.
            lastManifestCheck = Date()

            guard case .modified(let manifest, let etag) = fetchResult else { return .unchanged }

            let filesToDownload = await filesToDownload(for: manifest)
            guard !filesToDownload.isEmpty else {
                confirmManifest(etag: etag)
                return .upToDate
            }

            appendLog("Sync: \(filesToDownload.count) arquivo(s) para atualizar")

            let showProgress = filesToDownload.count >= Self.visibleSyncThreshold

            if showProgress {
                state = .downloading(progress: 0)
            }

            var downloadedCount = 0
            var failedCount = 0
            var stoppedEarly = false

            for (index, entry) in filesToDownload.enumerated() {
                if TranscriptPreferences.isDisabled {
                    discardAfterDisabling()
                    return .disabled
                }
                if shouldStopForBackground || Task.isCancelled {
                    stoppedEarly = true
                    appendLog("Sync interrompido em segundo plano: \(index) de \(filesToDownload.count)")
                    break
                }
                do {
                    let hash = try await downloadSRT(entry: entry)
                    recordHash(hash, for: entry.episodeId)
                    downloadedCount += 1
                } catch {
                    // Cut off by the background refresh running out of time, not a
                    // problem with the file: the check at the top of the loop stops it.
                    if Task.isCancelled { continue }
                    failedCount += 1
                    appendLog("Sync falha no arquivo \(entry.episodeId): \(error.localizedDescription)")
                    continue
                }
                if showProgress {
                    state = .downloading(progress: Double(index + 1) / Double(filesToDownload.count))
                }
            }

            // Switched off while the last file was on its way.
            if TranscriptPreferences.isDisabled {
                discardAfterDisabling()
                return .disabled
            }

            if stoppedEarly {
                // Whatever landed before the stop is on disk and worth showing, but this
                // run didn't finish — leaving a frozen progress bar or claiming completion
                // would both misreport it. The remainder resumes on the next check.
                if showProgress {
                    state = .idle
                }
                NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
                return .stopped(downloaded: downloadedCount, of: filesToDownload.count)
            }

            appendLog("Sync concluído: \(downloadedCount) arquivo(s), \(failedCount) falha(s)")

            if failedCount == 0 {
                confirmManifest(etag: etag)
            }

            if showProgress {
                markCompleted()
            } else {
                NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
            }
            return .downloaded(succeeded: downloadedCount, failed: failedCount)
        } catch {
            appendLog("Sync falhou: \(error.localizedDescription)")
            if case .downloading = state {
                state = .failed(message: error.localizedDescription)
            }
            return .failed
        }
    }

    @MainActor
    func deleteAllTranscripts() throws {
        try StorageHelper.removeAllFiles(in: Self.transcriptsDirectory())
        hashIndex = [:]
        hashIndexNeedsSaving = false
        try? FileManager.default.removeItem(at: Self.hashIndexFileURL())
        UserDefaults.standard.removeObject(forKey: confirmedManifestETagKey)
        transcriptsDownloaded = false
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
        state = .idle
        appendLog("Todas as transcrições apagadas")
        NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
    }

    /// Turns transcripts off: deletes what's downloaded and keeps every download, sync
    /// and readiness check from running until they're turned back on. A download
    /// already under way stops at the next file and cleans up after itself.
    @MainActor
    func disableTranscripts() throws {
        UserDefaults.standard.set(true, forKey: TranscriptPreferences.disabledKey)
        appendLog("Transcrições desativadas")
        try deleteAllTranscripts()
    }

    /// Lets transcripts be offered again. Downloads nothing by itself: the invitations
    /// come back, and the user decides.
    @MainActor
    func enableTranscripts() {
        UserDefaults.standard.set(false, forKey: TranscriptPreferences.disabledKey)
        appendLog("Transcrições reativadas")
    }

    @MainActor
    func downloadTranscripts(priorityEpisodeId: String? = nil) async {
        guard !isDownloading, TranscriptPreferences.isEnabled else { return }
        isDownloading = true
        shouldStopForBackground = false
        observeBackgroundingIfNeeded()
        state = .downloading(progress: 0)
        appendLog("Iniciando download de transcrições")

        defer {
            isDownloading = false
            saveHashIndexIfNeeded()
        }

        do {
            // Never conditional: this is the opt-in download, and it has to see the
            // whole catalog whatever an earlier sync confirmed.
            guard case .modified(let manifest, let etag) = try await fetchManifest(ifNoneMatch: nil) else {
                throw TranscriptDownloadError.manifestFetchFailed
            }
            lastManifestCheck = Date()
            var filesToDownload = await filesToDownload(for: manifest)

            if filesToDownload.isEmpty {
                appendLog("Download concluído: 0 arquivo(s) (tudo atualizado)")
                confirmManifest(etag: etag)
                markCompleted()
                return
            }

            if let priorityId = priorityEpisodeId,
               let idx = filesToDownload.firstIndex(where: { $0.episodeId == priorityId }) {
                let priority = filesToDownload.remove(at: idx)
                filesToDownload.insert(priority, at: 0)
            }

            var failedCount = 0
            var stoppedEarly = false

            for (index, entry) in filesToDownload.enumerated() {
                if TranscriptPreferences.isDisabled {
                    discardAfterDisabling()
                    return
                }
                if shouldStopForBackground {
                    stoppedEarly = true
                    appendLog("Download interrompido em segundo plano: \(index) de \(filesToDownload.count)")
                    break
                }
                do {
                    let hash = try await downloadSRT(entry: entry)
                    recordHash(hash, for: entry.episodeId)
                } catch {
                    failedCount += 1
                    appendLog("Falha no arquivo \(entry.episodeId): \(error.localizedDescription)")
                    continue
                }

                state = .downloading(progress: Double(index + 1) / Double(filesToDownload.count))

                if index == 0, priorityEpisodeId != nil, !transcriptsDownloaded {
                    transcriptsDownloaded = true
                    UserDefaults.standard.set(true, forKey: userDefaultsKey)
                    NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
                }
            }

            // Switched off while the last file was on its way.
            if TranscriptPreferences.isDisabled {
                discardAfterDisabling()
                return
            }

            if stoppedEarly {
                // The opt-in has to stick even though this run was cut short: files did
                // land, and treating it as never-downloaded would show the prompt again
                // and re-ask a question the user already answered. The rest resumes on
                // the next check.
                markCompleted()
                return
            }

            let successCount = filesToDownload.count - failedCount
            appendLog("Download concluído: \(successCount) arquivo(s), \(failedCount) falha(s)")

            if failedCount > 0 && successCount == 0 {
                state = .failed(message: "Todas as \(failedCount) transcrições falharam ao baixar.")
            } else if failedCount > 0 {
                markCompleted()
            } else {
                confirmManifest(etag: etag)
                markCompleted()
            }
        } catch {
            appendLog("Download falhou: \(error.localizedDescription)")
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Fetches one episode's transcript if the server already has it, reporting whether
    /// it landed.
    ///
    /// This is the "is it ready yet?" probe for an episode whose transcript is still
    /// being generated, so it can appear while the episode is open. It goes straight for
    /// the file rather than consulting the manifest: the manifest lists every episode and
    /// is well over a hundred kilobytes, while a miss here is a bare 404.
    ///
    /// Deliberately quiet. It leaves `state` alone — that drives the full-screen progress
    /// UI, which has no business appearing for a background poll — and logs only when a
    /// file actually arrives, since a miss is the expected case and logging every one
    /// would bury the operation log.
    @MainActor
    func fetchTranscriptIfReady(episodeId: String) async -> Bool {
        guard transcriptsDownloaded, !isDownloading, TranscriptPreferences.isEnabled else { return false }
        guard TranscriptProvider.findSRTFile(for: episodeId) == nil else { return false }

        do {
            // Size and hash go unused by the download itself. What gets recorded is the
            // hash of the bytes that landed, which the next manifest sync checks against
            // the catalog.
            let hash = try await downloadSRT(entry: TranscriptFileEntry(episodeId: episodeId, hash: "", size: 0))
            recordHash(hash, for: episodeId)
            saveHashIndexIfNeeded()
        } catch {
            return false
        }

        appendLog("Transcrição do episódio \(episodeId) chegou")
        NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
        return true
    }

    func clearLog() {
        operationLog = []
        try? FileManager.default.removeItem(at: Self.logFileURL())
    }

    // MARK: - Backgrounding

    /// Asks a sync in progress to stop at the next whole file. For a background refresh
    /// that is running out of time.
    func stopAtNextFile() {
        shouldStopForBackground = true
    }

    /// Starts watching for the app being backgrounded, once, the first time a download
    /// runs. Registering lazily keeps it off the many `TranscriptDownloadService()`
    /// instances that only ever exist to satisfy a SwiftUI preview.
    @MainActor
    private func observeBackgroundingIfNeeded() {
        guard backgroundObserver == nil else { return }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isDownloading else { return }
                TranscriptDownloadContinuation.beginGracePeriod(
                    isStillDownloading: { self.isDownloading },
                    requestStop: { self.shouldStopForBackground = true }
                )
            }
        }
    }

    // MARK: - Private

    private enum ManifestFetchResult {
        case notModified
        case modified(TranscriptManifest, etag: String?)
    }

    /// `nonisolated` so the fetch and the manifest decode stay off the main actor —
    /// the payload grows with the catalog and there is no reason to parse it there.
    ///
    /// - Parameter etag: the last confirmed manifest's ETag. When the server's copy still
    ///   carries it, the answer is a bodiless 304 and this returns `.notModified`.
    nonisolated private func fetchManifest(ifNoneMatch etag: String?) async throws -> ManifestFetchResult {
        let url = URL(string: APIConfig.baseServerURL + "transcripts/v1/manifest.json")!
        var request = URLRequest(url: url)
        // The conditional request is made by hand, so URLCache stays out of it: it would
        // otherwise answer from a stale copy or turn the 304 into a cached 200.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptDownloadError.manifestFetchFailed
        }
        if http.statusCode == 304, etag != nil {
            return .notModified
        }
        guard (200...299).contains(http.statusCode) else {
            throw TranscriptDownloadError.manifestFetchFailed
        }
        let manifest = try JSONDecoder().decode(TranscriptManifest.self, from: data)
        return .modified(manifest, etag: http.value(forHTTPHeaderField: "ETag"))
    }

    /// Runs the diff off the main actor and folds whatever it had to hash into the index.
    private func filesToDownload(for manifest: TranscriptManifest) async -> [TranscriptFileEntry] {
        let knownHashes = loadedHashIndex()
        let directory = Self.transcriptsDirectory()
        let diff = await Task.detached(priority: .utility) {
            Self.diffAgainstLocal(manifest: manifest, knownHashes: knownHashes, directory: directory)
        }.value

        if !diff.learnedHashes.isEmpty {
            for (episodeId, hash) in diff.learnedHashes {
                recordHash(hash, for: episodeId)
            }
            appendLog("Índice de hashes: \(diff.learnedHashes.count) arquivo(s) lido(s) do disco")
        }
        return diff.filesToDownload
    }

    /// Compares the manifest against what's on disk. `learnedHashes` holds the hashes of
    /// files that were on disk but missing from the index, read this time so the next
    /// diff doesn't have to.
    ///
    /// Trusts `knownHashes` for any file it has an entry for, so a normal check is one
    /// directory listing and a dictionary lookup per episode. Only a file with no entry
    /// is read and hashed: everything on the first check after an update from a version
    /// without the index, and afterwards just the odd file whose entry didn't get saved.
    ///
    /// `nonisolated static` and always called from a detached task anyway, since that
    /// first check still reads the whole catalog — tens of megabytes, seconds of work.
    nonisolated static func diffAgainstLocal(
        manifest: TranscriptManifest,
        knownHashes: [String: String],
        directory: URL
    ) -> (filesToDownload: [TranscriptFileEntry], learnedHashes: [String: String]) {
        let filesOnDisk = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        var learnedHashes: [String: String] = [:]

        let filesToDownload = manifest.files.filter { entry in
            let fileName = "\(entry.episodeId).srt"
            guard filesOnDisk.contains(fileName) else { return true }
            if let knownHash = knownHashes[entry.episodeId] {
                return knownHash != entry.hash
            }
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else { return true }
            let localHash = sha256Hex(data)
            learnedHashes[entry.episodeId] = localHash
            return localHash != entry.hash
        }
        return (filesToDownload, learnedHashes)
    }

    /// `nonisolated` so the transfer, the write to disk and the hash stay off the main
    /// actor. A bulk sync runs this hundreds of times in a row.
    ///
    /// - Returns: the SHA-256 of the bytes written. Hashing what actually arrived, not
    ///   copying the manifest's value, means a stale file served by a cache is recorded
    ///   as what it is, and the next diff fetches it again.
    nonisolated private func downloadSRT(entry: TranscriptFileEntry) async throws -> String {
        let remoteURL = URL(string: APIConfig.baseServerURL + "transcripts/v1/\(entry.episodeId).srt")!
        let (data, response) = try await session.data(from: remoteURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TranscriptDownloadError.fileDownloadFailed(entry.episodeId)
        }
        let destination = Self.transcriptsDirectory().appendingPathComponent("\(entry.episodeId).srt")
        try data.write(to: destination, options: .atomic)
        return Self.sha256Hex(data)
    }

    nonisolated static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Records that local files now match this manifest, so the next check can ask the
    /// server whether anything changed since.
    private func confirmManifest(etag: String?) {
        if let etag {
            UserDefaults.standard.set(etag, forKey: confirmedManifestETagKey)
        } else {
            UserDefaults.standard.removeObject(forKey: confirmedManifestETagKey)
        }
    }

    @MainActor
    /// A run that finds transcripts were switched off mid-way: whatever it wrote since
    /// the delete goes too, and it must not mark them as downloaded on the way out.
    private func discardAfterDisabling() {
        appendLog("Download interrompido: transcrições desativadas")
        try? deleteAllTranscripts()
    }

    private func markCompleted() {
        guard TranscriptPreferences.isEnabled else {
            discardAfterDisabling()
            return
        }
        transcriptsDownloaded = true
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        state = .completed
        NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
    }

    nonisolated static func transcriptsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(InternalFolderNames.transcripts)
    }

    // MARK: - Hash Index

    nonisolated static func hashIndexFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("transcript_hashes.json")
    }

    private func loadedHashIndex() -> [String: String] {
        if let hashIndex { return hashIndex }
        let loaded = Self.loadHashIndex()
        hashIndex = loaded
        return loaded
    }

    /// Kept in memory and written once per run rather than once per file: a full download
    /// is close to a thousand files. If the process dies before the write, the files whose
    /// entries were lost are simply hashed from disk on the next diff.
    private func recordHash(_ hash: String, for episodeId: String) {
        var index = loadedHashIndex()
        index[episodeId] = hash
        hashIndex = index
        hashIndexNeedsSaving = true
    }

    private func saveHashIndexIfNeeded() {
        guard hashIndexNeedsSaving, let hashIndex else { return }
        guard let data = try? JSONEncoder().encode(hashIndex) else { return }
        try? data.write(to: Self.hashIndexFileURL(), options: .atomic)
        hashIndexNeedsSaving = false
    }

    nonisolated private static func loadHashIndex() -> [String: String] {
        guard let data = try? Data(contentsOf: hashIndexFileURL()) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    // MARK: - Operation Log

    nonisolated static func logFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("transcript_log.json")
    }

    /// Entries older than this are dropped on every append, so the file this rewrites
    /// on each call stays bounded instead of growing for as long as the app is used.
    private static let logRetention: TimeInterval = 30 * 24 * 60 * 60

    private func appendLog(_ message: String) {
        let entry = TranscriptLogEntry(date: .now, message: message)
        operationLog.append(entry)
        operationLog = Self.trimmed(operationLog)
        Self.persistLog(operationLog)
    }

    nonisolated private static func trimmed(_ entries: [TranscriptLogEntry]) -> [TranscriptLogEntry] {
        let cutoff = Date(timeIntervalSinceNow: -logRetention)
        return entries.filter { $0.date >= cutoff }
    }

    nonisolated private static func persistLog(_ entries: [TranscriptLogEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: logFileURL(), options: .atomic)
    }

    nonisolated private static func loadLog() -> [TranscriptLogEntry] {
        let url = logFileURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = (try? decoder.decode([TranscriptLogEntry].self, from: data)) ?? []

        // Old entries accumulated before this cap existed shouldn't wait for the next
        // sync to be swept out — trim once at load, same as every append does.
        let fresh = trimmed(entries)
        if fresh.count != entries.count {
            persistLog(fresh)
        }
        return fresh
    }
}

// MARK: - Errors

enum TranscriptDownloadError: LocalizedError {
    case manifestFetchFailed
    case fileDownloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .manifestFetchFailed:
            "Não foi possível obter a lista de transcrições do servidor."
        case .fileDownloadFailed(let episodeId):
            "Falha ao baixar transcrição do episódio \(episodeId)."
        }
    }
}
