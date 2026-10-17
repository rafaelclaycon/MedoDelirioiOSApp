//
//  ProfileStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Foundation
import os

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "ProfileStore")

/// What the Você tab shows about the user, as kept on this device and in iCloud.
struct ProfileRecord: Codable, Equatable {

    /// An author's ID; their photo is the avatar.
    var avatarAuthorID: String?
    var nickname: String?
    /// When the avatar or nickname last changed. `distantPast` until the user edits
    /// them, so any device that has an edit wins.
    var updatedAt: Date
    var memberSince: Date?
    /// The user's own photo, as a small square JPEG (`ProfilePhoto`). When set, it's the
    /// avatar instead of an author's. Never leaves the user's devices, except in the
    /// pictures they choose to share.
    var customPhoto: Data? = nil

    static let empty = ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: .distantPast, memberSince: nil)

    var identity: ProfileIdentity {
        ProfileIdentity(avatarAuthorID: avatarAuthorID, nickname: nickname, updatedAt: updatedAt, customPhoto: customPhoto)
    }
}

/// The avatar and nickname, as kept in iCloud under their own key. Only a device that
/// edited them writes it.
struct ProfileIdentity: Codable, Equatable {

    var avatarAuthorID: String?
    var nickname: String?
    var updatedAt: Date
    /// Travels with the avatar and nickname, so the three always change together.
    var customPhoto: Data? = nil
}

/// "Com a gente desde", as kept in iCloud under its own key. Any device can lower it.
struct ProfileMemberSince: Codable, Equatable {

    var date: Date
}

/// The user's avatar, nickname and "Com a gente desde", in step across their devices
/// through iCloud key-value storage. There's no account: the Apple Account is the
/// identity.
///
/// Two keys, because iCloud keeps whichever write to a key came last. With one key, a
/// device that opened before another's avatar arrived wrote back its own record (no
/// avatar, just its "desde") and erased the choice. Now the avatar and nickname are
/// written only by a device that edited them, and only when its edit is newer than the
/// cloud's; "desde" has its own key, which any device may lower.
///
/// Syncs on its own rather than through `CloudStateSync`, which is built around
/// `[id: record]` dictionaries.
@Observable
@MainActor
final class ProfileStore {

    nonisolated static let identityKey = "profileIdentity.v1"
    nonisolated static let memberSinceKey = "profileMemberSince.v1"
    /// The single key the first beta builds used. Read, never written, so a choice made
    /// there still arrives.
    nonisolated static let legacyCloudKey = "profile.v1"
    nonisolated static let defaultsKey = "profile.v1"

    private(set) var record: ProfileRecord

    var avatarAuthorID: String? { record.avatarAuthorID }
    var nickname: String? { record.nickname }
    var customPhoto: Data? { record.customPhoto }
    var memberSince: Date? { record.memberSince }

    @ObservationIgnored private let cloudStore: CloudKeyValueStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let database: LocalDatabaseProtocol
    @ObservationIgnored private let isEnabled: () -> Bool
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var externalChangeObserver: NSObjectProtocol?

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
        cloudStore: CloudKeyValueStore = NSUbiquitousKeyValueStore.default,
        defaults: UserDefaults = .standard,
        database: LocalDatabaseProtocol = LocalDatabase.shared,
        isEnabled: @escaping () -> Bool = { UserSettings().getEnableICloudSync() },
        now: @escaping () -> Date = Date.init
    ) {
        self.cloudStore = cloudStore
        self.defaults = defaults
        self.database = database
        self.isEnabled = isEnabled
        self.now = now
        self.record = Self.decode(defaults.data(forKey: Self.defaultsKey)) ?? .empty
    }

    // MARK: - Lifecycle

    /// Folds in this device's oldest activity, starts listening for other devices and
    /// runs a first sync.
    func start() {
        foldInEarliestActivity()

        guard externalChangeObserver == nil else { return }
        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sync()
            }
        }
        sync()
    }

    // MARK: - Editing

    /// An empty or blank nickname clears it. A custom photo replaces the author's, so
    /// passing one clears `avatarAuthorID`; one over `ProfilePhoto.maxBytes` is dropped
    /// rather than risk iCloud's storage limit.
    func update(avatarAuthorID: String?, nickname: String?, customPhoto: Data? = nil) {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let photo = customPhoto.flatMap { $0.count <= ProfilePhoto.maxBytes ? $0 : nil }
        var updated = record
        updated.avatarAuthorID = photo == nil ? avatarAuthorID : nil
        updated.nickname = (trimmed?.isEmpty ?? true) ? nil : trimmed
        updated.customPhoto = photo
        guard updated.avatarAuthorID != record.avatarAuthorID
                || updated.nickname != record.nickname
                || updated.customPhoto != record.customPhoto
        else { return }
        // Always later than the last edit, even within the same instant: only a newer
        // edit is written to iCloud, so a tie would never leave this device.
        updated.updatedAt = max(now(), record.updatedAt.addingTimeInterval(0.001))
        save(updated)
        sync()
    }

    /// Keeps the earliest date between what's known and this device's oldest activity,
    /// and pushes it right away when it moves.
    func foldInEarliestActivity() {
        let earliest: Date?
        do {
            earliest = try database.earliestActivityDate()
        } catch {
            logger.error("Couldn't read the earliest activity: \(error.localizedDescription, privacy: .public)")
            return
        }
        let memberSince = Self.earliest(record.memberSince, earliest)
        guard memberSince != record.memberSince else { return }
        var updated = record
        updated.memberSince = memberSince
        save(updated)
        sync()
    }

    // MARK: - Sync

    /// Takes in what the cloud has, keeps the result here, and writes back only what
    /// this device knows better: an avatar or nickname it edited after the cloud's, or
    /// an earlier "desde". Does nothing while iCloud sync is off in Settings.
    func sync() {
        guard isEnabled() else { return }

        let legacy: ProfileRecord? = read(Self.legacyCloudKey)
        let cloudIdentity: ProfileIdentity? = read(Self.identityKey)
        let cloudMemberSince: ProfileMemberSince? = read(Self.memberSinceKey)

        let merged = Self.merge(
            local: record,
            cloudIdentity: cloudIdentity ?? legacy?.identity,
            cloudMemberSince: cloudMemberSince?.date ?? legacy?.memberSince
        )
        if merged != record {
            save(merged)
        }

        if Self.shouldWriteIdentity(merged.identity, over: cloudIdentity) {
            write(merged.identity, forKey: Self.identityKey)
        }
        if let memberSince = merged.memberSince,
           Self.shouldWriteMemberSince(memberSince, over: cloudMemberSince?.date) {
            write(ProfileMemberSince(date: memberSince), forKey: Self.memberSinceKey)
        }
    }

    /// The avatar and nickname come together from whichever side changed them last, so a
    /// device never ends up with one edit's avatar and another's nickname. A tie keeps
    /// the local one. "Com a gente desde" is the earliest either knows.
    nonisolated static func merge(
        local: ProfileRecord,
        cloudIdentity: ProfileIdentity?,
        cloudMemberSince: Date?
    ) -> ProfileRecord {
        var merged = local
        if let cloudIdentity, cloudIdentity.updatedAt > local.updatedAt {
            merged.avatarAuthorID = cloudIdentity.avatarAuthorID
            merged.nickname = cloudIdentity.nickname
            merged.customPhoto = cloudIdentity.customPhoto
            merged.updatedAt = cloudIdentity.updatedAt
        }
        merged.memberSince = earliest(local.memberSince, cloudMemberSince)
        return merged
    }

    /// Only an edit newer than the cloud's. A device that never edited (`distantPast`)
    /// never writes, which is what kept erasing another device's choice.
    nonisolated static func shouldWriteIdentity(_ identity: ProfileIdentity, over cloud: ProfileIdentity?) -> Bool {
        identity.updatedAt > (cloud?.updatedAt ?? .distantPast)
    }

    nonisolated static func shouldWriteMemberSince(_ date: Date, over cloud: Date?) -> Bool {
        guard let cloud else { return true }
        return date < cloud
    }

    // MARK: - Helpers

    private func save(_ updated: ProfileRecord) {
        record = updated
        do {
            defaults.set(try Self.encoder.encode(updated), forKey: Self.defaultsKey)
        } catch {
            logger.error("Couldn't save the profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func read<Value: Decodable>(_ key: String) -> Value? {
        guard let data = cloudStore.data(forKey: key) else { return nil }
        do {
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            logger.error("Couldn't decode \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func write<Value: Encodable>(_ value: Value, forKey key: String) {
        do {
            cloudStore.setData(try Self.encoder.encode(value), forKey: key)
        } catch {
            logger.error("Couldn't encode \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func earliest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        [lhs, rhs].compactMap { $0 }.min()
    }

    private static func decode(_ data: Data?) -> ProfileRecord? {
        guard let data else { return nil }
        do {
            return try decoder.decode(ProfileRecord.self, from: data)
        } catch {
            logger.error("Couldn't decode the profile: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
