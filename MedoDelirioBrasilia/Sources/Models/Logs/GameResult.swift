//
//  GameResult.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation

/// One finished game, kept on the device. Nothing reads these yet: they're recorded
/// from the start so a personal ranking, stats or achievements can draw on every game
/// ever played, not just the ones after the feature ships.
struct GameResult: Hashable, Identifiable {

    let id: String
    /// `GameKind.rawValue`.
    let gameKind: String
    let finishedAt: Date
    /// Usually ten; fewer when rounds were dropped for photos that wouldn't load.
    let rounds: Int
    let hits: Int
    /// The face game's score. Recorded for every game, since the clock runs in both.
    let points: Int
    /// Mean seconds from a prompt showing to the answer, over the rounds where the
    /// clock started. Nil if it never did.
    let averageAnswerSeconds: Double?
    /// Scoring can change between versions, as the face game's did; this tells old
    /// results apart.
    let appVersion: String

    init(
        id: String = UUID().uuidString,
        gameKind: String,
        finishedAt: Date,
        rounds: Int,
        hits: Int,
        points: Int,
        averageAnswerSeconds: Double?,
        appVersion: String
    ) {
        self.id = id
        self.gameKind = gameKind
        self.finishedAt = finishedAt
        self.rounds = rounds
        self.hits = hits
        self.points = points
        self.averageAnswerSeconds = averageAnswerSeconds
        self.appVersion = appVersion
    }

    /// The score it would be ranked by, in its game's unit.
    var score: Int {
        GameKind(rawValue: gameKind)?.scoring == .points ? points : hits
    }
}

extension GameResult {

    @MainActor
    init(session: GameSession, finishedAt: Date = .now, appVersion: String = Versioneer.appVersion) {
        self.init(
            gameKind: session.kind.rawValue,
            finishedAt: finishedAt,
            rounds: session.rounds.count,
            hits: session.hits,
            points: session.points,
            averageAnswerSeconds: session.averageAnswerSeconds,
            appVersion: appVersion
        )
    }
}
