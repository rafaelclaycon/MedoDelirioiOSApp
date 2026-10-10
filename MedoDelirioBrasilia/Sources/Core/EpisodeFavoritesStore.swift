//
//  EpisodeFavoritesStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

@Observable
final class EpisodeFavoritesStore {

    private static let legacyKey = "favoritedEpisodeIDs"

    @ObservationIgnored private let database: LocalDatabaseProtocol

    /// Called after every toggle, so the change can reach the user's other devices.
    @ObservationIgnored var onLocalChange: (() -> Void)?

    private(set) var favoriteIDs: Set<String>

    init(database: LocalDatabaseProtocol = LocalDatabase.shared) {
        self.database = database
        self.favoriteIDs = (try? database.allEpisodeFavoriteIDs()) ?? []
        migrateFromUserDefaultsIfNeeded()
    }

    func isFavorite(_ episodeID: String) -> Bool {
        favoriteIDs.contains(episodeID)
    }

    func toggle(_ episodeID: String) {
        let now = Date()
        if favoriteIDs.contains(episodeID) {
            favoriteIDs.remove(episodeID)
            try? database.deleteEpisodeFavorite(episodeId: episodeID)
            try? database.upsertEpisodeFavoriteTombstone(episodeId: episodeID, unfavoritedAt: now)
        } else {
            favoriteIDs.insert(episodeID)
            try? database.insertEpisodeFavorite(episodeId: episodeID, dateAdded: now)
            try? database.deleteEpisodeFavoriteTombstone(episodeId: episodeID)
        }
        onLocalChange?()
    }

    // MARK: - iCloud Sync

    /// Every favorite and unfavorite this device knows about, as sent to iCloud.
    func syncRecords() -> [String: EpisodeFavoriteRecord] {
        var records = [String: EpisodeFavoriteRecord]()
        for (id, unfavoritedAt) in (try? database.allEpisodeFavoriteTombstones()) ?? [:] {
            records[id] = EpisodeFavoriteRecord(isFavorite: false, updatedAt: unfavoritedAt)
        }
        for (id, dateAdded) in (try? database.allEpisodeFavoriteDates()) ?? [:] {
            let record = EpisodeFavoriteRecord(isFavorite: true, updatedAt: dateAdded)
            if let existing = records[id], existing.isNewer(than: record) { continue }
            records[id] = record
        }
        return records
    }

    /// Takes in a newer record from another device, keeping its timestamp so later
    /// merges compare against when it actually changed. Doesn't call `onLocalChange`.
    func applyRemote(_ record: EpisodeFavoriteRecord, episodeID: String) {
        if record.isFavorite {
            favoriteIDs.insert(episodeID)
            try? database.insertEpisodeFavorite(episodeId: episodeID, dateAdded: record.updatedAt)
            try? database.deleteEpisodeFavoriteTombstone(episodeId: episodeID)
        } else {
            favoriteIDs.remove(episodeID)
            try? database.deleteEpisodeFavorite(episodeId: episodeID)
            try? database.upsertEpisodeFavoriteTombstone(episodeId: episodeID, unfavoritedAt: record.updatedAt)
        }
    }

    func pruneTombstones(olderThan date: Date) {
        try? database.deleteEpisodeFavoriteTombstones(olderThan: date)
    }

    // MARK: - Legacy Migration

    private func migrateFromUserDefaultsIfNeeded() {
        guard let legacy = UserDefaults.standard.stringArray(forKey: Self.legacyKey) else { return }
        for id in legacy {
            try? database.insertEpisodeFavorite(episodeId: id)
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyKey)
        favoriteIDs = (try? database.allEpisodeFavoriteIDs()) ?? favoriteIDs
    }
}
