//
//  AddFeaturedRankFieldToAuthorTable.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/10/26.
//

import Foundation
import SQLiteMigrationManager
import SQLite

private typealias Expression = SQLite.Expression

/// The row of favorite profile photos in Você. Nil for every author until the server
/// sends a position, with the next content update for that author.
struct AddFeaturedRankFieldToAuthorTable: Migration {

    var version: Int64 = 2026_10_15_12_00_00

    private var author = Table("author")

    func migrateDatabase(_ db: Connection) throws {
        let featuredRank = Expression<Int?>("featuredRank")
        try db.run(author.addColumn(featuredRank))
    }
}
