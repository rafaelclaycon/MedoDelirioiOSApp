//
//  LocalDatabase+UpdateEvent.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/05/23.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {
    
    func insert(updateEvent newUpdateEvent: UpdateEvent) throws {
        let insert = try updateEventTable.insert(newUpdateEvent)
        try db.run(insert)
    }
    
    func markAsSucceeded(updateEventId: UUID) throws {
        let did_succeed_column = Expression<Bool>("didSucceed")
        let update_event_id_column = Expression<UUID>("id")
        
        let updateQuery = updateEventTable
            .filter(update_event_id_column == updateEventId)
            .update(did_succeed_column <- true)
        
        try db.run(updateQuery)
    }
    
    func unsuccessfulUpdates() throws -> [UpdateEvent] {
        var queriedItems = [UpdateEvent]()
        
        let id = Expression<UUID>("id")
        let content_id = Expression<String>("contentId")
        let date_time = Expression<String>("dateTime")
        let media_type = Expression<Int>("mediaType")
        let event_type = Expression<Int>("eventType")
        let did_succeed = Expression<Bool>("didSucceed")
        
        for row in try db.prepare(updateEventTable) {
            let updateEvent = UpdateEvent(
                id: row[id],
                contentId: row[content_id],
                dateTime: row[date_time],
                mediaType: MediaType(rawValue: row[media_type]) ?? .sound,
                eventType: EventType(rawValue: row[event_type]) ?? .metadataUpdated,
                didSucceed: row[did_succeed]
            )

            if !(updateEvent.didSucceed ?? false) {
                queriedItems.append(updateEvent)
            }
        }
        return queriedItems
    }

    func exists(withId updateEventId: UUID) throws -> Bool {
        let id = Expression<UUID>("id")
        let query = updateEventTable.filter(id == updateEventId)
        let count = try db.scalar(query.count)
        return count > 0
    }

    /// Event dates share the server's ISO 8601 format, so comparing them as strings orders them by time.
    func hasDeletionEvent(forContentId contentId: String, after dateTime: String) throws -> Bool {
        let content_id = Expression<String>("contentId")
        let date_time = Expression<String>("dateTime")
        let event_type = Expression<Int>("eventType")
        let query = updateEventTable.filter(
            content_id == contentId
            && event_type == EventType.deleted.rawValue
            && date_time > dateTime
        )
        return try db.scalar(query.count) > 0
    }

    func dateTimeOfLastUpdate() -> String {
        let dateTimeColumn = Expression<String>("dateTime")
        let query = updateEventTable.order(dateTimeColumn.desc).select(dateTimeColumn).limit(1)
        do {
            if let row = try db.prepare(query).compactMap({ $0 }).first {
                return row[dateTimeColumn]
            } else {
                return "all"
            }
        } catch {
            print("Error: \(error)")
            return "all"
        }
    }
}
