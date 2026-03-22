//
//  LocalDatabase+Song.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/09/23.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

private enum SongColumns {
    static let id = Expression<String>("id")
    static let title = Expression<String>("title")
    static let description = Expression<String>("description")
    static let genreId = Expression<String>("genreId")
    static let duration = Expression<Double>("duration")
    static let filename = Expression<String>("filename")
    static let dateAdded = Expression<String?>("dateAdded")
    static let isOffensive = Expression<Bool>("isOffensive")
    static let isFromServer = Expression<Bool?>("isFromServer")
}

extension LocalDatabase {

    func insert(song newSong: Song) throws {
        let insert = try songTable.insert(newSong)
        try db.run(insert)
    }

    func songs(allowSensitive: Bool) throws -> [Song] {
        var queriedGenres = [Song]()

        let genreId = Expression<String>("genreId")
        let genreTableId = Expression<String>("id")
        let genreName = Expression<String>("name")
        let isOffensive = Expression<Bool>("isOffensive")

        var query = songTable
            .select(songTable[*], musicGenreTable[genreName])
            .join(musicGenreTable, on: songTable[genreId] == musicGenreTable[genreTableId])

        if !allowSensitive {
            query = query.filter(isOffensive == false)
        }

        for row in try db.prepare(query) {
            queriedGenres.append(try song(from: row, genreName: row[musicGenreTable[genreName]]))
        }
        return queriedGenres
    }

    func songCount() throws -> Int {
        try db.scalar(songTable.count)
    }

    func song(withId songId: String) throws -> Song? {
        var queriedSongs = [Song]()

        let name = Expression<String>("name")
        let genreId = Expression<String>("genreId")
        let id = Expression<String>("id")

        let query = songTable
            .select(songTable[*], musicGenreTable[name])
            .join(musicGenreTable, on: songTable[genreId] == musicGenreTable[id])
            .filter(songTable[id] == songId)

        for row in try db.prepare(query) {
            queriedSongs.append(try song(from: row, genreName: row[musicGenreTable[name]]))
        }
        return queriedSongs.first
    }

    func update(song updatedSong: Song) throws {
        let id = Expression<String>("id")
        let query = songTable.filter(id == updatedSong.id)
        let updateQuery = query.update(
            Expression<String>("title") <- updatedSong.title,
            Expression<String>("description") <- updatedSong.description,
            Expression<String>("genreId") <- updatedSong.genreId,
            Expression<Double>("duration") <- updatedSong.duration,
            Expression<Bool>("isOffensive") <- updatedSong.isOffensive
        )
        try db.run(updateQuery)
    }

    func delete(songId: String) throws {
        let id = Expression<String>("id")

        let query = songTable.filter(id == songId)
        let count = try db.scalar(query.count)

        if count != 0 {
            try db.run(query.delete())
        } else {
            throw LocalDatabaseError.songNotFound
        }
    }

    func setIsFromServer(to value: Bool, onSongId songId: String) throws {
        let id = Expression<String>("id")
        let query = songTable.filter(id == songId)
        let updateQuery = query.update(
            Expression<Bool>("isFromServer") <- value
        )
        try db.run(updateQuery)
    }

    func songs(withIds songIds: [String]) throws -> [Song] {
        var queriedSongs = [String: Song]()

        let genreId = Expression<String>("genreId")
        let id = Expression<String>("id")
        let name = Expression<String>("name")

        let query = songTable
            .select(songTable[*], musicGenreTable[name])
            .join(musicGenreTable, on: songTable[genreId] == musicGenreTable[id])
            .filter(songIds.contains(songTable[id]))

        for row in try db.prepare(query) {
            let song = try song(from: row, genreName: row[musicGenreTable[name]])
            queriedSongs[song.id] = song
        }

        var orderedSongs = [Song]()
        for songId in songIds {
            if let song = queriedSongs[songId] {
                orderedSongs.append(song)
            }
        }

        return orderedSongs
    }
}

private extension LocalDatabase {

    func song(from row: Row, genreName: String) throws -> Song {
        Song(
            id: row[SongColumns.id],
            title: row[SongColumns.title],
            description: row[SongColumns.description],
            genreId: row[SongColumns.genreId],
            genreName: genreName,
            duration: row[SongColumns.duration],
            filename: row[SongColumns.filename],
            dateAdded: parseLocalDatabaseDate(row[SongColumns.dateAdded]) ?? Date(),
            isOffensive: row[SongColumns.isOffensive],
            isFromServer: try row.get(SongColumns.isFromServer)
        )
    }

}
