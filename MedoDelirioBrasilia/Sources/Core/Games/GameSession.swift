//
//  GameSession.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation

/// One play-through: which round is up, what was picked and the score so far.
@Observable
@MainActor
final class GameSession {

    let kind: GameKind
    /// New for every play-through, including "Jogar de novo", so views can tell a new
    /// game from rounds being swapped within one.
    private(set) var gameID = UUID()
    private(set) var rounds: [GameRound]
    /// Rounds kept aside to stand in for one that can't be played, like a photo that no
    /// longer loads.
    private(set) var spares: [GameRound]
    private(set) var index = 0
    private(set) var hits = 0
    private(set) var points = 0
    /// The author picked in the current round; nil until the user answers.
    private(set) var pickedID: String?
    /// When the current round's prompt became visible. Time, and so points, count from
    /// here, not from when the round began: a photo still loading isn't the player's
    /// delay. Nil until `startClock`.
    private(set) var roundStartedAt: Date?
    /// What the current round earned, once answered.
    private(set) var roundPoints: Int?
    /// Seconds from prompt to answer, for each answered round whose clock had started.
    private(set) var answerTimes: [TimeInterval] = []

    var averageAnswerSeconds: Double? {
        guard !answerTimes.isEmpty else { return nil }
        return answerTimes.reduce(0, +) / Double(answerTimes.count)
    }

    /// What the game is scored by: points for the face game, right answers otherwise.
    var score: Int {
        kind.scoring == .points ? points : hits
    }

    private let length: Int

    /// The first `length` rounds are played; the rest are spares.
    init(kind: GameKind, rounds: [GameRound], length: Int = GameRoundFactory.roundCount) {
        self.kind = kind
        self.length = length
        self.rounds = Array(rounds.prefix(length))
        self.spares = Array(rounds.dropFirst(length))
    }

    var current: GameRound? {
        rounds.indices.contains(index) ? rounds[index] : nil
    }

    var isRevealed: Bool { pickedID != nil }
    var isFinished: Bool { !rounds.isEmpty && index >= rounds.count }
    var isLastRound: Bool { index == rounds.count - 1 }

    var pickedCorrectly: Bool {
        guard let pickedID, let current else { return false }
        return pickedID == current.answer.id
    }

    /// Starts timing the current round. Only the first call counts, and only before
    /// it's answered.
    func startClock(at date: Date = .now) {
        guard roundStartedAt == nil, !isRevealed, current != nil else { return }
        roundStartedAt = date
    }

    /// Only the first pick in a round counts. Returns whether it was right. A right
    /// pick earns points by how long it took since `startClock`; one made before the
    /// clock started (the photo never showed) earns the minimum.
    @discardableResult
    func pick(_ author: Author, at date: Date = .now) -> Bool {
        guard pickedID == nil, let current else { return false }
        pickedID = author.id
        if let roundStartedAt {
            answerTimes.append(max(0, date.timeIntervalSince(roundStartedAt)))
        }
        let isRight = author.id == current.answer.id
        if isRight {
            hits += 1
            let elapsed = roundStartedAt.map { date.timeIntervalSince($0) } ?? GameScoring.revealDuration
            let earned = GameScoring.points(afterElapsed: elapsed)
            roundPoints = earned
            points += earned
        } else {
            roundPoints = 0
        }
        return isRight
    }

    /// Moves to the next round, or past the last one, which finishes the game.
    func advance() {
        guard isRevealed else { return }
        pickedID = nil
        roundStartedAt = nil
        roundPoints = nil
        index += 1
    }

    /// Swaps a round that hasn't been answered for a spare. With no spares left, drops
    /// it, which makes the game shorter. Returns whether anything changed.
    @discardableResult
    func replaceRound(id: GameRound.ID) -> Bool {
        guard let position = rounds.firstIndex(where: { $0.id == id }) else { return false }
        let isAnswered = position < index || (position == index && isRevealed)
        guard !isAnswered else { return false }

        if spares.isEmpty {
            rounds.remove(at: position)
        } else {
            rounds[position] = spares.removeFirst()
        }
        // A swapped current round starts over, clock included.
        if position == index {
            roundStartedAt = nil
        }
        return true
    }

    func restart(with rounds: [GameRound]) {
        gameID = UUID()
        self.rounds = Array(rounds.prefix(length))
        spares = Array(rounds.dropFirst(length))
        index = 0
        hits = 0
        points = 0
        pickedID = nil
        roundStartedAt = nil
        roundPoints = nil
        answerTimes = []
    }
}
