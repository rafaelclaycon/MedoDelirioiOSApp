//
//  LocalDatabase+EpisodeFavorite.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/02/26.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    func allEpisodeFavoriteIDs() throws -> Set<String> {
        let episodeId = Expression<String>("episodeId")
        var ids = Set<String>()
        for row in try db.prepare(episodeFavoriteTable.select(episodeId)) {
            ids.insert(row[episodeId])
        }
        return ids
    }

    func allEpisodeFavoriteDates() throws -> [String: Date] {
        let episodeId = Expression<String>("episodeId")
        let dateAdded = Expression<Date>("dateAdded")

        var result = [String: Date]()
        for row in try db.prepare(episodeFavoriteTable) {
            result[row[episodeId]] = row[dateAdded]
        }
        return result
    }

    func insertEpisodeFavorite(episodeId: String, dateAdded: Date) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let dateAddedCol = Expression<Date>("dateAdded")
        // Replace rather than ignore, so a newer favorite from another device updates the date.
        try db.run(episodeFavoriteTable.insert(or: .replace,
            episodeIdCol <- episodeId,
            dateAddedCol <- dateAdded
        ))
    }

    func deleteEpisodeFavorite(episodeId: String) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let row = episodeFavoriteTable.filter(episodeIdCol == episodeId)
        try db.run(row.delete())
    }

    // MARK: - Tombstones

    func allEpisodeFavoriteTombstones() throws -> [String: Date] {
        let episodeId = Expression<String>("episodeId")
        let unfavoritedAt = Expression<Date>("unfavoritedAt")

        var result = [String: Date]()
        for row in try db.prepare(episodeFavoriteTombstoneTable) {
            result[row[episodeId]] = row[unfavoritedAt]
        }
        return result
    }

    func upsertEpisodeFavoriteTombstone(episodeId: String, unfavoritedAt: Date) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let unfavoritedAtCol = Expression<Date>("unfavoritedAt")

        try db.run(episodeFavoriteTombstoneTable.insert(or: .replace,
            episodeIdCol <- episodeId,
            unfavoritedAtCol <- unfavoritedAt
        ))
    }

    func deleteEpisodeFavoriteTombstone(episodeId: String) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let row = episodeFavoriteTombstoneTable.filter(episodeIdCol == episodeId)
        try db.run(row.delete())
    }

    func deleteEpisodeFavoriteTombstones(olderThan date: Date) throws {
        let unfavoritedAt = Expression<Date>("unfavoritedAt")
        try db.run(episodeFavoriteTombstoneTable.filter(unfavoritedAt < date).delete())
    }
}
