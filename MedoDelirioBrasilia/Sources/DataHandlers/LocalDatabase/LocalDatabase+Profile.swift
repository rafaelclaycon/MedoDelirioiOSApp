//
//  LocalDatabase+Profile.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    /// The oldest thing this device remembers the user doing: a share, a play, a
    /// favorite or an episode listen. Stands in for "Com a gente desde", since the app
    /// never stored when it was first opened. Favorites synced from another device
    /// bring that device's dates along, which is what we want here.
    func earliestActivityDate() throws -> Date? {
        let dateTime = Expression<Date>("dateTime")
        let dateAdded = Expression<Date>("dateAdded")
        let startedAt = Expression<Date>("startedAt")

        let candidates: [Date?] = [
            try db.scalar(userShareLog.select(dateTime.min)),
            try db.scalar(userPlayLogTable.select(dateTime.min)),
            try db.scalar(favorite.select(dateAdded.min)),
            try db.scalar(episodeListenLogTable.select(startedAt.min))
        ]
        return candidates.compactMap { $0 }.min()
    }
}
