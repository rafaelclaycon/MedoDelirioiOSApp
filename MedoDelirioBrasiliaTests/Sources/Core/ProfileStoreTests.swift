//
//  ProfileStoreTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

@MainActor
struct ProfileStoreTests {

    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_790_000_000)
    }

    private let clock = Clock()
    private let cloud = FakeCloudKeyValueStore()
    private let database = FakeLocalDatabase()
    private let defaults = UserDefaults(suiteName: "ProfileStoreTests-\(UUID().uuidString)")!

    private func store(syncEnabled: Bool = true, defaults: UserDefaults? = nil) -> ProfileStore {
        let clock = clock
        return ProfileStore(
            cloudStore: cloud,
            defaults: defaults ?? self.defaults,
            database: database,
            isEnabled: { syncEnabled },
            now: { clock.now }
        )
    }

    private func cloudRecord() throws -> ProfileRecord? {
        guard let data = cloud.values[ProfileStore.cloudKey] else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(ProfileRecord.self, from: data)
    }

    private func setCloudRecord(_ record: ProfileRecord) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        cloud.values[ProfileStore.cloudKey] = try encoder.encode(record)
    }

    // MARK: - Merge

    @Test
    func merge_shouldTakeTheIdentityFromTheNewerRecord() {
        let older = ProfileRecord(avatarAuthorID: "a", nickname: "Velho", updatedAt: Date(timeIntervalSince1970: 100), memberSince: nil)
        let newer = ProfileRecord(avatarAuthorID: "b", nickname: "Novo", updatedAt: Date(timeIntervalSince1970: 200), memberSince: nil)

        #expect(ProfileStore.merge(local: older, remote: newer).nickname == "Novo")
        #expect(ProfileStore.merge(local: newer, remote: older).avatarAuthorID == "b")
    }

    @Test
    func merge_onATie_shouldKeepTheLocalRecord() {
        let date = Date(timeIntervalSince1970: 100)
        let local = ProfileRecord(avatarAuthorID: "a", nickname: "Aqui", updatedAt: date, memberSince: nil)
        let remote = ProfileRecord(avatarAuthorID: "b", nickname: "Lá", updatedAt: date, memberSince: nil)

        #expect(ProfileStore.merge(local: local, remote: remote) == local)
    }

    @Test
    func merge_shouldKeepTheEarliestMemberSince() {
        let early = Date(timeIntervalSince1970: 1_600_000_000)
        let late = Date(timeIntervalSince1970: 1_700_000_000)
        let local = ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: Date(timeIntervalSince1970: 300), memberSince: late)
        let remote = ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: Date(timeIntervalSince1970: 100), memberSince: early)

        #expect(ProfileStore.merge(local: local, remote: remote).memberSince == early)
    }

    @Test
    func merge_whenOnlyOneSideKnowsMemberSince_shouldKeepIt() {
        let date = Date(timeIntervalSince1970: 1_600_000_000)
        let local = ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: .distantPast, memberSince: nil)
        let remote = ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: .distantPast, memberSince: date)

        #expect(ProfileStore.merge(local: local, remote: remote).memberSince == date)
    }

    // MARK: - Editing

    @Test
    func update_shouldSaveTheProfileAndPushIt() throws {
        let sut = store()

        sut.update(avatarAuthorID: "author-1", nickname: "  Ouvinte  ")

        #expect(sut.avatarAuthorID == "author-1")
        #expect(sut.nickname == "Ouvinte")
        #expect(try cloudRecord()?.nickname == "Ouvinte")
        #expect(try cloudRecord()?.updatedAt == clock.now)
    }

    @Test
    func update_withABlankNickname_shouldClearIt() {
        let sut = store()
        sut.update(avatarAuthorID: nil, nickname: "Ouvinte")

        sut.update(avatarAuthorID: nil, nickname: "   ")

        #expect(sut.nickname == nil)
    }

    @Test
    func update_withoutChanges_shouldNotWriteAgain() {
        let sut = store()
        sut.update(avatarAuthorID: "author-1", nickname: "Ouvinte")
        let writes = cloud.setDataCallCount

        sut.update(avatarAuthorID: "author-1", nickname: "Ouvinte")

        #expect(cloud.setDataCallCount == writes)
    }

    @Test
    func update_shouldSurviveARelaunch() {
        store().update(avatarAuthorID: "author-1", nickname: "Ouvinte")

        let relaunched = store(syncEnabled: false)

        #expect(relaunched.avatarAuthorID == "author-1")
        #expect(relaunched.nickname == "Ouvinte")
    }

    // MARK: - Sync

    @Test
    func sync_whenOff_shouldNotTouchTheCloud() {
        let sut = store(syncEnabled: false)

        sut.update(avatarAuthorID: "author-1", nickname: "Ouvinte")

        #expect(cloud.setDataCallCount == 0)
        #expect(sut.nickname == "Ouvinte")
    }

    @Test
    func sync_shouldApplyAnEditFromAnotherDevice() throws {
        let sut = store()
        try setCloudRecord(ProfileRecord(avatarAuthorID: "author-2", nickname: "Do iPad", updatedAt: clock.now, memberSince: nil))

        sut.sync()

        #expect(sut.avatarAuthorID == "author-2")
        #expect(sut.nickname == "Do iPad")
    }

    @Test
    func sync_withAnOlderCloudCopy_shouldKeepTheLocalEditAndPushIt() throws {
        let sut = store()
        sut.update(avatarAuthorID: "author-1", nickname: "Novo")
        try setCloudRecord(ProfileRecord(avatarAuthorID: "author-2", nickname: "Velho", updatedAt: clock.now.addingTimeInterval(-60), memberSince: nil))

        sut.sync()

        #expect(sut.nickname == "Novo")
        #expect(try cloudRecord()?.nickname == "Novo")
    }

    @Test
    func sync_withNothingToSay_shouldNotWrite() {
        let sut = store()

        sut.sync()

        #expect(cloud.setDataCallCount == 0)
    }

    // MARK: - Member Since

    @Test
    func start_shouldUseTheEarliestLocalActivity() throws {
        let firstShare = Date(timeIntervalSince1970: 1_650_000_000)
        database.earliestActivity = firstShare
        let sut = store()

        sut.start()

        #expect(sut.memberSince == firstShare)
        #expect(try cloudRecord()?.memberSince == firstShare)
    }

    @Test
    func start_shouldKeepAnEarlierDateFromAnotherDevice() throws {
        let fromOtherDevice = Date(timeIntervalSince1970: 1_600_000_000)
        database.earliestActivity = Date(timeIntervalSince1970: 1_750_000_000)
        try setCloudRecord(ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: .distantPast, memberSince: fromOtherDevice))
        let sut = store()

        sut.start()

        #expect(sut.memberSince == fromOtherDevice)
    }

    @Test
    func foldInEarliestActivity_whenTheDateMovesEarlier_shouldPushItRightAway() throws {
        database.earliestActivity = Date(timeIntervalSince1970: 1_750_000_000)
        let sut = store()
        sut.start()

        let earlier = Date(timeIntervalSince1970: 1_650_000_000)
        database.earliestActivity = earlier
        sut.foldInEarliestActivity()

        #expect(try cloudRecord()?.memberSince == earlier)
    }

    @Test
    func start_withNoActivity_shouldLeaveMemberSinceEmpty() {
        let sut = store()

        sut.start()

        #expect(sut.memberSince == nil)
        #expect(cloud.setDataCallCount == 0)
    }
}
