//
//  TranscriptDownloadService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/03/26.
//

import CryptoKit
import Foundation

// MARK: - Manifest Models

struct TranscriptManifest: Codable {
    let version: Int
    let files: [TranscriptFileEntry]
}

struct TranscriptFileEntry: Codable {
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

    private var isDownloading = false
    private let userDefaultsKey = "transcriptsDownloaded"
    private let session = URLSession(configuration: .default)

    static let transcriptsDidUpdate = Notification.Name("TranscriptDownloadService.transcriptsDidUpdate")

    init() {
        transcriptsDownloaded = UserDefaults.standard.bool(forKey: userDefaultsKey)
        operationLog = Self.loadLog()
    }

    // MARK: - Public

    private static let visibleSyncThreshold = 5

    @MainActor
    func syncNewTranscriptsIfNeeded() async {
        guard transcriptsDownloaded, !isDownloading else { return }
        isDownloading = true

        defer { isDownloading = false }

        do {
            let manifest = try await fetchManifest()
            let filesToDownload = try diffAgainstLocal(manifest: manifest)
            guard !filesToDownload.isEmpty else { return }

            appendLog("Sync: \(filesToDownload.count) arquivo(s) para atualizar")

            let showProgress = filesToDownload.count >= Self.visibleSyncThreshold

            if showProgress {
                state = .downloading(progress: 0)
            }

            var failedCount = 0

            for (index, entry) in filesToDownload.enumerated() {
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
        state = .downloading(progress: 0)
        appendLog("Iniciando download de transcrições")

        defer { isDownloading = false }

        do {
            let manifest = try await fetchManifest()
            var filesToDownload = try diffAgainstLocal(manifest: manifest)

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

            for (index, entry) in filesToDownload.enumerated() {
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

    func clearLog() {
        operationLog = []
        try? FileManager.default.removeItem(at: Self.logFileURL())
    }

    // MARK: - Private

    private func fetchManifest() async throws -> TranscriptManifest {
        let url = URL(string: APIConfig.baseServerURL + "transcripts/v1/manifest.json")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TranscriptDownloadError.manifestFetchFailed
        }
        return try JSONDecoder().decode(TranscriptManifest.self, from: data)
    }

    private func diffAgainstLocal(manifest: TranscriptManifest) throws -> [TranscriptFileEntry] {
        let transcriptsDir = Self.transcriptsDirectory()

        return manifest.files.filter { entry in
            let localFile = transcriptsDir.appendingPathComponent("\(entry.episodeId).srt")
            guard FileManager.default.fileExists(atPath: localFile.path) else { return true }
            guard let data = try? Data(contentsOf: localFile) else { return true }
            let localHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            return localHash != entry.hash
        }
    }

    private func downloadSRT(entry: TranscriptFileEntry) async throws {
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

    static func transcriptsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(InternalFolderNames.transcripts)
    }

    // MARK: - Operation Log

    static func logFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("transcript_log.json")
    }

    private func appendLog(_ message: String) {
        let entry = TranscriptLogEntry(date: .now, message: message)
        operationLog.append(entry)
        Self.persistLog(operationLog)
    }

    private static func persistLog(_ entries: [TranscriptLogEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: logFileURL(), options: .atomic)
    }

    private static func loadLog() -> [TranscriptLogEntry] {
        let url = logFileURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TranscriptLogEntry].self, from: data)) ?? []
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
