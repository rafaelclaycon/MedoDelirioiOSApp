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

    /// How stale a manifest check has to be before a throttled caller gets another one.
    ///
    /// Much longer than the chapters equivalent, deliberately. That one polls a fixed
    /// few-hundred-byte version file; this one pulls a manifest that grows with the
    /// catalog and then reads and hashes every local transcript to diff against it —
    /// currently tens of megabytes of disk. Cheap to do occasionally, wasteful of
    /// battery to do often, and there is nothing to gain: transcripts are generated
    /// hours after an episode goes out, not minutes.
    static let minimumCheckInterval: TimeInterval = 30 * 60

    /// In-memory on purpose: a fresh process always checks on launch.
    @ObservationIgnored private var lastManifestCheck: Date?

    /// Set when the grace period runs out, and cleared at the start of each run. The
    /// download loops check it between files so an interrupted sync stops at a whole
    /// file rather than being killed mid-write.
    @ObservationIgnored private var shouldStopForBackground = false

    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?

    static let transcriptsDidUpdate = Notification.Name("TranscriptDownloadService.transcriptsDidUpdate")

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

    /// - Parameter minimumInterval: skips the round trip when the last successful manifest
    ///   check is more recent than this. Zero — the launch sync — always checks.
    @MainActor
    func syncNewTranscriptsIfNeeded(minimumInterval: TimeInterval = 0) async {
        guard transcriptsDownloaded, !isDownloading else { return }

        if minimumInterval > 0,
           let lastManifestCheck,
           Date().timeIntervalSince(lastManifestCheck) < minimumInterval {
            return
        }

        isDownloading = true
        shouldStopForBackground = false
        observeBackgroundingIfNeeded()

        defer { isDownloading = false }

        do {
            let manifest = try await fetchManifest()

            // Only a check that reached the server counts as fresh, so being offline for
            // a while doesn't leave the next online trigger throttled out.
            lastManifestCheck = Date()

            let filesToDownload = await Task.detached(priority: .utility) {
                Self.diffAgainstLocal(manifest: manifest)
            }.value
            guard !filesToDownload.isEmpty else { return }

            appendLog("Sync: \(filesToDownload.count) arquivo(s) para atualizar")

            let showProgress = filesToDownload.count >= Self.visibleSyncThreshold

            if showProgress {
                state = .downloading(progress: 0)
            }

            var failedCount = 0
            var stoppedEarly = false

            for (index, entry) in filesToDownload.enumerated() {
                if shouldStopForBackground {
                    stoppedEarly = true
                    appendLog("Sync interrompido em segundo plano: \(index) de \(filesToDownload.count)")
                    break
                }
                do {
                    try await downloadSRT(entry: entry)
                } catch {
                    failedCount += 1
                    appendLog("Sync falha no arquivo \(entry.episodeId): \(error.localizedDescription)")
                    continue
                }
                if showProgress {
                    state = .downloading(progress: Double(index + 1) / Double(filesToDownload.count))
                }
            }

            if stoppedEarly {
                // Whatever landed before the stop is on disk and worth showing, but this
                // run didn't finish — leaving a frozen progress bar or claiming completion
                // would both misreport it. The remainder resumes on the next check.
                if showProgress {
                    state = .idle
                }
                NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
                return
            }

            let successCount = filesToDownload.count - failedCount
            appendLog("Sync concluído: \(successCount) arquivo(s), \(failedCount) falha(s)")

            if showProgress {
                markCompleted()
            } else {
                NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
            }
        } catch {
            appendLog("Sync falhou: \(error.localizedDescription)")
            if case .downloading = state {
                state = .failed(message: error.localizedDescription)
            }
        }
    }

    @MainActor
    func deleteAllTranscripts() throws {
        try StorageHelper.removeAllFiles(in: Self.transcriptsDirectory())
        transcriptsDownloaded = false
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
        state = .idle
        appendLog("Todas as transcrições apagadas")
        NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
    }

    @MainActor
    func downloadTranscripts(priorityEpisodeId: String? = nil) async {
        guard !isDownloading else { return }
        isDownloading = true
        shouldStopForBackground = false
        observeBackgroundingIfNeeded()
        state = .downloading(progress: 0)
        appendLog("Iniciando download de transcrições")

        defer { isDownloading = false }

        do {
            let manifest = try await fetchManifest()
            lastManifestCheck = Date()
            var filesToDownload = await Task.detached(priority: .utility) {
                Self.diffAgainstLocal(manifest: manifest)
            }.value

            if filesToDownload.isEmpty {
                appendLog("Download concluído: 0 arquivo(s) (tudo atualizado)")
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
                if shouldStopForBackground {
                    stoppedEarly = true
                    appendLog("Download interrompido em segundo plano: \(index) de \(filesToDownload.count)")
                    break
                }
                do {
                    try await downloadSRT(entry: entry)
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
        guard transcriptsDownloaded, !isDownloading else { return false }
        guard TranscriptProvider.findSRTFile(for: episodeId) == nil else { return false }

        do {
            // Size and hash go unused by the download itself; the next manifest sync is
            // what verifies this file against the catalog.
            try await downloadSRT(entry: TranscriptFileEntry(episodeId: episodeId, hash: "", size: 0))
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

    /// `nonisolated` so the fetch and the manifest decode stay off the main actor —
    /// the payload grows with the catalog and there is no reason to parse it there.
    nonisolated private func fetchManifest() async throws -> TranscriptManifest {
        let url = URL(string: APIConfig.baseServerURL + "transcripts/v1/manifest.json")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TranscriptDownloadError.manifestFetchFailed
        }
        return try JSONDecoder().decode(TranscriptManifest.self, from: data)
    }

    /// Compares the manifest against what's on disk.
    ///
    /// `nonisolated static` and always called from a detached task, because this reads
    /// and hashes **every** local transcript — tens of megabytes across hundreds of files,
    /// seconds of work. Run on the main actor, as it would be by default now that this
    /// type is `@MainActor`, it freezes the UI for the duration.
    nonisolated private static func diffAgainstLocal(
        manifest: TranscriptManifest
    ) -> [TranscriptFileEntry] {
        let transcriptsDir = Self.transcriptsDirectory()

        return manifest.files.filter { entry in
            let localFile = transcriptsDir.appendingPathComponent("\(entry.episodeId).srt")
            guard FileManager.default.fileExists(atPath: localFile.path) else { return true }
            guard let data = try? Data(contentsOf: localFile) else { return true }
            let localHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            return localHash != entry.hash
        }
    }

    /// `nonisolated` so the transfer and the write to disk stay off the main actor.
    /// A bulk sync runs this hundreds of times in a row.
    nonisolated private func downloadSRT(entry: TranscriptFileEntry) async throws {
        let remoteURL = URL(string: APIConfig.baseServerURL + "transcripts/v1/\(entry.episodeId).srt")!
        let (data, response) = try await session.data(from: remoteURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TranscriptDownloadError.fileDownloadFailed(entry.episodeId)
        }
        let destination = Self.transcriptsDirectory().appendingPathComponent("\(entry.episodeId).srt")
        try data.write(to: destination, options: .atomic)
    }

    @MainActor
    private func markCompleted() {
        transcriptsDownloaded = true
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        state = .completed
        NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
    }

    nonisolated static func transcriptsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(InternalFolderNames.transcripts)
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
