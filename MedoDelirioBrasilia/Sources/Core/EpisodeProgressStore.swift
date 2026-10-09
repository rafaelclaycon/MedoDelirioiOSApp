//
//  EpisodeProgressStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/02/26.
//

import Foundation

@Observable
final class EpisodeProgressStore {

    struct EpisodeProgress: Codable {
        var currentTime: TimeInterval
        var duration: TimeInterval
    }

    private static let legacyKey = "episodePlaybackProgress"

    @ObservationIgnored private let database: LocalDatabaseProtocol
    /// Episodes whose progress was cleared, so `save` only touches the tombstone table
    /// when there's something to remove.
    @ObservationIgnored private var clearedIDs: Set<String>

    /// Called after a clear, so it can reach the user's other devices right away.
    /// Saves don't call it: they happen every few seconds during playback.
    @ObservationIgnored var onLocalChange: (() -> Void)?

    private(set) var entries: [String: EpisodeProgress]

    init(database: LocalDatabaseProtocol = LocalDatabase.shared) {
        self.database = database

        let dbEntries = (try? database.allEpisodeProgress()) ?? [:]
        var converted = [String: EpisodeProgress]()
        for (id, value) in dbEntries {
            converted[id] = EpisodeProgress(currentTime: value.currentTime, duration: value.duration)
        }
        self.entries = converted
        self.clearedIDs = Set(((try? database.allEpisodeProgressTombstones()) ?? [:]).keys)

        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - Public API

    func progress(for episodeID: String) -> EpisodeProgress? {
        entries[episodeID]
    }

    func save(episodeID: String, currentTime: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else { return }
        entries[episodeID] = EpisodeProgress(currentTime: currentTime, duration: duration)
        try? database.upsertEpisodeProgress(episodeId: episodeID, currentTime: currentTime, duration: duration)
        removeTombstone(for: episodeID)
    }

    func clear(episodeID: String) {
        entries.removeValue(forKey: episodeID)
        try? database.deleteEpisodeProgress(episodeId: episodeID)
        try? database.upsertEpisodeProgressTombstone(episodeId: episodeID, clearedAt: Date())
        clearedIDs.insert(episodeID)
        onLocalChange?()
    }

    func fractionCompleted(for episodeID: String) -> Double? {
        guard let entry = entries[episodeID], entry.duration > 0 else { return nil }
        return min(entry.currentTime / entry.duration, 1.0)
    }

    func timeRemaining(for episodeID: String) -> TimeInterval? {
        guard let entry = entries[episodeID] else { return nil }
        return max(entry.duration - entry.currentTime, 0)
    }

    /// Formats the remaining time as a human-readable string (e.g. "45 min left", "1 hr 12 min left").
    func formattedTimeRemaining(for episodeID: String) -> String? {
        guard let remaining = timeRemaining(for: episodeID), remaining > 0 else { return nil }
        let totalMinutes = Int(remaining) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours) hr \(minutes) min restantes"
        } else if hours > 0 {
            return "\(hours) hr restantes"
        } else if minutes > 0 {
            return "\(minutes) min restantes"
        } else {
            return "< 1 min restante"
        }
    }

    // MARK: - iCloud Sync

    /// Every position and clearing this device knows about, as sent to iCloud.
    func syncRecords() -> [String: EpisodeProgressRecord] {
        var records = [String: EpisodeProgressRecord]()
        for (id, clearedAt) in (try? database.allEpisodeProgressTombstones()) ?? [:] {
            records[id] = .cleared(at: clearedAt)
        }
        for (id, value) in (try? database.allEpisodeProgress()) ?? [:] {
            let record = EpisodeProgressRecord(
                currentTime: value.currentTime,
                duration: value.duration,
                updatedAt: value.updatedAt,
                isCleared: false
            )
            if let existing = records[id], existing.isNewer(than: record) { continue }
            records[id] = record
        }
        return records
    }

    /// Takes in a newer record from another device, keeping its timestamp so later
    /// merges compare against when it actually changed. Doesn't call `onLocalChange`.
    func applyRemote(_ record: EpisodeProgressRecord, episodeID: String) {
        if record.isCleared {
            entries.removeValue(forKey: episodeID)
            try? database.deleteEpisodeProgress(episodeId: episodeID)
            try? database.upsertEpisodeProgressTombstone(episodeId: episodeID, clearedAt: record.updatedAt)
            clearedIDs.insert(episodeID)
        } else {
            entries[episodeID] = EpisodeProgress(currentTime: record.currentTime, duration: record.duration)
            try? database.upsertEpisodeProgress(
                episodeId: episodeID,
                currentTime: record.currentTime,
                duration: record.duration,
                updatedAt: record.updatedAt
            )
            removeTombstone(for: episodeID)
        }
    }

    func pruneTombstones(olderThan date: Date) {
        try? database.deleteEpisodeProgressTombstones(olderThan: date)
        clearedIDs = Set(((try? database.allEpisodeProgressTombstones()) ?? [:]).keys)
    }

    private func removeTombstone(for episodeID: String) {
        guard clearedIDs.contains(episodeID) else { return }
        try? database.deleteEpisodeProgressTombstone(episodeId: episodeID)
        clearedIDs.remove(episodeID)
    }

    // MARK: - Legacy Migration

    private func migrateFromUserDefaultsIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: Self.legacyKey),
              let decoded = try? JSONDecoder().decode([String: EpisodeProgress].self, from: data) else {
            return
        }
        for (id, progress) in decoded {
            try? database.upsertEpisodeProgress(
                episodeId: id,
                currentTime: progress.currentTime,
                duration: progress.duration
            )
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyKey)

        let dbEntries = (try? database.allEpisodeProgress()) ?? [:]
        var converted = [String: EpisodeProgress]()
        for (id, value) in dbEntries {
            converted[id] = EpisodeProgress(currentTime: value.currentTime, duration: value.duration)
        }
        entries = converted
    }
}
