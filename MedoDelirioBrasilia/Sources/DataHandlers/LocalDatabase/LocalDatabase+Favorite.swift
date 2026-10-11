import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    func favoriteCount() throws -> Int {
        try db.scalar(favorite.count)
    }
    
    func insert(favorite newFavorite: Favorite) throws {
        let insert = try favorite.insert(newFavorite)
        try db.run(insert)
    }
    
    func favorites() throws -> [Favorite] {
        var queriedFavorites = [Favorite]()

        for queriedFavorite in try db.prepare(favorite) {
            queriedFavorites.append(try queriedFavorite.decode())
        }
        return queriedFavorites
    }
    
    func deleteAllFavorites() throws {
        try db.run(favorite.delete())
    }

    func deleteFavorite(withId contentId: String) throws {
        let id = Expression<String>("contentId")
        let specificFavorite = favorite.filter(id == contentId)
        if try db.run(specificFavorite.delete()) == 0 {
            throw LocalDatabaseError.favoriteNotFound
        }
    }

    func isFavorite(contentId: String) throws -> Bool {
        let id = Expression<String>("contentId")
        let query = favorite.filter(id == contentId)
        let count = try db.scalar(query.count)
        return count > 0
    }

    // MARK: - iCloud Sync

    func allFavoriteDates() throws -> [String: Date] {
        let contentId = Expression<String>("contentId")
        let dateAdded = Expression<Date>("dateAdded")

        var result = [String: Date]()
        for row in try db.prepare(favorite) {
            result[row[contentId]] = row[dateAdded]
        }
        return result
    }

    /// Replaces rather than failing on an existing row, so a newer favorite from another
    /// device updates the date.
    func upsertFavorite(contentId: String, dateAdded: Date) throws {
        let contentIdCol = Expression<String>("contentId")
        let dateAddedCol = Expression<Date>("dateAdded")
        try db.run(favorite.insert(or: .replace,
            contentIdCol <- contentId,
            dateAddedCol <- dateAdded
        ))
    }

    func allFavoriteTombstones() throws -> [String: Date] {
        let contentId = Expression<String>("contentId")
        let unfavoritedAt = Expression<Date>("unfavoritedAt")

        var result = [String: Date]()
        for row in try db.prepare(favoriteTombstoneTable) {
            result[row[contentId]] = row[unfavoritedAt]
        }
        return result
    }

    func upsertFavoriteTombstone(contentId: String, unfavoritedAt: Date) throws {
        let contentIdCol = Expression<String>("contentId")
        let unfavoritedAtCol = Expression<Date>("unfavoritedAt")
        try db.run(favoriteTombstoneTable.insert(or: .replace,
            contentIdCol <- contentId,
            unfavoritedAtCol <- unfavoritedAt
        ))
    }

    func deleteFavoriteTombstone(contentId: String) throws {
        let contentIdCol = Expression<String>("contentId")
        try db.run(favoriteTombstoneTable.filter(contentIdCol == contentId).delete())
    }

    func deleteFavoriteTombstones(olderThan date: Date) throws {
        let unfavoritedAt = Expression<Date>("unfavoritedAt")
        try db.run(favoriteTombstoneTable.filter(unfavoritedAt < date).delete())
    }
}
