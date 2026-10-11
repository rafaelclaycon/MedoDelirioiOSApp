//
//  FavoritesBackupStoreTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct FavoritesBackupStoreTests {

    /// Lets a test move the store's clock between calls.
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private let start = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 12))!
    private let fakeDatabase = FakeLocalDatabase()
    private let clock: Clock
    private let sut: FavoritesBackupStore

    init() {
        clock = Clock(start)
        let clock = clock
        sut = FavoritesBackupStore(
            database: fakeDatabase,
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("FavoritesBackupStoreTests-\(UUID().uuidString)"),
            now: { clock.now }
        )
    }

    // MARK: - Helpers

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: start)!
    }

    private func favorites(_ ids: String...) -> [String: Date] {
        Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, start.addingTimeInterval(Double($0))) })
    }

    // MARK: - Backing Up

    @Test
    func firstBackup_shouldKeepTheFavoritesFromBeforeSync_evenWhenEmpty() {
        sut.backUpBeforeSync(favorites: [:])

        let backups = sut.backups()
        #expect(backups.map(\.kind) == [.beforeFirstSync])
        #expect(backups.first?.count == 0)
    }

    @Test
    func laterDays_shouldOnlyBackUpWhenTheFavoritesChanged() {
        sut.backUpBeforeSync(favorites: favorites("a"))

        clock.now = day(1)
        sut.backUpBeforeSync(favorites: favorites("a"))
        #expect(sut.backups().count == 1)

        clock.now = day(2)
        sut.backUpBeforeSync(favorites: favorites("a", "b"))
        #expect(sut.backups().map(\.kind) == [.daily, .beforeFirstSync])
    }

    @Test
    func sameDay_shouldBackUpOnlyOnce() {
        sut.backUpBeforeSync(favorites: favorites("a"))
        clock.now = day(1)
        sut.backUpBeforeSync(favorites: favorites("a", "b"))

        clock.now = day(1).addingTimeInterval(3600)
        sut.backUpBeforeSync(favorites: favorites("a", "b", "c"))

        #expect(sut.backups().filter { $0.kind == .daily }.map(\.count) == [2])
    }

    @Test
    func emptyFavorites_shouldNeverTakeADailyBackup() {
        sut.backUpBeforeSync(favorites: favorites("a"))
        clock.now = day(1)

        sut.backUpBeforeSync(favorites: [:])

        #expect(sut.backups().filter { $0.kind == .daily }.isEmpty)
    }

    @Test
    func dailyBackups_shouldKeepOnlyTheNewest() {
        sut.backUpBeforeSync(favorites: favorites("first"))
        for offset in 1...10 {
            clock.now = day(offset)
            sut.backUpBeforeSync(favorites: favorites("day-\(offset)"))
        }

        let backups = sut.backups()
        let dailies = backups.filter { $0.kind == .daily }
        #expect(dailies.count == FavoritesBackupStore.dailyBackupsKept)
        #expect(dailies.first?.createdAt == day(10))
        #expect(backups.contains { $0.kind == .beforeFirstSync })
    }

    // MARK: - Restoring

    @Test
    func restore_shouldAddOnlyWhatIsMissing_andRemoveNothing() throws {
        sut.backUpBeforeSync(favorites: favorites("a", "b", "c"))
        let file = try #require(sut.backups().first)
        let backup = try #require(sut.backup(at: file.url))
        fakeDatabase.favoriteDates = ["a": start, "extra": start]

        let restored = sut.restore(backup)

        #expect(restored == 2)
        #expect(Set(fakeDatabase.favoriteDates.keys) == ["a", "b", "c", "extra"])
    }

    @Test
    func restore_shouldDateFavoritesNow_inTheirOriginalOrder_andClearTombstones() throws {
        sut.backUpBeforeSync(favorites: favorites("older", "newer"))
        let file = try #require(sut.backups().first)
        let backup = try #require(sut.backup(at: file.url))
        clock.now = day(5)
        fakeDatabase.favoriteTombstones = ["older": day(4), "newer": day(4)]

        sut.restore(backup)

        let older = try #require(fakeDatabase.favoriteDates["older"])
        let newer = try #require(fakeDatabase.favoriteDates["newer"])
        #expect(newer == day(5))
        #expect(older < newer)
        #expect(older > day(4))
        #expect(fakeDatabase.favoriteTombstones.isEmpty)
    }

    @Test
    func restore_withNothingMissing_shouldChangeNothing() throws {
        sut.backUpBeforeSync(favorites: favorites("a"))
        let file = try #require(sut.backups().first)
        let backup = try #require(sut.backup(at: file.url))
        fakeDatabase.favoriteDates = ["a": start]

        #expect(sut.restore(backup) == 0)
        #expect(fakeDatabase.favoriteDates == ["a": start])
    }
}
