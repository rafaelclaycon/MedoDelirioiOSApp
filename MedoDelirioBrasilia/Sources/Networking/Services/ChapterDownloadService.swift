//
//  ChapterDownloadService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 30/07/26.
//

import CryptoKit
import Foundation

// MARK: - Version Model

/// Companion to `chapters.json`, small enough to poll on every launch.
struct ChapterVersion: Codable {

    let version: Int
    let hash: String
    let size: Int
    let episodeCount: Int
    let chapterCount: Int

    /// Earliest episode publication date covered, as `yyyy-MM-dd`.
    ///
    /// Optional so a client that ships before the server starts publishing it
    /// still decodes — it falls back to `ChapterPreferences.defaultCoverageStart`.
    let coverageStart: String?
}

// MARK: - Service

/// Keeps the bundled `chapters.json` up to date.
///
/// Unlike transcripts this is not opt-in: chapters are a couple hundred KB for the
/// whole catalog, so every user gets them without being asked. That also means no
/// progress UI and no user-facing failure — a failed sync just leaves the previous
/// file in place and retries next launch.
@Observable
final class ChapterDownloadService {

    enum State: Equatable {
        case idle
        case syncing
        case upToDate
        case failed(message: String)
    }

    private(set) var state: State = .idle

    private var isSyncing = false
    private let session = URLSession(configuration: .default)
    private let storedHashKey = "chaptersFileHash"

    /// Posted only when the file on disk actually changed, so observers can reload
    /// without being woken by no-op syncs.
    static let chaptersDidUpdate = Notification.Name("ChapterDownloadService.chaptersDidUpdate")

    // MARK: - Public

    @MainActor
    func syncIfNeeded() async {
        guard !isSyncing else { return }
        isSyncing = true
        state = .syncing

        defer { isSyncing = false }

        do {
            let remote = try await fetchVersion()

            // Persisted before the up-to-date check below, so a coverage change
            // lands even when chapters.json itself is unchanged.
            if let coverageStart = remote.coverageStart,
               ChapterPreferences.coverageDate(from: coverageStart) != nil {
                UserDefaults.standard.set(coverageStart, forKey: ChapterPreferences.coverageStartKey)
            }

            if remote.hash == UserDefaults.standard.string(forKey: storedHashKey),
               FileManager.default.fileExists(atPath: Self.chaptersFileURL().path) {
                state = .upToDate
                return
            }

            let data = try await downloadChapters()

            // The hash is the only integrity check between here and the server, so
            // a mismatch means a truncated or stale-cached body — discard it rather
            // than overwriting a good file with a bad one.
            let downloadedHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard downloadedHash == remote.hash else {
                throw ChapterDownloadError.hashMismatch
            }

            try write(data)
            UserDefaults.standard.set(remote.hash, forKey: storedHashKey)
            state = .upToDate
            NotificationCenter.default.post(name: Self.chaptersDidUpdate, object: nil)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    @MainActor
    func deleteChapters() throws {
        let url = Self.chaptersFileURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: storedHashKey)
        state = .idle
        NotificationCenter.default.post(name: Self.chaptersDidUpdate, object: nil)
    }

    // MARK: - Private

    private func fetchVersion() async throws -> ChapterVersion {
        let url = URL(string: APIConfig.baseServerURL + "chapters/v1/version.json")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ChapterDownloadError.versionFetchFailed
        }
        return try JSONDecoder().decode(ChapterVersion.self, from: data)
    }

    private func downloadChapters() async throws -> Data {
        let url = URL(string: APIConfig.baseServerURL + "chapters/v1/chapters.json")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ChapterDownloadError.fileDownloadFailed
        }
        return data
    }

    private func write(_ data: Data) throws {
        let directory = Self.chaptersDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: Self.chaptersFileURL(), options: .atomic)
    }

    // MARK: - Paths

    static func chaptersDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(InternalFolderNames.chapters)
    }

    static func chaptersFileURL() -> URL {
        chaptersDirectory().appendingPathComponent("chapters.json")
    }
}

// MARK: - Errors

enum ChapterDownloadError: LocalizedError {

    case versionFetchFailed
    case fileDownloadFailed
    case hashMismatch

    var errorDescription: String? {
        switch self {
        case .versionFetchFailed:
            "Não foi possível verificar a versão dos capítulos."
        case .fileDownloadFailed:
            "Falha ao baixar os capítulos."
        case .hashMismatch:
            "O arquivo de capítulos baixado não corresponde ao esperado."
        }
    }
}
