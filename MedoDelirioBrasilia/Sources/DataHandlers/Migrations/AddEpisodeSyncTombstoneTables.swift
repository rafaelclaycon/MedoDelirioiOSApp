//
//  AddEpisodeSyncTombstoneTables.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Foundation
import SQLiteMigrationManager
import SQLite

private typealias Expression = SQLite.Expression

/// Clearing progress or unmarking an episode as played deletes its row, which leaves
/// nothing to compare against when another device's older copy arrives over iCloud.
/// These tables remember when that happened so the deletion wins the merge.
struct AddEpisodeSyncTombstoneTables: Migration {

    var version: Int64 = 2026_10_09_10_00_00

    private var episodeProgressTombstone = Table("episodeProgressTombstone")
    private var episodePlayedTombstone = Table("episodePlayedTombstone")

    func migrateDatabase(_ db: Connection) throws {
        let episodeId = Expression<String>("episodeId")
        let clearedAt = Expression<Date>("clearedAt")
        let unmarkedAt = Expression<Date>("unmarkedAt")

        try db.run(episodeProgressTombstone.create(ifNotExists: true) { t in
            t.column(episodeId, primaryKey: true)
            t.column(clearedAt)
        })

        try db.run(episodePlayedTombstone.create(ifNotExists: true) { t in
            t.column(episodeId, primaryKey: true)
            t.column(unmarkedAt)
        })
    }
}
