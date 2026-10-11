//
//  FavoritesMultiDeviceSyncTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

/// Several devices sharing one iCloud store, each with its own favorites, to check they
/// all end up agreeing, and on the right answer: the latest change to each favorite.
@MainActor
struct FavoritesMultiDeviceSyncTests {

    /// One shared clock, so every device's changes and syncs line up in time.
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_790_000_000)
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    /// One device: its database and sync, sharing `cloud` with the others.
    @MainActor
    private final class Device {
        let database = FakeLocalDatabase()
        let sync: CloudStateSync
        private let clock: Clock

        init(cloud: FakeCloudKeyValueStore, clock: Clock) {
            self.clock = clock
            let database = database
            sync = CloudStateSync(
                progressStore: EpisodeProgressStore(database: database),
                playedStore: EpisodePlayedStore(database: database),
                favoriteStore: EpisodeFavoritesStore(database: database),
                contentFavoriteStore: ContentFavoritesSyncStore(database: database),
                favoritesBackup: FavoritesBackupStore(
                    database: database,
                    directory: FileManager.default.temporaryDirectory
                        .appendingPathComponent("FavoritesMultiDeviceSyncTests-\(UUID().uuidString)"),
                    now: { clock.now }
                ),
                cloudStore: cloud,
                isEnabled: { true },
                now: { clock.now }
            )
        }

        var favorites: Set<String> { Set(database.favoriteDates.keys) }

        /// What `ContentRepository` does on a tap, with the shared clock instead of `Date()`.
        func favorite(_ id: String) {
            database.favoriteDates[id] = clock.now
            database.favoriteTombstones.removeValue(forKey: id)
        }

        func unfavorite(_ id: String) {
            database.favoriteDates.removeValue(forKey: id)
            database.favoriteTombstones[id] = clock.now
        }

        func toggle(_ id: String) {
            favorites.contains(id) ? unfavorite(id) : favorite(id)
        }
    }

    private let clock = Clock()
    private let cloud = FakeCloudKeyValueStore()

    private func makeDevices(_ count: Int) -> [Device] {
        (0..<count).map { _ in Device(cloud: cloud, clock: clock) }
    }

    /// Two rounds, so whatever the last device pushed reaches the first ones too.
    private func syncAll(_ devices: [Device]) {
        for _ in 0..<2 {
            for device in devices {
                device.sync.sync()
            }
        }
    }

    // MARK: - Scenarios

    @Test
    func threeDevicesWithDifferentFavorites_shouldAllEndUpWithAllOfThem() {
        let devices = makeDevices(3)
        devices[0].favorite("a"); devices[0].favorite("b")
        clock.advance(1)
        devices[1].favorite("b"); devices[1].favorite("c")
        clock.advance(1)
        devices[2].favorite("d")

        syncAll(devices)

        for device in devices {
            #expect(device.favorites == ["a", "b", "c", "d"])
        }
    }

    @Test
    func removalOnOneDevice_andAdditionOnAnother_shouldBothReachEveryDevice() {
        let devices = makeDevices(2)
        devices[0].favorite("a"); devices[0].favorite("b")
        syncAll(devices)

        clock.advance(60)
        devices[0].unfavorite("a")
        clock.advance(1)
        devices[1].favorite("c")
        syncAll(devices)

        for device in devices {
            #expect(device.favorites == ["b", "c"])
        }
    }

    @Test
    func refavoritingAfterARemovalElsewhere_shouldKeepTheFavorite() {
        let devices = makeDevices(2)
        devices[0].favorite("a")
        syncAll(devices)

        clock.advance(60)
        devices[0].unfavorite("a")
        devices[0].sync.sync()
        clock.advance(60)
        devices[1].favorite("a")
        syncAll(devices)

        for device in devices {
            #expect(device.favorites == ["a"])
        }
    }

    @Test
    func removalOnADeviceThatWasOffline_shouldStillWin_whenItIsTheLatestChange() {
        let devices = makeDevices(2)
        devices[0].favorite("a")
        syncAll(devices)

        // Device 1 removes it while offline, then device 0 changes something else.
        clock.advance(60)
        devices[1].unfavorite("a")
        clock.advance(60)
        devices[0].favorite("b")
        devices[0].sync.sync()

        syncAll(devices)

        for device in devices {
            #expect(device.favorites == ["b"])
        }
    }

    @Test
    func aWriteLostToAnotherDevicesWrite_shouldComeBackOnTheNextSync() {
        let devices = makeDevices(2)
        devices[0].favorite("a")
        devices[1].favorite("b")

        // Both push at once: device 0's write lands, then device 1's, made from the
        // cloud as it was before device 0's, replaces it.
        let before = cloud.values
        devices[0].sync.sync()
        cloud.values = before
        devices[1].sync.sync()

        syncAll(devices)

        for device in devices {
            #expect(device.favorites == ["a", "b"])
        }
    }

    @Test
    func restoringABackup_shouldBringTheFavoriteBackOnEveryDevice() throws {
        let devices = makeDevices(2)
        devices[0].favorite("a")
        syncAll(devices)

        clock.advance(60)
        devices[1].unfavorite("a")
        syncAll(devices)
        #expect(devices[0].favorites.isEmpty)

        clock.advance(60)
        let backup = FavoritesBackup(
            kind: .beforeFirstSync,
            createdAt: clock.now,
            favorites: [FavoritesBackup.Entry(contentId: "a", dateAdded: clock.now.addingTimeInterval(-3600))]
        )
        let backupStore = FavoritesBackupStore(
            database: devices[0].database,
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            now: { [clock] in clock.now }
        )
        #expect(backupStore.restore(backup) == 1)
        syncAll(devices)

        for device in devices {
            #expect(device.favorites == ["a"])
        }
    }

    // MARK: - Random Sequences

    /// SplitMix64, so a failing sequence can be replayed from its seed.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Three devices, 40 items, a few hundred random favorites, removals and syncs, with
    /// some syncs losing their write to another device's. In the end every device must
    /// hold exactly the items whose latest change, on any device, was a favorite.
    @Test(arguments: [1, 2, 3, 42, 1234, 2026])
    func randomChangesOnThreeDevices_shouldAgreeOnTheLatestChangeToEachFavorite(seed: UInt64) {
        var random = SeededGenerator(state: seed)
        let devices = makeDevices(3)
        let items = (0..<40).map { "item-\($0)" }
        var latestChange = [String: Bool]()

        // Favorites from before sync existed, a different handful on each device.
        for device in devices {
            for item in items where Int.random(in: 0..<4, using: &random) == 0 {
                clock.advance(1)
                device.favorite(item)
                latestChange[item] = true
            }
        }

        for _ in 0..<400 {
            clock.advance(TimeInterval(Int.random(in: 1...120, using: &random)))
            let device = devices[Int.random(in: 0..<devices.count, using: &random)]

            switch Int.random(in: 0..<10, using: &random) {
            case 0..<6:
                let item = items[Int.random(in: 0..<items.count, using: &random)]
                device.toggle(item)
                latestChange[item] = device.favorites.contains(item)
            case 6..<9:
                device.sync.sync()
            default:
                let before = cloud.values
                device.sync.sync()
                cloud.values = before
            }
        }

        syncAll(devices)

        let expected = Set(latestChange.filter(\.value).keys)
        for device in devices {
            #expect(device.favorites == expected, "seed \(seed)")
        }
    }
}

// MARK: - Repository

@MainActor
struct ContentRepositoryFavoriteSyncTests {

    @Test
    func deleteFavorite_shouldRememberTheRemoval_andTellSync() throws {
        let database = FakeLocalDatabase()
        database.favoriteDates["sound-1"] = Date(timeIntervalSince1970: 0)
        let sut = ContentRepository(database: database)
        var notified = 0
        let observer = NotificationCenter.default.addObserver(
            forName: ContentFavoritesSyncStore.didChangeLocally, object: nil, queue: nil
        ) { _ in notified += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        try sut.deleteFavorite("sound-1")

        #expect(database.favoriteDates["sound-1"] == nil)
        #expect(database.favoriteTombstones["sound-1"] != nil)
        #expect(notified == 1)
    }

    @Test
    func insertFavorite_shouldClearAnEarlierRemoval_andTellSync() throws {
        let database = FakeLocalDatabase()
        database.favoriteTombstones["sound-1"] = Date(timeIntervalSince1970: 0)
        let sut = ContentRepository(database: database)
        var notified = 0
        let observer = NotificationCenter.default.addObserver(
            forName: ContentFavoritesSyncStore.didChangeLocally, object: nil, queue: nil
        ) { _ in notified += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        try sut.insert(favorite: Favorite(contentId: "sound-1", dateAdded: .now))

        #expect(database.favoriteDates["sound-1"] != nil)
        #expect(database.favoriteTombstones["sound-1"] == nil)
        #expect(notified == 1)
    }
}
