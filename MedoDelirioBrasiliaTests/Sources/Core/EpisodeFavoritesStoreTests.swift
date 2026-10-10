//
//  EpisodeFavoritesStoreTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 10/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct EpisodeFavoritesStoreTests {

    private var sut: EpisodeFavoritesStore
    private var fakeDatabase: FakeLocalDatabase

    init() {
        fakeDatabase = FakeLocalDatabase()
        sut = EpisodeFavoritesStore(database: fakeDatabase)
    }

    // MARK: - toggle

    @Test
    func toggle_shouldFavoriteAndNotify() {
        var changeCount = 0
        sut.onLocalChange = { changeCount += 1 }

        sut.toggle("ep-1")

        #expect(sut.isFavorite("ep-1"))
        #expect(fakeDatabase.episodeFavorites["ep-1"] != nil)
        #expect(changeCount == 1)
    }

    @Test
    func toggle_twice_shouldUnfavoriteAndLeaveTombstone() {
        sut.toggle("ep-1")

        sut.toggle("ep-1")

        #expect(!sut.isFavorite("ep-1"))
        #expect(fakeDatabase.episodeFavorites["ep-1"] == nil)
        #expect(fakeDatabase.episodeFavoriteTombstones["ep-1"] != nil)
    }

    @Test
    func toggle_thrice_shouldRemoveTombstone() {
        sut.toggle("ep-1")
        sut.toggle("ep-1")

        sut.toggle("ep-1")

        #expect(sut.isFavorite("ep-1"))
        #expect(fakeDatabase.episodeFavoriteTombstones["ep-1"] == nil)
    }

    // MARK: - iCloud sync

    @Test
    func syncRecords_shouldIncludeFavoritesAndUnfavorites() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        try fakeDatabase.insertEpisodeFavorite(episodeId: "ep-1", dateAdded: date)
        try fakeDatabase.upsertEpisodeFavoriteTombstone(episodeId: "ep-2", unfavoritedAt: date)

        let records = sut.syncRecords()

        #expect(records["ep-1"] == EpisodeFavoriteRecord(isFavorite: true, updatedAt: date))
        #expect(records["ep-2"] == EpisodeFavoriteRecord(isFavorite: false, updatedAt: date))
    }

    @Test
    func applyRemote_shouldUpdateStateWithoutNotifying() {
        var changeCount = 0
        sut.onLocalChange = { changeCount += 1 }
        let date = Date(timeIntervalSince1970: 1_790_000_000)

        sut.applyRemote(EpisodeFavoriteRecord(isFavorite: true, updatedAt: date), episodeID: "ep-1")

        #expect(sut.isFavorite("ep-1"))
        #expect(fakeDatabase.episodeFavorites["ep-1"] == date)
        #expect(changeCount == 0)
    }

    @Test
    func applyRemote_withUnfavorite_shouldRemoveFavoriteAndLeaveTombstone() {
        sut.toggle("ep-1")
        let date = Date(timeIntervalSince1970: 1_790_000_000)

        sut.applyRemote(EpisodeFavoriteRecord(isFavorite: false, updatedAt: date), episodeID: "ep-1")

        #expect(!sut.isFavorite("ep-1"))
        #expect(fakeDatabase.episodeFavoriteTombstones["ep-1"] == date)
    }
}
