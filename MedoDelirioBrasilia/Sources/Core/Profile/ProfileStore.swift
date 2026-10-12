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

    static let empty = ProfileRecord(avatarAuthorID: nil, nickname: nil, updatedAt: .distantPast, memberSince: nil)
}

/// The user's avatar, nickname and "Com a gente desde", in step across their devices
/// through iCloud key-value storage. There's no account: the Apple Account is the
/// identity.
///
/// A single record under one key, so it syncs on its own rather than through
/// `CloudStateSync`, which is built around `[id: record]` dictionaries.
@Observable
@MainActor
final class ProfileStore {

    nonisolated static let cloudKey = "profile.v1"
    nonisolated static let defaultsKey = "profile.v1"

    private(set) var record: ProfileRecord

    var avatarAuthorID: String? { record.avatarAuthorID }
    var nickname: String? { record.nickname }
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

    /// An empty or blank nickname clears it.
    func update(avatarAuthorID: String?, nickname: String?) {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = record
        updated.avatarAuthorID = avatarAuthorID
        updated.nickname = (trimmed?.isEmpty ?? true) ? nil : trimmed
        guard updated.avatarAuthorID != record.avatarAuthorID || updated.nickname != record.nickname else { return }
        updated.updatedAt = now()
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

    /// Merges with the cloud copy, keeps the result here and writes it back only if the
    /// cloud copy differs. Does nothing while iCloud sync is off in Settings.
    func sync() {
        guard isEnabled() else { return }

        let remote = Self.decode(cloudStore.data(forKey: Self.cloudKey))
        let merged = remote.map { Self.merge(local: record, remote: $0) } ?? record

        if merged != record {
            save(merged)
        }
        if merged != remote, merged != .empty {
            do {
                cloudStore.setData(try Self.encoder.encode(merged), forKey: Self.cloudKey)
            } catch {
                logger.error("Couldn't encode the profile: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// The avatar and nickname come together from whichever record changed them last,
    /// so a device never ends up with one person's avatar and another edit's nickname.
    /// A tie keeps the local one. "Com a gente desde" is the earliest either knows.
    nonisolated static func merge(local: ProfileRecord, remote: ProfileRecord) -> ProfileRecord {
        var merged = remote.updatedAt > local.updatedAt ? remote : local
        merged.memberSince = earliest(local.memberSince, remote.memberSince)
        return merged
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
