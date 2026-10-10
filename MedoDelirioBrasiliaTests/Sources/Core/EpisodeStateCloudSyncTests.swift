//
//  EpisodeStateCloudSyncTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

@MainActor
struct EpisodeStateCloudSyncTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private var fakeDatabase: FakeLocalDatabase
    private var cloud: FakeCloudKeyValueStore

    init() {
        fakeDatabase = FakeLocalDatabase()
        cloud = FakeCloudKeyValueStore()
    }

    /// Built after seeding, since the stores load from the database on init.
    private func makeSUT(
        isEnabled: Bool = true
    ) -> (sync: EpisodeStateCloudSync, progress: EpisodeProgressStore, played: EpisodePlayedStore, favorites: EpisodeFavoritesStore) {
        let progress = EpisodeProgressStore(database: fakeDatabase)
        let played = EpisodePlayedStore(database: fakeDatabase)
        let favorites = EpisodeFavoritesStore(database: fakeDatabase)
        let fixedNow = now
        let sync = EpisodeStateCloudSync(
            progressStore: progress,
            playedStore: played,
            favoriteStore: favorites,
            cloudStore: cloud,
            isEnabled: { isEnabled },
            now: { fixedNow }
        )
        return (sync, progress, played, favorites)
    }

    private func progress(_ time: Double, at date: Date, cleared: Bool = false) -> EpisodeProgressRecord {
        cleared ? .cleared(at: date) : EpisodeProgressRecord(currentTime: time, duration: 3600, updatedAt: date, isCleared: false)
    }

    private func putInCloud<Record: Encodable>(_ records: [String: Record], key: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        cloud.values[key] = try encoder.encode(records)
    }

    private func cloudRecords<Record: Decodable>(_ key: String, as type: Record.Type) throws -> [String: Record] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let data = cloud.values[key] else { return [:] }
        return try decoder.decode([String: Record].self, from: data)
    }

    // MARK: - Progress

    @Test
    func sync_withEmptyCloud_shouldPushLocalProgress() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now)
        let sut = makeSUT()

        sut.sync.sync()

        let pushed = try cloudRecords(EpisodeStateCloudSync.progressKey, as: EpisodeProgressRecord.self)
        #expect(pushed["ep-1"]?.currentTime == 30)
    }

    @Test
    func sync_withNewerRemoteProgress_shouldApplyIt() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now.addingTimeInterval(-60))
        try putInCloud(["ep-1": progress(900, at: now)], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(sut.progress.progress(for: "ep-1")?.currentTime == 900)
        #expect(fakeDatabase.episodeProgress["ep-1"]?.updatedAt == now)
    }

    @Test
    func sync_withNewerLocalProgress_shouldKeepAndPushIt() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now)
        try putInCloud(["ep-1": progress(900, at: now.addingTimeInterval(-60))], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(sut.progress.progress(for: "ep-1")?.currentTime == 30)
        let pushed = try cloudRecords(EpisodeStateCloudSync.progressKey, as: EpisodeProgressRecord.self)
        #expect(pushed["ep-1"]?.currentTime == 30)
    }

    @Test
    func sync_withNewerRemoteClearing_shouldRemoveLocalProgress() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now.addingTimeInterval(-60))
        try putInCloud(["ep-1": progress(0, at: now, cleared: true)], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(sut.progress.progress(for: "ep-1") == nil)
        #expect(fakeDatabase.episodeProgressTombstones["ep-1"] == now)
    }

    @Test
    func sync_afterLocalClear_shouldNotBringBackOlderRemoteProgress() throws {
        try fakeDatabase.upsertEpisodeProgressTombstone(episodeId: "ep-1", clearedAt: now)
        try putInCloud(["ep-1": progress(900, at: now.addingTimeInterval(-60))], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(sut.progress.progress(for: "ep-1") == nil)
        let pushed = try cloudRecords(EpisodeStateCloudSync.progressKey, as: EpisodeProgressRecord.self)
        #expect(pushed["ep-1"]?.isCleared == true)
    }

    @Test
    func sync_shouldNotMoveTheActiveEpisode() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now.addingTimeInterval(-60))
        try putInCloud(["ep-1": progress(900, at: now)], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()
        sut.sync.isEpisodeActive = { $0 == "ep-1" }

        sut.sync.sync()

        #expect(sut.progress.progress(for: "ep-1")?.currentTime == 30)
    }

    @Test
    func sync_shouldKeepOtherDevicesEntriesWhenPushing() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now)
        try putInCloud(["ep-2": progress(500, at: now)], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()

        sut.sync.sync()

        let pushed = try cloudRecords(EpisodeStateCloudSync.progressKey, as: EpisodeProgressRecord.self)
        #expect(Set(pushed.keys) == ["ep-1", "ep-2"])
        #expect(sut.progress.progress(for: "ep-2")?.currentTime == 500)
    }

    @Test
    func sync_calledAgainWithNothingNew_shouldNotWrite() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now)
        try fakeDatabase.insertEpisodePlayed(episodeId: "ep-2", dateMarked: now)
        try fakeDatabase.insertEpisodeFavorite(episodeId: "ep-3", dateAdded: now)
        let sut = makeSUT()
        sut.sync.sync()
        let writesAfterFirstSync = cloud.setDataCallCount

        sut.sync.sync()

        #expect(writesAfterFirstSync == 3)
        #expect(cloud.setDataCallCount == writesAfterFirstSync)
    }

    @Test
    func sync_withRemoteWithinTimestampSlack_shouldNotWriteOrApply() throws {
        // SQLite can shave a millisecond off a date, so the copy that came from the
        // cloud reads back slightly older. That must not count as a local change.
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now.addingTimeInterval(-0.001))
        try putInCloud(["ep-1": progress(30, at: now)], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(cloud.setDataCallCount == 0)
        #expect(fakeDatabase.episodeProgress["ep-1"]?.updatedAt == now.addingTimeInterval(-0.001))
    }

    @Test
    func sync_withExpiredRemoteClearing_shouldNotRecreateLocalTombstone() throws {
        let longAgo = now.addingTimeInterval(-EpisodeStateCloudSync.tombstoneLifetime - 60)
        try putInCloud(["ep-1": progress(0, at: longAgo, cleared: true)], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(fakeDatabase.episodeProgressTombstones["ep-1"] == nil)
        #expect(cloud.setDataCallCount == 0)
    }

    @Test
    func sync_shouldPruneExpiredLocalTombstones() throws {
        let longAgo = now.addingTimeInterval(-EpisodeStateCloudSync.tombstoneLifetime - 60)
        try fakeDatabase.upsertEpisodeProgressTombstone(episodeId: "ep-1", clearedAt: longAgo)
        try fakeDatabase.upsertEpisodePlayedTombstone(episodeId: "ep-2", unmarkedAt: longAgo)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(fakeDatabase.episodeProgressTombstones.isEmpty)
        #expect(fakeDatabase.episodePlayedTombstones.isEmpty)
    }

    // MARK: - Played

    @Test
    func sync_withRemoteMark_shouldMarkEpisodePlayed() throws {
        try putInCloud(["ep-1": EpisodePlayedRecord(isPlayed: true, updatedAt: now)], key: EpisodeStateCloudSync.playedKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(sut.played.isPlayed("ep-1"))
    }

    @Test
    func sync_withNewerRemoteUnmark_shouldBeatOlderLocalMark() throws {
        try fakeDatabase.insertEpisodePlayed(episodeId: "ep-1", dateMarked: now.addingTimeInterval(-60))
        try putInCloud(["ep-1": EpisodePlayedRecord(isPlayed: false, updatedAt: now)], key: EpisodeStateCloudSync.playedKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(!sut.played.isPlayed("ep-1"))
    }

    @Test
    func sync_afterLocalUnmark_shouldNotBringBackOlderRemoteMark() throws {
        try fakeDatabase.upsertEpisodePlayedTombstone(episodeId: "ep-1", unmarkedAt: now)
        try putInCloud(["ep-1": EpisodePlayedRecord(isPlayed: true, updatedAt: now.addingTimeInterval(-60))], key: EpisodeStateCloudSync.playedKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(!sut.played.isPlayed("ep-1"))
        let pushed = try cloudRecords(EpisodeStateCloudSync.playedKey, as: EpisodePlayedRecord.self)
        #expect(pushed["ep-1"]?.isPlayed == false)
    }

    // MARK: - Favorites

    @Test
    func sync_withEmptyCloud_shouldPushLocalFavorites() throws {
        try fakeDatabase.insertEpisodeFavorite(episodeId: "ep-1", dateAdded: now)
        let sut = makeSUT()

        sut.sync.sync()

        let pushed = try cloudRecords(EpisodeStateCloudSync.favoriteKey, as: EpisodeFavoriteRecord.self)
        #expect(pushed["ep-1"]?.isFavorite == true)
    }

    @Test
    func sync_withRemoteFavorite_shouldFavoriteTheEpisode() throws {
        try putInCloud(["ep-1": EpisodeFavoriteRecord(isFavorite: true, updatedAt: now)], key: EpisodeStateCloudSync.favoriteKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(sut.favorites.isFavorite("ep-1"))
        #expect(fakeDatabase.episodeFavorites["ep-1"] == now)
    }

    @Test
    func sync_afterLocalUnfavorite_shouldNotBringBackOlderRemoteFavorite() throws {
        try fakeDatabase.upsertEpisodeFavoriteTombstone(episodeId: "ep-1", unfavoritedAt: now)
        try putInCloud(["ep-1": EpisodeFavoriteRecord(isFavorite: true, updatedAt: now.addingTimeInterval(-60))], key: EpisodeStateCloudSync.favoriteKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(!sut.favorites.isFavorite("ep-1"))
        let pushed = try cloudRecords(EpisodeStateCloudSync.favoriteKey, as: EpisodeFavoriteRecord.self)
        #expect(pushed["ep-1"]?.isFavorite == false)
    }

    @Test
    func sync_withNewerRemoteUnfavorite_shouldBeatOlderLocalFavorite() throws {
        try fakeDatabase.insertEpisodeFavorite(episodeId: "ep-1", dateAdded: now.addingTimeInterval(-60))
        try putInCloud(["ep-1": EpisodeFavoriteRecord(isFavorite: false, updatedAt: now)], key: EpisodeStateCloudSync.favoriteKey)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(!sut.favorites.isFavorite("ep-1"))
        #expect(fakeDatabase.episodeFavoriteTombstones["ep-1"] == now)
    }

    @Test
    func sync_shouldPruneExpiredLocalFavoriteTombstones() throws {
        let longAgo = now.addingTimeInterval(-EpisodeStateCloudSync.tombstoneLifetime - 60)
        try fakeDatabase.upsertEpisodeFavoriteTombstone(episodeId: "ep-1", unfavoritedAt: longAgo)
        let sut = makeSUT()

        sut.sync.sync()

        #expect(fakeDatabase.episodeFavoriteTombstones.isEmpty)
    }

    // MARK: - Setting and bad data

    @Test
    func sync_whenDisabled_shouldNeitherReadNorWrite() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now)
        try putInCloud(["ep-2": progress(500, at: now)], key: EpisodeStateCloudSync.progressKey)
        let sut = makeSUT(isEnabled: false)

        sut.sync.sync()

        #expect(cloud.setDataCallCount == 0)
        #expect(sut.progress.progress(for: "ep-2") == nil)
    }

    @Test
    func sync_withUnreadableCloudData_shouldReplaceItWithLocalState() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 3600, updatedAt: now)
        cloud.values[EpisodeStateCloudSync.progressKey] = Data("not json".utf8)
        let sut = makeSUT()

        sut.sync.sync()

        let pushed = try cloudRecords(EpisodeStateCloudSync.progressKey, as: EpisodeProgressRecord.self)
        #expect(pushed["ep-1"]?.currentTime == 30)
    }

    // MARK: - Pruning

    @Test
    func pruneProgress_shouldKeepTheMostRecentPositionsUpToTheCap() {
        var records = [String: EpisodeProgressRecord]()
        for index in 0..<(EpisodeStateCloudSync.maxLiveProgressRecords + 5) {
            records["ep-\(index)"] = progress(10, at: now.addingTimeInterval(TimeInterval(-index)))
        }

        let pruned = EpisodeStateCloudSync.pruneProgress(records, now: now)

        #expect(pruned.count == EpisodeStateCloudSync.maxLiveProgressRecords)
        #expect(pruned["ep-0"] != nil)
        #expect(pruned["ep-\(EpisodeStateCloudSync.maxLiveProgressRecords)"] == nil)
    }

    @Test
    func pruneProgress_shouldDropClearingsPastTheirLifetimeAndGrace() {
        let expired = now.addingTimeInterval(-EpisodeStateCloudSync.tombstoneLifetime - EpisodeStateCloudSync.cloudTombstoneGrace - 1)
        let withinGrace = now.addingTimeInterval(-EpisodeStateCloudSync.tombstoneLifetime - 1)
        let records = [
            "expired": progress(0, at: expired, cleared: true),
            "withinGrace": progress(0, at: withinGrace, cleared: true)
        ]

        let pruned = EpisodeStateCloudSync.pruneProgress(records, now: now)

        #expect(pruned["expired"] == nil)
        #expect(pruned["withinGrace"] != nil)
    }

    @Test
    func pruneMarks_shouldKeepOldMarksButDropExpiredUnmarks() {
        let expired = now.addingTimeInterval(-EpisodeStateCloudSync.tombstoneLifetime - EpisodeStateCloudSync.cloudTombstoneGrace - 1)
        let records = [
            "oldMark": EpisodePlayedRecord(isPlayed: true, updatedAt: expired),
            "oldUnmark": EpisodePlayedRecord(isPlayed: false, updatedAt: expired)
        ]

        let pruned = EpisodeStateCloudSync.pruneMarks(records, now: now)

        #expect(pruned["oldMark"] != nil)
        #expect(pruned["oldUnmark"] == nil)
    }
}
