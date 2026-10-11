//
//  ContentFavoritesSyncStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Foundation

/// The sound and song favorites as `CloudStateSync` sees them: what this device has,
/// what it removed, and how to take in a change from another device.
///
/// Unlike the episode stores this one holds no list for views. Favorites are read from
/// the database wherever they're shown, and changed through `ContentRepository`, which
/// posts `didChangeLocally`.
final class ContentFavoritesSyncStore {

    /// A favorite was added or removed on this device, so the other devices should hear
    /// about it.
    static let didChangeLocally = Notification.Name("ContentFavoritesSyncStore.didChangeLocally")

    /// Favorites changed without the screen showing them doing it: another device's
    /// change arrived, or a backup was restored. Views showing favorites reload.
    static let didChangeExternally = Notification.Name("ContentFavoritesSyncStore.didChangeExternally")

    private let database: LocalDatabaseProtocol

    /// Called on every `didChangeLocally`.
    var onLocalChange: (() -> Void)?

    private var localChangeObserver: NSObjectProtocol?

    init(database: LocalDatabaseProtocol = LocalDatabase.shared) {
        self.database = database
        localChangeObserver = NotificationCenter.default.addObserver(
            forName: Self.didChangeLocally,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onLocalChange?()
        }
    }

    deinit {
        if let localChangeObserver {
            NotificationCenter.default.removeObserver(localChangeObserver)
        }
    }

    /// When each current favorite was added, for backups.
    func favoriteDates() -> [String: Date] {
        (try? database.allFavoriteDates()) ?? [:]
    }

    /// Every favorite and unfavorite this device knows about, as sent to iCloud.
    func syncRecords() -> [String: ContentFavoriteRecord] {
        var records = [String: ContentFavoriteRecord]()
        for (id, unfavoritedAt) in (try? database.allFavoriteTombstones()) ?? [:] {
            records[id] = ContentFavoriteRecord(isFavorite: false, updatedAt: unfavoritedAt)
        }
        for (id, dateAdded) in favoriteDates() {
            let record = ContentFavoriteRecord(isFavorite: true, updatedAt: dateAdded)
            if let existing = records[id], existing.isNewer(than: record) { continue }
            records[id] = record
        }
        return records
    }

    /// Takes in a newer record from another device, keeping its timestamp so later
    /// merges compare against when it actually changed. Doesn't post `didChangeLocally`.
    func applyRemote(_ record: ContentFavoriteRecord, contentID: String) {
        if record.isFavorite {
            try? database.upsertFavorite(contentId: contentID, dateAdded: record.updatedAt)
            try? database.deleteFavoriteTombstone(contentId: contentID)
        } else {
            try? database.deleteFavorite(withId: contentID)
            try? database.upsertFavoriteTombstone(contentId: contentID, unfavoritedAt: record.updatedAt)
        }
    }

    /// Once per sync that applied anything, so the screens reload once.
    func didApplyRemoteChanges() {
        NotificationCenter.default.post(name: Self.didChangeExternally, object: nil)
    }

    func pruneTombstones(olderThan date: Date) {
        try? database.deleteFavoriteTombstones(olderThan: date)
    }
}
