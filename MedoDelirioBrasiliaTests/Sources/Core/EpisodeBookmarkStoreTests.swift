//
//  EpisodeBookmarkStoreTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 17/06/26.
//

import Testing
import Foundation
@testable import MedoDelirio

@MainActor
struct EpisodeBookmarkStoreTests {

    private var sut: EpisodeBookmarkStore
    private var fakeDatabase: FakeLocalDatabase

    init() {
        fakeDatabase = FakeLocalDatabase()
        sut = EpisodeBookmarkStore(database: fakeDatabase)
    }

    // MARK: - addBookmark

    @Test
    func addBookmark_shouldPersistToDatabase() {
        sut.addBookmark(episodeId: "ep-1", timestamp: 120)

        #expect(fakeDatabase.bookmarks.count == 1)
        #expect(fakeDatabase.bookmarks[0].episodeId == "ep-1")
        #expect(fakeDatabase.bookmarks[0].timestamp == 120)
    }

    @Test
    func addBookmark_shouldReturnCreatedBookmark() {
        let bookmark = sut.addBookmark(episodeId: "ep-1", timestamp: 120)

        #expect(bookmark.episodeId == "ep-1")
        #expect(bookmark.timestamp == 120)
    }

    @Test
    func addBookmark_shouldUpdateInMemoryCache() {
        sut.addBookmark(episodeId: "ep-1", timestamp: 120)

        #expect(sut.bookmarksByEpisode["ep-1"]?.count == 1)
    }

    @Test
    func addBookmark_shouldKeepBookmarksSortedByTimestamp() {
        sut.addBookmark(episodeId: "ep-1", timestamp: 300)
        sut.addBookmark(episodeId: "ep-1", timestamp: 100)
        sut.addBookmark(episodeId: "ep-1", timestamp: 200)

        let timestamps = sut.bookmarks(for: "ep-1").map(\.timestamp)
        #expect(timestamps == [100, 200, 300])
    }

    // MARK: - bookmarks(for:)

    @Test
    func bookmarks_whenNotCached_shouldLoadFromDatabase() throws {
        try fakeDatabase.insertBookmark(EpisodeBookmark(episodeId: "ep-1", timestamp: 50))

        let result = sut.bookmarks(for: "ep-1")

        #expect(result.count == 1)
        #expect(result[0].timestamp == 50)
    }

    @Test
    func bookmarks_shouldCacheAfterFirstLoad() throws {
        try fakeDatabase.insertBookmark(EpisodeBookmark(episodeId: "ep-1", timestamp: 50))

        _ = sut.bookmarks(for: "ep-1")
        #expect(sut.bookmarksByEpisode["ep-1"]?.count == 1)
    }

    @Test
    func bookmarks_forEpisodeWithNone_shouldReturnEmpty() {
        #expect(sut.bookmarks(for: "ep-1").isEmpty)
    }

    // MARK: - episodeIdsWithBookmarks

    @Test
    func episodeIdsWithBookmarks_shouldReturnDistinctEpisodeIDs() throws {
        try fakeDatabase.insertBookmark(EpisodeBookmark(episodeId: "ep-1", timestamp: 50))
        try fakeDatabase.insertBookmark(EpisodeBookmark(episodeId: "ep-1", timestamp: 60))
        try fakeDatabase.insertBookmark(EpisodeBookmark(episodeId: "ep-2", timestamp: 70))

        #expect(sut.episodeIdsWithBookmarks() == ["ep-1", "ep-2"])
    }

    // MARK: - update

    @Test
    func update_shouldPersistChangesToDatabaseAndCache() {
        var bookmark = sut.addBookmark(episodeId: "ep-1", timestamp: 120)
        bookmark.title = "Highlight"

        sut.update(bookmark)

        #expect(fakeDatabase.bookmarks[0].title == "Highlight")
        #expect(sut.bookmarks(for: "ep-1")[0].title == "Highlight")
    }

    // MARK: - delete

    @Test
    func delete_shouldRemoveFromDatabaseAndCache() {
        let bookmark = sut.addBookmark(episodeId: "ep-1", timestamp: 120)

        sut.delete(id: bookmark.id, episodeId: "ep-1")

        #expect(fakeDatabase.bookmarks.isEmpty)
        #expect(sut.bookmarks(for: "ep-1").isEmpty)
    }

    @Test
    func delete_shouldOnlyRemoveTargetedBookmark() {
        let first = sut.addBookmark(episodeId: "ep-1", timestamp: 100)
        sut.addBookmark(episodeId: "ep-1", timestamp: 200)

        sut.delete(id: first.id, episodeId: "ep-1")

        let remaining = sut.bookmarks(for: "ep-1")
        #expect(remaining.count == 1)
        #expect(remaining[0].timestamp == 200)
    }

    // MARK: - allBookmarkDates

    @Test
    func allBookmarkDates_shouldReturnCreationDates() throws {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        try fakeDatabase.insertBookmark(EpisodeBookmark(episodeId: "ep-1", timestamp: 50, createdAt: date1))
        try fakeDatabase.insertBookmark(EpisodeBookmark(episodeId: "ep-2", timestamp: 60, createdAt: date2))

        let dates = sut.allBookmarkDates()

        #expect(dates.count == 2)
        #expect(dates.contains(date1))
        #expect(dates.contains(date2))
    }
}
