//
//  LocalDatabase+GameResult.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    private var gameIdCol: Expression<String> { Expression<String>("id") }
    private var gameKindCol: Expression<String> { Expression<String>("gameKind") }
    private var gameFinishedAtCol: Expression<Date> { Expression<Date>("finishedAt") }
    private var gameRoundsCol: Expression<Int> { Expression<Int>("rounds") }
    private var gameHitsCol: Expression<Int> { Expression<Int>("hits") }
    private var gamePointsCol: Expression<Int> { Expression<Int>("points") }
    private var gameAverageAnswerCol: Expression<Double?> { Expression<Double?>("averageAnswerSeconds") }
    private var gameAppVersionCol: Expression<String> { Expression<String>("appVersion") }

    func insert(gameResult result: GameResult) throws {
        try db.run(gameResultTable.insert(
            gameIdCol <- result.id,
            gameKindCol <- result.gameKind,
            gameFinishedAtCol <- result.finishedAt,
            gameRoundsCol <- result.rounds,
            gameHitsCol <- result.hits,
            gamePointsCol <- result.points,
            gameAverageAnswerCol <- result.averageAnswerSeconds,
            gameAppVersionCol <- result.appVersion
        ))
    }

    /// Newest first.
    func gameResults(forKind gameKind: String) throws -> [GameResult] {
        let query = gameResultTable
            .filter(gameKindCol == gameKind)
            .order(gameFinishedAtCol.desc)
        return try db.prepare(query).map(gameResult(from:))
    }

    func deleteAllGameResults() throws {
        try db.run(gameResultTable.delete())
    }

    private func gameResult(from row: Row) -> GameResult {
        GameResult(
            id: row[gameIdCol],
            gameKind: row[gameKindCol],
            finishedAt: row[gameFinishedAtCol],
            rounds: row[gameRoundsCol],
            hits: row[gameHitsCol],
            points: row[gamePointsCol],
            averageAnswerSeconds: row[gameAverageAnswerCol],
            appVersion: row[gameAppVersionCol]
        )
    }
}
