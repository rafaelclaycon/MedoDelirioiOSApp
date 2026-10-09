//
//  EpisodeStateCloudSync.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Foundation
import os

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "EpisodeStateCloudSync")

/// Keeps episode progress and played state in step across the user's devices through
/// iCloud key-value storage.
///
/// Each kind of state lives under one key as a `[episodeId: record]` dictionary. A sync
/// reads the cloud copy, merges it with everything this device knows (newer record
/// wins per episode), applies what the other devices changed, and writes the merged
/// result back only if it differs. Pushing the full merged state, rather than just the
/// latest change, means an entry lost to two devices writing at once comes back with
/// the next push from either.
///
/// The store syncs on its own schedule, usually within seconds to minutes. That's
/// enough for picking up on the iPad where the iPhone left off.
@MainActor
final class EpisodeStateCloudSync {

    nonisolated static let progressKey = "episodeProgress.v1"
    nonisolated static let playedKey = "episodePlayed.v1"

    /// Keeps the progress payload well under the store's 1 MB limit. Positions beyond
    /// this stay on the device that has them; they just stop syncing.
    nonisolated static let maxLiveProgressRecords = 300
    /// How long a clearing or unmarking is remembered. A device that comes back after
    /// longer than this can bring an old position back, which is an acceptable miss.
    nonisolated static let tombstoneLifetime: TimeInterval = 60 * 24 * 60 * 60
    /// The cloud keeps tombstones a day past their local lifetime. Without the margin,
    /// a device whose clock runs behind would keep pushing back one that another device
    /// had just dropped.
    nonisolated static let cloudTombstoneGrace: TimeInterval = 24 * 60 * 60

    private let progressStore: EpisodeProgressStore
    private let playedStore: EpisodePlayedStore
    private let cloudStore: CloudKeyValueStore
    private let isEnabled: () -> Bool
    private let now: () -> Date

    /// The episode loaded in the player keeps its own position: a remote update never
    /// moves it. Its next save is newer anyway and wins on the other devices.
    var isEpisodeActive: (String) -> Bool = { _ in false }

    private var externalChangeObserver: NSObjectProtocol?
    private var isSyncScheduled = false

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    init(
        progressStore: EpisodeProgressStore,
        playedStore: EpisodePlayedStore,
        cloudStore: CloudKeyValueStore = NSUbiquitousKeyValueStore.default,
        isEnabled: @escaping () -> Bool = { UserSettings().getEnableICloudEpisodeSync() },
        now: @escaping () -> Date = Date.init
    ) {
        self.progressStore = progressStore
        self.playedStore = playedStore
        self.cloudStore = cloudStore
        self.isEnabled = isEnabled
        self.now = now
    }

    // MARK: - Lifecycle

    /// Starts listening for changes from other devices and runs a first sync.
    func start() {
        guard externalChangeObserver == nil else { return }

        // The stores aren't main-actor types, but every caller that changes them is on
        // the main thread (views and the player).
        progressStore.onLocalChange = { [weak self] in
            MainActor.assumeIsolated { self?.requestSync() }
        }
        playedStore.onLocalChange = { [weak self] in
            MainActor.assumeIsolated { self?.requestSync() }
        }

        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            MainActor.assumeIsolated {
                self?.handleExternalChange(reason: reason)
            }
        }

        cloudStore.synchronize()
        sync()
    }

    /// Syncs once the current burst of changes is done, so finishing an episode (which
    /// clears progress and marks it played) pushes once instead of twice.
    func requestSync() {
        guard !isSyncScheduled else { return }
        isSyncScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSyncScheduled = false
            self.sync()
        }
    }

    func handleExternalChange(reason: Int?) {
        switch reason {
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            logger.error("iCloud key-value quota exceeded; episode state may stop syncing.")
        case NSUbiquitousKeyValueStoreAccountChange:
            logger.info("iCloud account changed; merging local episode state into the new account.")
        default:
            break
        }
        sync()
    }

    // MARK: - Sync

    func sync() {
        guard isEnabled() else { return }
        let date = now()
        syncProgress(now: date)
        syncPlayed(now: date)
    }

    private func syncProgress(now date: Date) {
        let remote: [String: EpisodeProgressRecord] = read(Self.progressKey)
        let result = Self.merge(local: progressStore.syncRecords(), remote: remote)
        let horizon = date.addingTimeInterval(-Self.tombstoneLifetime)

        for (id, record) in result.toApply where !isEpisodeActive(id) {
            // Already past its lifetime here; applying it would just recreate a
            // tombstone that the pruning below deletes again.
            if record.isCleared && record.updatedAt < horizon { continue }
            progressStore.applyRemote(record, episodeID: id)
        }
        progressStore.pruneTombstones(olderThan: horizon)

        let pruned = Self.pruneProgress(result.merged, now: date)
        if pruned != remote {
            write(pruned, forKey: Self.progressKey)
        }
    }

    private func syncPlayed(now date: Date) {
        let remote: [String: EpisodePlayedRecord] = read(Self.playedKey)
        let result = Self.merge(local: playedStore.syncRecords(), remote: remote)
        let horizon = date.addingTimeInterval(-Self.tombstoneLifetime)

        for (id, record) in result.toApply {
            if !record.isPlayed && record.updatedAt < horizon { continue }
            playedStore.applyRemote(record, episodeID: id)
        }
        playedStore.pruneTombstones(olderThan: horizon)

        let pruned = Self.prunePlayed(result.merged, now: date)
        if pruned != remote {
            write(pruned, forKey: Self.playedKey)
        }
    }

    // MARK: - Merge

    struct MergeResult<Record: EpisodeSyncRecord> {
        /// What the cloud should hold: the newer copy of every episode on either side.
        var merged: [String: Record]
        /// Remote records newer than (or missing from) this device's copy.
        var toApply: [String: Record]
    }

    /// Picks the newer record per episode. When both copies are within the timestamp
    /// slack, the cloud's copy stays, so a sync that changed nothing writes nothing.
    nonisolated static func merge<Record: EpisodeSyncRecord>(
        local: [String: Record],
        remote: [String: Record]
    ) -> MergeResult<Record> {
        var merged = remote
        var toApply = [String: Record]()

        for (id, localRecord) in local {
            guard let remoteRecord = remote[id] else {
                merged[id] = localRecord
                continue
            }
            if localRecord.isNewer(than: remoteRecord) {
                merged[id] = localRecord
            } else if remoteRecord.isNewer(than: localRecord) {
                toApply[id] = remoteRecord
            }
        }
        for (id, remoteRecord) in remote where local[id] == nil {
            toApply[id] = remoteRecord
        }

        return MergeResult(merged: merged, toApply: toApply)
    }

    // MARK: - Pruning

    /// Keeps the most recent positions up to the cap, and clearings until they expire.
    /// Ties sort by ID so every device prunes to the same result.
    nonisolated static func pruneProgress(
        _ records: [String: EpisodeProgressRecord],
        now date: Date
    ) -> [String: EpisodeProgressRecord] {
        let expiry = date.addingTimeInterval(-(tombstoneLifetime + cloudTombstoneGrace))

        let live = records
            .filter { !$0.value.isCleared }
            .sorted { lhs, rhs in
                lhs.value.updatedAt != rhs.value.updatedAt
                    ? lhs.value.updatedAt > rhs.value.updatedAt
                    : lhs.key < rhs.key
            }
            .prefix(maxLiveProgressRecords)
        let cleared = records.filter { $0.value.isCleared && $0.value.updatedAt >= expiry }

        var pruned = cleared
        for (id, record) in live {
            pruned[id] = record
        }
        return pruned
    }

    /// Keeps every played mark (a few hundred episodes is only tens of KB) and
    /// unmarkings until they expire.
    nonisolated static func prunePlayed(
        _ records: [String: EpisodePlayedRecord],
        now date: Date
    ) -> [String: EpisodePlayedRecord] {
        let expiry = date.addingTimeInterval(-(tombstoneLifetime + cloudTombstoneGrace))
        return records.filter { $0.value.isPlayed || $0.value.updatedAt >= expiry }
    }

    // MARK: - Encoding

    /// Missing or unreadable data reads as empty, so the next write replaces it with
    /// this device's state instead of failing forever.
    private func read<Record: EpisodeSyncRecord>(_ key: String) -> [String: Record] {
        guard let data = cloudStore.data(forKey: key) else { return [:] }
        do {
            return try Self.decoder.decode([String: Record].self, from: data)
        } catch {
            logger.error("Couldn't decode \(key, privacy: .public) from iCloud: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func write<Record: EpisodeSyncRecord>(_ records: [String: Record], forKey key: String) {
        do {
            let data = try Self.encoder.encode(records)
            cloudStore.setData(data, forKey: key)
            logger.debug("Pushed \(records.count) records (\(data.count) bytes) to \(key, privacy: .public).")
        } catch {
            logger.error("Couldn't encode \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
