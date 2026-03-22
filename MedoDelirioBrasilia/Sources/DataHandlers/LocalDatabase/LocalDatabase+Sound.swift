//
//  LocalDatabase+Sound.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 28/04/23.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

private enum SoundColumns {
    static let id = Expression<String>("id")
    static let title = Expression<String>("title")
    static let authorId = Expression<String>("authorId")
    static let description = Expression<String>("description")
    static let filename = Expression<String>("filename")
    static let dateAdded = Expression<String?>("dateAdded")
    static let duration = Expression<Double>("duration")
    static let isOffensive = Expression<Bool>("isOffensive")
    static let isFromServer = Expression<Bool?>("isFromServer")
}

extension LocalDatabase {

    func soundCount() throws -> Int {
        try db.scalar(soundTable.count)
    }

    func insert(sound newSound: Sound) throws {
        let insert = try soundTable.insert(newSound)
        try db.run(insert)
    }

    func sounds(
        allowSensitive: Bool
    ) throws -> [Sound] {
        var queriedSounds = [Sound]()

        let authorId = Expression<String>("authorId")
        let authorTableId = Expression<String>("id")
        let authorName = Expression<String>("name")
        let isOffensive = Expression<Bool>("isOffensive")

        var query = soundTable
            .select(soundTable[*], author[authorName])
            .join(author, on: soundTable[authorId] == author[authorTableId])

        if !allowSensitive {
            query = query.filter(isOffensive == false)
        }

        for row in try db.prepare(query) {
            queriedSounds.append(try sound(from: row, authorName: row[author[authorName]]))
        }
        return queriedSounds
    }

    func sound(withId soundId: String) throws -> Sound? {
        var queriedSounds = [Sound]()

        let authorId = Expression<String>("authorId")
        let authorTableId = Expression<String>("id")
        let authorName = Expression<String>("name")
        let id = Expression<String>("id")

        let query = soundTable
            .select(soundTable[*], author[authorName])
            .join(author, on: soundTable[authorId] == author[authorTableId])
            .filter(soundTable[id] == soundId)

        for row in try db.prepare(query) {
            queriedSounds.append(try sound(from: row, authorName: row[author[authorName]]))
        }
        return queriedSounds.first
    }

    func sounds(withIds soundIds: [String]) throws -> [Sound] {
        var queriedSounds = [String: Sound]()

        let authorId = Expression<String>("authorId")
        let authorTableId = Expression<String>("id")
        let authorName = Expression<String>("name")
        let id = Expression<String>("id")

        let query = soundTable
            .select(soundTable[*], author[authorName])
            .join(author, on: soundTable[authorId] == author[authorTableId])
            .filter(soundIds.contains(soundTable[id]))

        for row in try db.prepare(query) {
            let sound = try sound(from: row, authorName: row[author[authorName]])
            queriedSounds[sound.id] = sound
        }

        var orderedSounds = [Sound]()
        for soundId in soundIds {
            if let sound = queriedSounds[soundId] {
                orderedSounds.append(sound)
            }
        }

        return orderedSounds
    }

    func allSounds(
        forAuthor authorId: String,
        isSensitiveContentAllowed: Bool
    ) throws -> [Sound] {
        var queriedSounds = [Sound]()

        let soundAuthorId = Expression<String>("authorId")
        let authorTableId = Expression<String>("id")
        let authorName = Expression<String>("name")
        let isOffensive = Expression<Bool>("isOffensive")

        var query = soundTable
            .select(soundTable[*], author[authorName])
            .join(author, on: soundTable[soundAuthorId] == author[authorTableId])
            .filter(soundAuthorId == authorId)

        if !isSensitiveContentAllowed {
            query = query.filter(isOffensive == false)
        }

        for row in try db.prepare(query) {
            queriedSounds.append(try sound(from: row, authorName: row[author[authorName]]))
        }
        return queriedSounds
    }

//    func update(sound updatedSound: Sound) throws {
//        let id = Expression<String>("id")
//        let filter = sound.filter(id == updatedSound.id)
//        let update = try filter.update(updatedSound)
//        try db.run(update)
//    }

    func update(sound updatedSound: Sound) throws {
        let id = Expression<String>("id")
        let query = soundTable.filter(id == updatedSound.id)
        let updateQuery = query.update(
            Expression<String>("title") <- updatedSound.title,
            Expression<String>("authorId") <- updatedSound.authorId,
            Expression<String>("description") <- updatedSound.description,
            Expression<Double>("duration") <- updatedSound.duration,
            Expression<Bool>("isOffensive") <- updatedSound.isOffensive
        )

        try db.run(updateQuery)
    }

    func delete(soundId: String) throws {
        let id = Expression<String>("id")
        let deleteQuery = soundTable.filter(id == soundId).delete()
        try db.run(deleteQuery)
    }

    func setIsFromServer(to value: Bool, onSoundId soundId: String) throws {
        let id = Expression<String>("id")
        let query = soundTable.filter(id == soundId)
        let updateQuery = query.update(
            Expression<Bool>("isFromServer") <- value
        )
        try db.run(updateQuery)
    }

    func randomSound(
        includeOffensive: Bool
    ) throws -> Sound? {
        let authorId = Expression<String>("authorId")
        let authorTableId = Expression<String>("id")
        let authorName = Expression<String>("name")
        let isOffensive = Expression<Bool>("isOffensive")

        let query = soundTable
            .select(soundTable[*], author[authorName])
            .join(author, on: soundTable[authorId] == author[authorTableId])
            .where(soundTable[isOffensive] == includeOffensive)
            .order(Expression<Void>(literal: "RANDOM()"))
            .limit(1)

        if let row = try db.pluck(query) {
            return try sound(from: row, authorName: row[author[authorName]])
        }
        return nil
    }

    func contentExists(withId contentId: String) throws -> Bool {
        let soundId = Expression<String>("id")
        let soundQuery = soundTable.filter(soundId == contentId)
        let soundCount = try db.scalar(soundQuery.count)

        let songId = Expression<String>("id")
        let songQuery = songTable.filter(songId == contentId)
        let songCount = try db.scalar(songQuery.count)

        return soundCount > 0 || songCount > 0
    }
}

// MARK: - Search

extension LocalDatabase {

    func sounds(matchingDescription searchText: String) throws -> [Sound] {
        var queriedSounds = [Sound]()

        let authorId = Expression<String>("authorId")
        let authorTableId = Expression<String>("id")
        let authorName = Expression<String>("name")
        let description = Expression<String>("description")

        let query = soundTable
            .select(soundTable[*], author[authorName])
            .join(author, on: soundTable[authorId] == author[authorTableId])
            .filter(soundTable[description].like("%\(searchText)%"))

        for row in try db.prepare(query) {
            queriedSounds.append(try sound(from: row, authorName: row[author[authorName]]))
        }

        return queriedSounds
    }
}

private extension LocalDatabase {

    func sound(from row: Row, authorName: String) throws -> Sound {
        Sound(
            id: row[SoundColumns.id],
            title: row[SoundColumns.title],
            authorId: row[SoundColumns.authorId],
            authorName: authorName,
            description: row[SoundColumns.description],
            filename: row[SoundColumns.filename],
            dateAdded: parseLocalDatabaseDate(row[SoundColumns.dateAdded]),
            duration: row[SoundColumns.duration],
            isOffensive: row[SoundColumns.isOffensive],
            isFromServer: try row.get(SoundColumns.isFromServer)
        )
    }

}
