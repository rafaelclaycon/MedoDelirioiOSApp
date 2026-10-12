//
//  AddGameResultTable.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation
import SQLiteMigrationManager
import SQLite

private typealias Expression = SQLite.Expression

struct AddGameResultTable: Migration {

    var version: Int64 = 2026_10_12_12_00_00

    private var gameResult = Table("gameResult")

    func migrateDatabase(_ db: Connection) throws {
        let id = Expression<String>("id")
        let gameKind = Expression<String>("gameKind")
        let finishedAt = Expression<Date>("finishedAt")
        let rounds = Expression<Int>("rounds")
        let hits = Expression<Int>("hits")
        let points = Expression<Int>("points")
        let averageAnswerSeconds = Expression<Double?>("averageAnswerSeconds")
        let appVersion = Expression<String>("appVersion")

        try db.run(gameResult.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(gameKind)
            t.column(finishedAt)
            t.column(rounds)
            t.column(hits)
            t.column(points)
            t.column(averageAnswerSeconds)
            t.column(appVersion)
        })

        // Everything planned on top of this (best games, recent games) reads one game
        // at a time.
        try db.run(gameResult.createIndex(gameKind, ifNotExists: true))
    }
}
