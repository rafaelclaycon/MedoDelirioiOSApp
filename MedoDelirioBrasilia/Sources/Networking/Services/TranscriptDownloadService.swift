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

    private let userDefaultsKey = "transcriptsDownloaded"
    private let session = URLSession(configuration: .default)

    static let transcriptsDidUpdate = Notification.Name("TranscriptDownloadService.transcriptsDidUpdate")

    init() {
        transcriptsDownloaded = UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    // MARK: - Public

    @MainActor
    func syncNewTranscriptsIfNeeded() async {
        guard transcriptsDownloaded else { return }
        guard state == .idle || state == .completed else { return }

        do {
            let manifest = try await fetchManifest()
            let filesToDownload = try diffAgainstLocal(manifest: manifest)
            guard !filesToDownload.isEmpty else { return }

            for entry in filesToDownload {
                try await downloadSRT(entry: entry)
            }
            NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
        } catch {
            // Silent failure — background convenience sync
        }
    }

    @MainActor
    func deleteAllTranscripts() throws {
        try StorageHelper.removeAllFiles(in: Self.transcriptsDirectory())
        transcriptsDownloaded = false
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
        state = .idle
        NotificationCenter.default.post(name: Self.transcriptsDidUpdate, object: nil)
    }

    @MainActor
    func downloadTranscripts() async {
        guard state != .downloading(progress: 0) else { return }
        state = .downloading(progress: 0)

        do {
            let manifest = try await fetchManifest()
            let filesToDownload = try diffAgainstLocal(manifest: manifest)

            if filesToDownload.isEmpty {
                markCompleted()
                return
            }

            for (index, entry) in filesToDownload.enumerated() {
                try await downloadSRT(entry: entry)
                state = .downloading(progress: Double(index + 1) / Double(filesToDownload.count))
            }

            markCompleted()
        } catch {
            state = .failed(message: error.localizedDescription)
        }
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
