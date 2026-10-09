//
//  EpisodeProgressStoreTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 17/06/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct EpisodeProgressStoreTests {

    private var sut: EpisodeProgressStore
    private var fakeDatabase: FakeLocalDatabase

    init() {
        fakeDatabase = FakeLocalDatabase()
        sut = EpisodeProgressStore(database: fakeDatabase)
    }

    // MARK: - save

    @Test
    func save_shouldStoreProgressInMemoryAndDatabase() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)

        #expect(sut.progress(for: "ep-1")?.currentTime == 30)
        #expect(sut.progress(for: "ep-1")?.duration == 120)
        #expect(fakeDatabase.episodeProgress["ep-1"]?.currentTime == 30)
    }

    @Test
    func save_whenDurationIsZero_shouldNotPersist() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 0)

        #expect(sut.progress(for: "ep-1") == nil)
        #expect(fakeDatabase.episodeProgress.isEmpty)
    }

    @Test
    func save_calledTwice_shouldOverwritePreviousProgress() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)
        sut.save(episodeID: "ep-1", currentTime: 90, duration: 120)

        #expect(sut.progress(for: "ep-1")?.currentTime == 90)
    }

    // MARK: - init / loading

    @Test
    func init_shouldLoadExistingProgressFromDatabase() throws {
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 45, duration: 100)

        let store = EpisodeProgressStore(database: fakeDatabase)

        #expect(store.progress(for: "ep-1")?.currentTime == 45)
    }

    // MARK: - clear

    @Test
    func clear_shouldRemoveProgressFromMemoryAndDatabase() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)

        sut.clear(episodeID: "ep-1")

        #expect(sut.progress(for: "ep-1") == nil)
        #expect(fakeDatabase.episodeProgress["ep-1"] == nil)
    }

    @Test
    func clear_shouldLeaveTombstoneAndNotifyLocalChange() {
        var changeCount = 0
        sut.onLocalChange = { changeCount += 1 }
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)

        sut.clear(episodeID: "ep-1")

        #expect(fakeDatabase.episodeProgressTombstones["ep-1"] != nil)
        #expect(changeCount == 1)
    }

    @Test
    func save_shouldNotNotifyLocalChange() {
        var changeCount = 0
        sut.onLocalChange = { changeCount += 1 }

        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)

        #expect(changeCount == 0)
    }

    @Test
    func save_afterClear_shouldRemoveTombstone() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)
        sut.clear(episodeID: "ep-1")

        sut.save(episodeID: "ep-1", currentTime: 10, duration: 120)

        #expect(fakeDatabase.episodeProgressTombstones["ep-1"] == nil)
    }

    // MARK: - iCloud sync

    @Test
    func syncRecords_shouldIncludeLiveProgressAndClearings() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        try fakeDatabase.upsertEpisodeProgress(episodeId: "ep-1", currentTime: 30, duration: 120, updatedAt: date)
        try fakeDatabase.upsertEpisodeProgressTombstone(episodeId: "ep-2", clearedAt: date)

        let records = sut.syncRecords()

        #expect(records["ep-1"] == EpisodeProgressRecord(currentTime: 30, duration: 120, updatedAt: date, isCleared: false))
        #expect(records["ep-2"] == .cleared(at: date))
    }

    @Test
    func applyRemote_shouldKeepTheRemoteTimestampAndNotNotify() {
        var changeCount = 0
        sut.onLocalChange = { changeCount += 1 }
        let date = Date(timeIntervalSince1970: 1_790_000_000)

        sut.applyRemote(
            EpisodeProgressRecord(currentTime: 45, duration: 100, updatedAt: date, isCleared: false),
            episodeID: "ep-1"
        )

        #expect(sut.progress(for: "ep-1")?.currentTime == 45)
        #expect(fakeDatabase.episodeProgress["ep-1"]?.updatedAt == date)
        #expect(changeCount == 0)
    }

    @Test
    func applyRemote_withClearing_shouldRemoveProgressAndLeaveTombstone() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)
        let date = Date(timeIntervalSince1970: 1_790_000_000)

        sut.applyRemote(.cleared(at: date), episodeID: "ep-1")

        #expect(sut.progress(for: "ep-1") == nil)
        #expect(fakeDatabase.episodeProgressTombstones["ep-1"] == date)
    }

    // MARK: - fractionCompleted

    @Test
    func fractionCompleted_shouldReturnRatio() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)

        #expect(sut.fractionCompleted(for: "ep-1") == 0.25)
    }

    @Test
    func fractionCompleted_whenCurrentExceedsDuration_shouldClampToOne() {
        sut.save(episodeID: "ep-1", currentTime: 200, duration: 120)

        #expect(sut.fractionCompleted(for: "ep-1") == 1.0)
    }

    @Test
    func fractionCompleted_forUnknownEpisode_shouldReturnNil() {
        #expect(sut.fractionCompleted(for: "missing") == nil)
    }

    // MARK: - timeRemaining

    @Test
    func timeRemaining_shouldReturnDifference() {
        sut.save(episodeID: "ep-1", currentTime: 30, duration: 120)

        #expect(sut.timeRemaining(for: "ep-1") == 90)
    }

    @Test
    func timeRemaining_whenCurrentExceedsDuration_shouldClampToZero() {
        sut.save(episodeID: "ep-1", currentTime: 200, duration: 120)

        #expect(sut.timeRemaining(for: "ep-1") == 0)
    }

    @Test
    func timeRemaining_forUnknownEpisode_shouldReturnNil() {
        #expect(sut.timeRemaining(for: "missing") == nil)
    }

    // MARK: - formattedTimeRemaining

    @Test
    func formattedTimeRemaining_withHoursAndMinutes() {
        sut.save(episodeID: "ep-1", currentTime: 0, duration: 4320) // 1h 12m

        #expect(sut.formattedTimeRemaining(for: "ep-1") == "1 hr 12 min restantes")
    }

    @Test
    func formattedTimeRemaining_withWholeHoursOnly() {
        sut.save(episodeID: "ep-1", currentTime: 0, duration: 7200) // 2h

        #expect(sut.formattedTimeRemaining(for: "ep-1") == "2 hr restantes")
    }

    @Test
    func formattedTimeRemaining_withMinutesOnly() {
        sut.save(episodeID: "ep-1", currentTime: 0, duration: 2700) // 45m

        #expect(sut.formattedTimeRemaining(for: "ep-1") == "45 min restantes")
    }

    @Test
    func formattedTimeRemaining_withLessThanOneMinuteRemaining() {
        sut.save(episodeID: "ep-1", currentTime: 90, duration: 120) // 30s left

        #expect(sut.formattedTimeRemaining(for: "ep-1") == "< 1 min restante")
    }

    @Test
    func formattedTimeRemaining_whenNoTimeRemaining_shouldReturnNil() {
        sut.save(episodeID: "ep-1", currentTime: 120, duration: 120)

        #expect(sut.formattedTimeRemaining(for: "ep-1") == nil)
    }

    @Test
    func formattedTimeRemaining_forUnknownEpisode_shouldReturnNil() {
        #expect(sut.formattedTimeRemaining(for: "missing") == nil)
    }
}
