//
//  GameScoreStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation

/// The best score for each game, kept on this device.
@Observable
final class GameScoreStore {

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var bestScores: [GameKind: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var scores = [GameKind: Int]()
        for kind in GameKind.allCases {
            if let score = defaults.object(forKey: Self.key(for: kind)) as? Int {
                scores[kind] = score
            }
        }
        self.bestScores = scores
    }

    /// Nil until the game has been played to the end once.
    func bestScore(for kind: GameKind) -> Int? {
        bestScores[kind]
    }

    /// Keeps the score if it beats the best. Returns whether it's a new best; the first
    /// game played is one only if it scored something.
    @discardableResult
    func record(_ score: Int, for kind: GameKind) -> Bool {
        let previous = bestScores[kind]
        guard previous == nil || score > previous! else { return false }
        bestScores[kind] = score
        defaults.set(score, forKey: Self.key(for: kind))
        return previous != nil || score > 0
    }

    /// Points games keep their best under a key of their own, so a best from before
    /// the face game counted points (right answers, out of ten) never shows as points.
    private static func key(for kind: GameKind) -> String {
        switch kind.scoring {
        case .hits: "gameBestScore.\(kind.rawValue)"
        case .points: "gameBestScore.\(kind.rawValue).points"
        }
    }
}
