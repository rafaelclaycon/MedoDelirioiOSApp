//
//  LocalDatabase+EpisodeProgress.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/02/26.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    func allEpisodeProgress() throws -> [String: (currentTime: Double, duration: Double, updatedAt: Date)] {
        let episodeId = Expression<String>("episodeId")
        let currentTime = Expression<Double>("currentTime")
        let duration = Expression<Double>("duration")
        let updatedAt = Expression<Date>("updatedAt")

        var result = [String: (currentTime: Double, duration: Double, updatedAt: Date)]()
        for row in try db.prepare(episodeProgressTable) {
            result[row[episodeId]] = (currentTime: row[currentTime], duration: row[duration], updatedAt: row[updatedAt])
        }
        return result
    }

    func upsertEpisodeProgress(episodeId: String, currentTime: Double, duration: Double, updatedAt: Date) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let currentTimeCol = Expression<Double>("currentTime")
        let durationCol = Expression<Double>("duration")
        let updatedAtCol = Expression<Date>("updatedAt")

        try db.run(episodeProgressTable.insert(or: .replace,
            episodeIdCol <- episodeId,
            currentTimeCol <- currentTime,
            durationCol <- duration,
            updatedAtCol <- updatedAt
        ))
    }

    func deleteEpisodeProgress(episodeId: String) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let row = episodeProgressTable.filter(episodeIdCol == episodeId)
        try db.run(row.delete())
    }

    // MARK: - Tombstones

    func allEpisodeProgressTombstones() throws -> [String: Date] {
        let episodeId = Expression<String>("episodeId")
        let clearedAt = Expression<Date>("clearedAt")

        var result = [String: Date]()
        for row in try db.prepare(episodeProgressTombstoneTable) {
            result[row[episodeId]] = row[clearedAt]
        }
        return result
    }

    func upsertEpisodeProgressTombstone(episodeId: String, clearedAt: Date) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let clearedAtCol = Expression<Date>("clearedAt")

        try db.run(episodeProgressTombstoneTable.insert(or: .replace,
            episodeIdCol <- episodeId,
            clearedAtCol <- clearedAt
        ))
    }

    func deleteEpisodeProgressTombstone(episodeId: String) throws {
        let episodeIdCol = Expression<String>("episodeId")
        let row = episodeProgressTombstoneTable.filter(episodeIdCol == episodeId)
        try db.run(row.delete())
    }

    func deleteEpisodeProgressTombstones(olderThan date: Date) throws {
        let clearedAt = Expression<Date>("clearedAt")
        try db.run(episodeProgressTombstoneTable.filter(clearedAt < date).delete())
    }
}
