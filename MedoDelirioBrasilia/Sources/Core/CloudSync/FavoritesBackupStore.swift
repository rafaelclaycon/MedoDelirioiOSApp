//
//  FavoritesBackupStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Foundation
import os

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "FavoritesBackupStore")

/// The sound and song favorites at one moment.
struct FavoritesBackup: Codable, Equatable {

    enum Kind: String, Codable {
        /// Taken right before this device first synced favorites. Kept for good.
        case beforeFirstSync
        /// Taken before the first sync of a day, when the favorites changed since the
        /// last backup. The newest few are kept.
        case daily
    }

    struct Entry: Codable, Equatable {
        let contentId: String
        let dateAdded: Date
    }

    var version: Int = 1
    let kind: Kind
    let createdAt: Date
    let favorites: [Entry]
}

/// A backup on disk, as listed in Diagnostics.
struct FavoritesBackupFile: Identifiable, Hashable {

    let url: URL
    let kind: FavoritesBackup.Kind
    let createdAt: Date
    let count: Int

    var id: URL { url }
}

/// Keeps copies of the favorites in `Documents/FavoritesBackups`, so a sync problem,
/// ours or iCloud's, can't take anyone's favorites for good. iCloud sync spreads a
/// wrong removal to every device in minutes; these copies stay on this one, and go
/// into the device backup with the rest of Documents.
///
/// Diagnostics lists them and restores from them. Restoring only adds.
final class FavoritesBackupStore {

    static let dailyBackupsKept = 7

    private static let beforeFirstSyncFileName = "before-first-sync.json"
    private static let dailyFilePrefix = "daily-"

    private let database: LocalDatabaseProtocol
    private let directory: URL
    private let now: () -> Date

    /// The day `backUpBeforeSync(favorites:)` last looked, so later syncs that day skip
    /// the disk.
    private var lastCheckedDay: String?

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FavoritesBackups")
    }

    init(
        database: LocalDatabaseProtocol = LocalDatabase.shared,
        directory: URL = FavoritesBackupStore.defaultDirectory,
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.directory = directory
        self.now = now
    }

    // MARK: - Backing Up

    /// Called by `CloudStateSync` right before it syncs favorites.
    ///
    /// The first time ever, saves the favorites as they were before sync existed. After
    /// that, once a day at most: saves them if there are any and they differ from the
    /// newest backup, then drops the daily ones past `dailyBackupsKept`. An empty or
    /// unchanged list never pushes out an older, useful backup.
    func backUpBeforeSync(favorites: [String: Date]) {
        let date = now()

        if !FileManager.default.fileExists(atPath: url(for: Self.beforeFirstSyncFileName).path) {
            write(FavoritesBackup(kind: .beforeFirstSync, createdAt: date, favorites: Self.entries(favorites)),
                  to: Self.beforeFirstSyncFileName)
        }

        let day = Self.dayString(date)
        guard lastCheckedDay != day else { return }
        lastCheckedDay = day

        guard !favorites.isEmpty else { return }

        let fileName = Self.dailyFilePrefix + day + ".json"
        guard !FileManager.default.fileExists(atPath: url(for: fileName).path) else { return }

        if let newest = backups().first.flatMap({ backup(at: $0.url) }),
           Set(newest.favorites.map(\.contentId)) == Set(favorites.keys) {
            return
        }

        write(FavoritesBackup(kind: .daily, createdAt: date, favorites: Self.entries(favorites)), to: fileName)
        pruneDailyBackups()
    }

    // MARK: - Reading

    /// Every backup on disk, newest first.
    func backups() -> [FavoritesBackupFile] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let backup = backup(at: url) else { return nil }
                return FavoritesBackupFile(
                    url: url,
                    kind: backup.kind,
                    createdAt: backup.createdAt,
                    count: backup.favorites.count
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func backup(at url: URL) -> FavoritesBackup? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(FavoritesBackup.self, from: data)
    }

    // MARK: - Restoring

    /// The favorites in `backup` this device no longer has.
    func missingFavorites(in backup: FavoritesBackup) -> [FavoritesBackup.Entry] {
        let current = (try? database.allFavoriteDates()) ?? [:]
        return backup.favorites.filter { current[$0.contentId] == nil }
    }

    /// Adds back every favorite in `backup` this device no longer has, and never removes
    /// one. Returns how many came back.
    ///
    /// They're dated now, a hundredth of a second apart in their original order, so they
    /// beat any removal that synced since and still sort the way they did. Posting
    /// `didChangeLocally` sends them to the other devices too.
    @discardableResult
    func restore(_ backup: FavoritesBackup) -> Int {
        let missing = missingFavorites(in: backup).sorted { $0.dateAdded < $1.dateAdded }
        guard !missing.isEmpty else { return 0 }

        let date = now()
        for (index, entry) in missing.enumerated() {
            let restoredAt = date.addingTimeInterval(-Double(missing.count - 1 - index) * 0.01)
            try? database.upsertFavorite(contentId: entry.contentId, dateAdded: restoredAt)
            try? database.deleteFavoriteTombstone(contentId: entry.contentId)
        }

        NotificationCenter.default.post(name: ContentFavoritesSyncStore.didChangeLocally, object: nil)
        NotificationCenter.default.post(name: ContentFavoritesSyncStore.didChangeExternally, object: nil)
        return missing.count
    }

    // MARK: - Private

    private func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    private func write(_ backup: FavoritesBackup, to fileName: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(backup)
            try data.write(to: url(for: fileName), options: .atomic)
            logger.info("Backed up \(backup.favorites.count) favorites to \(fileName, privacy: .public).")
        } catch {
            logger.error("Couldn't back up favorites to \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pruneDailyBackups() {
        let dailies = backups().filter { $0.kind == .daily }
        for file in dailies.dropFirst(Self.dailyBackupsKept) {
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    private static func entries(_ favorites: [String: Date]) -> [FavoritesBackup.Entry] {
        favorites
            .map { FavoritesBackup.Entry(contentId: $0.key, dateAdded: $0.value) }
            .sorted { $0.dateAdded != $1.dateAdded ? $0.dateAdded < $1.dateAdded : $0.contentId < $1.contentId }
    }

    /// Local calendar day, since "a backup a day" means the user's day.
    private static func dayString(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
