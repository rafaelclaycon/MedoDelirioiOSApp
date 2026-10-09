//
//  EpisodePlayedStoreTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct EpisodePlayedStoreTests {

    private var sut: EpisodePlayedStore
    private var fakeDatabase: FakeLocalDatabase

    init() {
        fakeDatabase = FakeLocalDatabase()
        sut = EpisodePlayedStore(database: fakeDatabase)
    }

    // MARK: - toggle

    @Test
    func toggle_shouldMarkAsPlayedAndNotify() {
        var changeCount = 0
        sut.onLocalChange = { changeCount += 1 }

        sut.toggle("ep-1")

        #expect(sut.isPlayed("ep-1"))
        #expect(fakeDatabase.episodePlayed["ep-1"] != nil)
        #expect(changeCount == 1)
    }

    @Test
    func toggle_twice_shouldUnmarkAndLeaveTombstone() {
        sut.toggle("ep-1")

        sut.toggle("ep-1")

        #expect(!sut.isPlayed("ep-1"))
        #expect(fakeDatabase.episodePlayed["ep-1"] == nil)
        #expect(fakeDatabase.episodePlayedTombstones["ep-1"] != nil)
    }

    @Test
    func toggle_thrice_shouldRemoveTombstone() {
        sut.toggle("ep-1")
        sut.toggle("ep-1")

        sut.toggle("ep-1")

        #expect(sut.isPlayed("ep-1"))
        #expect(fakeDatabase.episodePlayedTombstones["ep-1"] == nil)
    }

    // MARK: - iCloud sync

    @Test
    func syncRecords_shouldIncludeMarksAndUnmarks() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        try fakeDatabase.insertEpisodePlayed(episodeId: "ep-1", dateMarked: date)
        try fakeDatabase.upsertEpisodePlayedTombstone(episodeId: "ep-2", unmarkedAt: date)

        let records = sut.syncRecords()

        #expect(records["ep-1"] == EpisodePlayedRecord(isPlayed: true, updatedAt: date))
        #expect(records["ep-2"] == EpisodePlayedRecord(isPlayed: false, updatedAt: date))
    }

    @Test
    func applyRemote_shouldUpdateStateWithoutNotifying() {
        var changeCount = 0
        sut.onLocalChange = { changeCount += 1 }
        let date = Date(timeIntervalSince1970: 1_790_000_000)

        sut.applyRemote(EpisodePlayedRecord(isPlayed: true, updatedAt: date), episodeID: "ep-1")

        #expect(sut.isPlayed("ep-1"))
        #expect(fakeDatabase.episodePlayed["ep-1"] == date)
        #expect(changeCount == 0)
    }

    @Test
    func applyRemote_withUnmark_shouldRemoveMarkAndLeaveTombstone() {
        sut.toggle("ep-1")
        let date = Date(timeIntervalSince1970: 1_790_000_000)

        sut.applyRemote(EpisodePlayedRecord(isPlayed: false, updatedAt: date), episodeID: "ep-1")

        #expect(!sut.isPlayed("ep-1"))
        #expect(fakeDatabase.episodePlayedTombstones["ep-1"] == date)
    }
}
