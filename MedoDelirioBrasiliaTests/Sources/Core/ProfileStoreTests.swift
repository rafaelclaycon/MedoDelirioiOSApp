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

    private static func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ProfileStoreTests-\(UUID().uuidString)")!
    }

    private let defaults = ProfileStoreTests.freshDefaults()

    private func store(
        syncEnabled: Bool = true,
        defaults: UserDefaults? = nil,
        database: FakeLocalDatabase? = nil
    ) -> ProfileStore {
        let clock = clock
        return ProfileStore(
            cloudStore: cloud,
            defaults: defaults ?? self.defaults,
            database: database ?? self.database,
            isEnabled: { syncEnabled },
            now: { clock.now }
        )
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    private func cloudIdentity() throws -> ProfileIdentity? {
        guard let data = cloud.values[ProfileStore.identityKey] else { return nil }
        return try Self.decoder.decode(ProfileIdentity.self, from: data)
    }

    private func cloudMemberSince() throws -> Date? {
        guard let data = cloud.values[ProfileStore.memberSinceKey] else { return nil }
        return try Self.decoder.decode(ProfileMemberSince.self, from: data).date
    }

    private func setCloudIdentity(_ identity: ProfileIdentity) throws {
        cloud.values[ProfileStore.identityKey] = try Self.encoder.encode(identity)
    }

    private func setCloudMemberSince(_ date: Date) throws {
        cloud.values[ProfileStore.memberSinceKey] = try Self.encoder.encode(ProfileMemberSince(date: date))
    }

    // MARK: - Merge

    @Test
    func merge_shouldTakeTheIdentityFromTheNewerSide() {
        let local = ProfileRecord(avatarAuthorID: "a", nickname: "Velho", updatedAt: Date(timeIntervalSince1970: 100), memberSince: nil)
        let cloud = ProfileIdentity(avatarAuthorID: "b", nickname: "Novo", updatedAt: Date(timeIntervalSince1970: 200))

        let merged = ProfileStore.merge(local: local, cloudIdentity: cloud, cloudMemberSince: nil)

        #expect(merged.avatarAuthorID == "b")
        #expect(merged.nickname == "Novo")
    }

    @Test
    func merge_withAnOlderOrEqualCloudIdentity_shouldKeepTheLocalOne() {
        let date = Date(timeIntervalSince1970: 100)
        let local = ProfileRecord(avatarAuthorID: "a", nickname: "Aqui", updatedAt: date, memberSince: nil)

        let tie = ProfileStore.merge(local: local, cloudIdentity: ProfileIdentity(avatarAuthorID: "b", nickname: "Lá", updatedAt: date), cloudMemberSince: nil)
        let older = ProfileStore.merge(local: local, cloudIdentity: ProfileIdentity(avatarAuthorID: "b", nickname: "Lá", updatedAt: .distantPast), cloudMemberSince: nil)

        #expect(tie == local)
        #expect(older == local)
    }

    @Test
    func merge_shouldKeepTheEarliestMemberSince() {
        let early = Date(timeIntervalSince1970: 1_600_000_000)
        let late = Date(timeIntervalSince1970: 1_700_000_000)
        let local = ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: .distantPast, memberSince: late)

        #expect(ProfileStore.merge(local: local, cloudIdentity: nil, cloudMemberSince: early).memberSince == early)
        #expect(ProfileStore.merge(local: local, cloudIdentity: nil, cloudMemberSince: nil).memberSince == late)
    }

    @Test
    func shouldWriteIdentity_onlyForAnEditNewerThanTheCloud() {
        let cloud = ProfileIdentity(avatarAuthorID: "a", nickname: nil, updatedAt: Date(timeIntervalSince1970: 200))

        #expect(ProfileStore.shouldWriteIdentity(ProfileIdentity(avatarAuthorID: "b", nickname: nil, updatedAt: Date(timeIntervalSince1970: 300)), over: cloud))
        #expect(!ProfileStore.shouldWriteIdentity(ProfileIdentity(avatarAuthorID: "b", nickname: nil, updatedAt: Date(timeIntervalSince1970: 200)), over: cloud))
        #expect(!ProfileStore.shouldWriteIdentity(ProfileRecord.empty.identity, over: nil))
    }

    // MARK: - Editing

    @Test
    func update_shouldSaveTheProfileAndPushIt() throws {
        let sut = store()

        sut.update(avatarAuthorID: "author-1", nickname: "  Ouvinte  ")

        #expect(sut.avatarAuthorID == "author-1")
        #expect(sut.nickname == "Ouvinte")
        #expect(try cloudIdentity()?.nickname == "Ouvinte")
        #expect(try cloudIdentity()?.updatedAt == clock.now)
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
        try setCloudIdentity(ProfileIdentity(avatarAuthorID: "author-2", nickname: "Do iPad", updatedAt: clock.now))

        sut.sync()

        #expect(sut.avatarAuthorID == "author-2")
        #expect(sut.nickname == "Do iPad")
    }

    @Test
    func sync_withAnOlderCloudIdentity_shouldKeepTheLocalEditAndPushIt() throws {
        let sut = store()
        sut.update(avatarAuthorID: "author-1", nickname: "Novo")
        try setCloudIdentity(ProfileIdentity(avatarAuthorID: "author-2", nickname: "Velho", updatedAt: clock.now.addingTimeInterval(-60)))

        sut.sync()

        #expect(sut.nickname == "Novo")
        #expect(try cloudIdentity()?.nickname == "Novo")
    }

    @Test
    func sync_withNothingToSay_shouldNotWrite() {
        let sut = store()

        sut.sync()

        #expect(cloud.setDataCallCount == 0)
    }

    /// The bug from the TestFlight build: the iPad opened before the iPhone's avatar
    /// reached it, wrote its own record (no avatar, its own "desde") and erased the
    /// iPhone's choice in iCloud.
    @Test
    func sync_onADeviceThatNeverEdited_shouldNeverWriteTheAvatar() throws {
        let iPadDatabase = FakeLocalDatabase()
        iPadDatabase.earliestActivity = Date(timeIntervalSince1970: 1_700_000_000)
        let iPad = store(defaults: Self.freshDefaults(), database: iPadDatabase)

        iPad.start()

        #expect(cloud.values[ProfileStore.identityKey] == nil)
        #expect(try cloudMemberSince() == iPadDatabase.earliestActivity)
    }

    @Test
    func sync_twoDevices_shouldEndWithTheAvatarFromWhereItWasPicked() throws {
        let iPhone = store(defaults: Self.freshDefaults())
        iPhone.update(avatarAuthorID: "cristiano", nickname: nil)

        let iPadDatabase = FakeLocalDatabase()
        iPadDatabase.earliestActivity = Date(timeIntervalSince1970: 1_700_000_000)
        let iPad = store(defaults: Self.freshDefaults(), database: iPadDatabase)
        iPad.start()

        #expect(iPad.avatarAuthorID == "cristiano")
        #expect(try cloudIdentity()?.avatarAuthorID == "cristiano")
    }

    @Test
    func sync_shouldStillPickUpAChoiceFromTheFirstBetaBuilds() throws {
        let legacy = ProfileRecord(avatarAuthorID: "cristiano", nickname: "Rafa", updatedAt: clock.now, memberSince: nil)
        cloud.values[ProfileStore.legacyCloudKey] = try Self.encoder.encode(legacy)
        let sut = store()

        sut.sync()

        #expect(sut.avatarAuthorID == "cristiano")
        #expect(sut.nickname == "Rafa")
    }

    // MARK: - Member Since

    @Test
    func start_shouldUseTheEarliestLocalActivity() throws {
        let firstShare = Date(timeIntervalSince1970: 1_650_000_000)
        database.earliestActivity = firstShare
        let sut = store()

        sut.start()

        #expect(sut.memberSince == firstShare)
        #expect(try cloudMemberSince() == firstShare)
    }

    @Test
    func start_shouldKeepAnEarlierDateFromAnotherDevice() throws {
        let fromOtherDevice = Date(timeIntervalSince1970: 1_600_000_000)
        database.earliestActivity = Date(timeIntervalSince1970: 1_750_000_000)
        try setCloudMemberSince(fromOtherDevice)
        let sut = store()

        sut.start()

        #expect(sut.memberSince == fromOtherDevice)
        #expect(try cloudMemberSince() == fromOtherDevice)
    }

    @Test
    func start_withNoActivity_shouldLeaveMemberSinceEmpty() {
        let sut = store()

        sut.start()

        #expect(sut.memberSince == nil)
        #expect(cloud.setDataCallCount == 0)
    }

    @Test
    func foldInEarliestActivity_whenTheDateMovesEarlier_shouldPushItRightAway() throws {
        database.earliestActivity = Date(timeIntervalSince1970: 1_750_000_000)
        let sut = store()
        sut.start()

        let earlier = Date(timeIntervalSince1970: 1_650_000_000)
        database.earliestActivity = earlier
        sut.foldInEarliestActivity()

        #expect(try cloudMemberSince() == earlier)
    }
}
