//
//  AddEpisodeFavoriteTombstoneTable.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 10/10/26.
//

import Foundation
import SQLiteMigrationManager
import SQLite

private typealias Expression = SQLite.Expression

/// Remembers when an episode was unfavorited, so iCloud sync can tell that apart from
/// an older favorite still on another device. A separate migration from
/// `AddEpisodeSyncTombstoneTables` because beta builds have already run that one.
struct AddEpisodeFavoriteTombstoneTable: Migration {

    var version: Int64 = 2026_10_10_10_00_00

    private var episodeFavoriteTombstone = Table("episodeFavoriteTombstone")

    func migrateDatabase(_ db: Connection) throws {
        let episodeId = Expression<String>("episodeId")
        let unfavoritedAt = Expression<Date>("unfavoritedAt")

        try db.run(episodeFavoriteTombstone.create(ifNotExists: true) { t in
            t.column(episodeId, primaryKey: true)
            t.column(unfavoritedAt)
        })
    }
}
