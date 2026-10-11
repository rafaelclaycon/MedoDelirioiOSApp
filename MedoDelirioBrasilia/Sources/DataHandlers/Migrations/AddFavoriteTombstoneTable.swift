//
//  AddFavoriteTombstoneTable.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Foundation
import SQLiteMigrationManager
import SQLite

private typealias Expression = SQLite.Expression

/// Remembers when a sound or song was unfavorited, so iCloud sync can tell that apart
/// from an older favorite still on another device. Like `episodeFavoriteTombstone`.
struct AddFavoriteTombstoneTable: Migration {

    var version: Int64 = 2026_10_11_12_00_00

    private var favoriteTombstone = Table("favoriteTombstone")

    func migrateDatabase(_ db: Connection) throws {
        let contentId = Expression<String>("contentId")
        let unfavoritedAt = Expression<Date>("unfavoritedAt")

        try db.run(favoriteTombstone.create(ifNotExists: true) { t in
            t.column(contentId, primaryKey: true)
            t.column(unfavoritedAt)
        })
    }
}
