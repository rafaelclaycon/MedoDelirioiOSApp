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
    private(set) var rounds: [GameRound]
    /// Rounds kept aside to stand in for one that can't be played, like a photo that no
    /// longer loads.
    private(set) var spares: [GameRound]
    private(set) var index = 0
    private(set) var score = 0
    /// The author picked in the current round; nil until the user answers.
    private(set) var pickedID: String?

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

    /// Only the first pick in a round counts. Returns whether it was right.
    @discardableResult
    func pick(_ author: Author) -> Bool {
        guard pickedID == nil, let current else { return false }
        pickedID = author.id
        let isRight = author.id == current.answer.id
        if isRight {
            score += 1
        }
        return isRight
    }

    /// Moves to the next round, or past the last one, which finishes the game.
    func advance() {
        guard isRevealed else { return }
        pickedID = nil
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
        return true
    }

    func restart(with rounds: [GameRound]) {
        self.rounds = Array(rounds.prefix(length))
        spares = Array(rounds.dropFirst(length))
        index = 0
        score = 0
        pickedID = nil
    }
}
