//
//  LocalDatabase+EpisodePlayed.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/02/26.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    func allEpisodePlayedIDs() throws -> Set<String> {
        let episodeId = Expression<String>("episodeId")
        var ids = Set<String>()
        for row in try db.prepare(episodePlayedTable.select(episodeId)) {
            ids.insert(row[episodeId])
        }
        return ids
    }

    func allEpisodePlayedDates() throws -> [String: Date] {
        let episodeId = Expression<String>("episodeId")
        let dateMarked = Expression<Date>("dateMarked")

        var result = [String: Date]()
        for row in try db.prepare(episodePlayedTable) {
            result[row[episodeId]] = row[dateMarked]
        }
        return result
    }

    func insertEpisodePlayed(episodeId: String, dateMarked: Date) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let dateMarkedCol = Expression<Date>("dateMarked")
        // Replace rather than ignore, so a newer mark from another device updates the date.
        try db.run(episodePlayedTable.insert(or: .replace,
            episodeIdCol <- episodeId,
            dateMarkedCol <- dateMarked
        ))
    }

    func deleteEpisodePlayed(episodeId: String) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let row = episodePlayedTable.filter(episodeIdCol == episodeId)
        try db.run(row.delete())
    }

    // MARK: - Tombstones

    func allEpisodePlayedTombstones() throws -> [String: Date] {
        let episodeId = Expression<String>("episodeId")
        let unmarkedAt = Expression<Date>("unmarkedAt")

        var result = [String: Date]()
        for row in try db.prepare(episodePlayedTombstoneTable) {
            result[row[episodeId]] = row[unmarkedAt]
        }
        return result
    }

    func upsertEpisodePlayedTombstone(episodeId: String, unmarkedAt: Date) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let unmarkedAtCol = Expression<Date>("unmarkedAt")

        try db.run(episodePlayedTombstoneTable.insert(or: .replace,
            episodeIdCol <- episodeId,
            unmarkedAtCol <- unmarkedAt
        ))
    }

    func deleteEpisodePlayedTombstone(episodeId: String) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let row = episodePlayedTombstoneTable.filter(episodeIdCol == episodeId)
        try db.run(row.delete())
    }

    func deleteEpisodePlayedTombstones(olderThan date: Date) throws {
        let unmarkedAt = Expression<Date>("unmarkedAt")
        try db.run(episodePlayedTombstoneTable.filter(unmarkedAt < date).delete())
    }
}
