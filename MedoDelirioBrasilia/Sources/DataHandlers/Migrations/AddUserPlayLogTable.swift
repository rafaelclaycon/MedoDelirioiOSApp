//
//  AddUserPlayLogTable.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Foundation
import SQLiteMigrationManager
import SQLite

private typealias Expression = SQLite.Expression

struct AddUserPlayLogTable: Migration {

    var version: Int64 = 2026_10_06_12_00_00

    private var userPlayLog = Table("userPlayLog")

    func migrateDatabase(_ db: Connection) throws {
        let id = Expression<String>("id")
        let contentId = Expression<String>("contentId")
        let contentType = Expression<Int>("contentType")
        let dateTime = Expression<Date>("dateTime")
        let isAutoplay = Expression<Bool>("isAutoplay")
        let sentToServer = Expression<Bool>("sentToServer")

        try db.run(userPlayLog.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(contentId)
            t.column(contentType)
            t.column(dateTime)
            t.column(isAutoplay)
            t.column(sentToServer)
        })

        // The upload reads only the unsent rows, which become a small slice of the
        // table once it has been in use for a while.
        try db.run(userPlayLog.createIndex(sentToServer, ifNotExists: true))
    }
}
