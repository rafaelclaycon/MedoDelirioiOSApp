//
//  LocalDatabase+PlayLog.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    private var playIdCol: Expression<String> { Expression<String>("id") }
    private var playContentIdCol: Expression<String> { Expression<String>("contentId") }
    private var playContentTypeCol: Expression<Int> { Expression<Int>("contentType") }
    private var playDateTimeCol: Expression<Date> { Expression<Date>("dateTime") }
    private var playIsAutoplayCol: Expression<Bool> { Expression<Bool>("isAutoplay") }
    private var playSentToServerCol: Expression<Bool> { Expression<Bool>("sentToServer") }

    func insert(userPlayLog newLog: UserPlayLog) throws {
        try db.run(userPlayLogTable.insert(
            playIdCol <- newLog.id,
            playContentIdCol <- newLog.contentId,
            playContentTypeCol <- newLog.contentType,
            playDateTimeCol <- newLog.dateTime,
            playIsAutoplayCol <- newLog.isAutoplay,
            playSentToServerCol <- newLog.sentToServer
        ))
    }

    /// Oldest first, so an upload cut short by a failure always leaves the newest plays
    /// for next time rather than skipping over old ones.
    func pendingPlayLogsNotSentToServer(limit: Int) throws -> [UserPlayLog] {
        let query = userPlayLogTable
            .filter(playSentToServerCol == false)
            .order(playDateTimeCol.asc)
            .limit(limit)
        return try db.prepare(query).map(playLog(from:))
    }

    func markUserPlayLogsAsSent(logIds: [String]) throws {
        guard !logIds.isEmpty else { return }
        let logsToUpdate = userPlayLogTable.filter(logIds.contains(playIdCol))
        try db.run(logsToUpdate.update(playSentToServerCol <- true))
    }

    func allUserPlayLogs() throws -> [UserPlayLog] {
        try db.prepare(userPlayLogTable.order(playDateTimeCol.desc)).map(playLog(from:))
    }

    func deleteAllUserPlayLogs() throws {
        try db.run(userPlayLogTable.delete())
    }

    // MARK: - Personal Stats in a Date Range

    // Seu Mês and the Retrospectiva. Sounds a person tapped: songs aren't Vírgulas, and
    // autoplay would let a folder played back to back take over the ranking.

    func topSoundsPlayedByTheUser(in interval: DateInterval, limit: Int) throws -> [TopChartItem] {
        let soundId = Expression<String>("id")
        let soundTitle = Expression<String>("title")
        let authorIdOnSounds = Expression<String>("authorId")

        let authorId = Expression<String>("id")
        let authorName = Expression<String>("name")

        let playCount = playContentIdCol.count
        return try db.prepare(
            tappedSoundPlays(in: interval)
                .join(soundTable, on: userPlayLogTable[playContentIdCol] == soundTable[soundId])
                .join(author, on: soundTable[authorIdOnSounds] == author[authorId])
                .select(userPlayLogTable[playContentIdCol], soundTable[soundTitle], soundTable[authorId], author[authorName], playCount)
                .group(userPlayLogTable[playContentIdCol])
                .order(playCount.desc)
                .limit(limit)
        ).map { row in
            TopChartItem(
                id: "",
                rankNumber: "",
                contentId: row[userPlayLogTable[playContentIdCol]],
                contentName: row[soundTable[soundTitle]],
                contentAuthorId: row[soundTable[authorId]],
                contentAuthorName: row[author[authorName]],
                shareCount: row[playCount]
            )
        }
    }

    func playDates(in interval: DateInterval) throws -> [Date] {
        try db.prepare(tappedSoundPlays(in: interval).select(userPlayLogTable[playDateTimeCol]))
            .map { $0[userPlayLogTable[playDateTimeCol]] }
    }

    private func tappedSoundPlays(in interval: DateInterval) -> Table {
        userPlayLogTable
            .filter(userPlayLogTable[playContentTypeCol] == ContentType.sound.rawValue)
            .filter(userPlayLogTable[playIsAutoplayCol] == false)
            .filter(userPlayLogTable[playDateTimeCol] >= interval.start && userPlayLogTable[playDateTimeCol] < interval.end)
    }

    private func playLog(from row: Row) -> UserPlayLog {
        UserPlayLog(
            id: row[playIdCol],
            contentId: row[playContentIdCol],
            contentType: row[playContentTypeCol],
            dateTime: row[playDateTimeCol],
            isAutoplay: row[playIsAutoplayCol],
            sentToServer: row[playSentToServerCol]
        )
    }
}
