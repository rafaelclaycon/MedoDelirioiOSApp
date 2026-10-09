//
//  EpisodePlayedStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/02/26.
//

import Foundation

@Observable
final class EpisodePlayedStore {

    private static let legacyKey = "playedEpisodeIDs"

    @ObservationIgnored private let database: LocalDatabaseProtocol

    /// Called after every toggle, so the change can reach the user's other devices.
    @ObservationIgnored var onLocalChange: (() -> Void)?

    private(set) var playedIDs: Set<String>

    init(database: LocalDatabaseProtocol = LocalDatabase.shared) {
        self.database = database
        self.playedIDs = (try? database.allEpisodePlayedIDs()) ?? []
        migrateFromUserDefaultsIfNeeded()
    }

    func isPlayed(_ episodeID: String) -> Bool {
        playedIDs.contains(episodeID)
    }

    func toggle(_ episodeID: String) {
        let now = Date()
        if playedIDs.contains(episodeID) {
            playedIDs.remove(episodeID)
            try? database.deleteEpisodePlayed(episodeId: episodeID)
            try? database.upsertEpisodePlayedTombstone(episodeId: episodeID, unmarkedAt: now)
        } else {
            playedIDs.insert(episodeID)
            try? database.insertEpisodePlayed(episodeId: episodeID, dateMarked: now)
            try? database.deleteEpisodePlayedTombstone(episodeId: episodeID)
        }
        onLocalChange?()
    }

    // MARK: - iCloud Sync

    /// Every mark and unmark this device knows about, as sent to iCloud.
    func syncRecords() -> [String: EpisodePlayedRecord] {
        var records = [String: EpisodePlayedRecord]()
        for (id, unmarkedAt) in (try? database.allEpisodePlayedTombstones()) ?? [:] {
            records[id] = EpisodePlayedRecord(isPlayed: false, updatedAt: unmarkedAt)
        }
        for (id, dateMarked) in (try? database.allEpisodePlayedDates()) ?? [:] {
            let record = EpisodePlayedRecord(isPlayed: true, updatedAt: dateMarked)
            if let existing = records[id], existing.isNewer(than: record) { continue }
            records[id] = record
        }
        return records
    }

    /// Takes in a newer record from another device, keeping its timestamp so later
    /// merges compare against when it actually changed. Doesn't call `onLocalChange`.
    func applyRemote(_ record: EpisodePlayedRecord, episodeID: String) {
        if record.isPlayed {
            playedIDs.insert(episodeID)
            try? database.insertEpisodePlayed(episodeId: episodeID, dateMarked: record.updatedAt)
            try? database.deleteEpisodePlayedTombstone(episodeId: episodeID)
        } else {
            playedIDs.remove(episodeID)
            try? database.deleteEpisodePlayed(episodeId: episodeID)
            try? database.upsertEpisodePlayedTombstone(episodeId: episodeID, unmarkedAt: record.updatedAt)
        }
    }

    func pruneTombstones(olderThan date: Date) {
        try? database.deleteEpisodePlayedTombstones(olderThan: date)
    }

    // MARK: - Legacy Migration

    private func migrateFromUserDefaultsIfNeeded() {
        guard let legacy = UserDefaults.standard.stringArray(forKey: Self.legacyKey) else { return }
        for id in legacy {
            try? database.insertEpisodePlayed(episodeId: id)
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyKey)
        playedIDs = (try? database.allEpisodePlayedIDs()) ?? playedIDs
    }
}
