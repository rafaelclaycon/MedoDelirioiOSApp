//
//  GameScoring.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation

/// How a game counts. The face game pays more the sooner you answer, while the photo
/// is still pixelated; the voice game counts right answers.
enum GameScoring {

    enum Unit {
        /// Right answers, out of the number of rounds.
        case hits
        /// Points per right answer, fewer the longer it took.
        case points
    }

    /// How long the photo takes to go from blocks to sharp, and the window over which a
    /// right answer's points fall from `maxPoints` to `minPoints`.
    static let revealDuration: TimeInterval = 10
    static let maxPoints = 1000
    /// What a right answer is still worth once the photo is sharp. Never zero, so
    /// knowing it beats guessing even when slow.
    static let minPoints = 100

    /// Block sizes, in points, for each second of the reveal: unrecognizable at first,
    /// almost sharp at the end. Sharp (1) once the reveal is over.
    static let pixelSteps: [Double] = [44, 34, 26, 20, 15, 11, 8, 5, 3, 2]

    /// Points for a right answer `elapsed` seconds after the photo appeared, rounded to
    /// tens so they read well.
    static func points(afterElapsed elapsed: TimeInterval) -> Int {
        let progress = min(max(elapsed / revealDuration, 0), 1)
        let raw = Double(maxPoints) - Double(maxPoints - minPoints) * progress
        return Int((raw / 10).rounded()) * 10
    }

    /// The block size to draw the photo at, `elapsed` seconds in. Steps rather than a
    /// smooth slide, so each second reveals a little more, like a game show.
    static func pixelSize(afterElapsed elapsed: TimeInterval) -> Double {
        guard elapsed < revealDuration else { return 1 }
        let step = Int(max(elapsed, 0) / revealDuration * Double(pixelSteps.count))
        return pixelSteps[min(step, pixelSteps.count - 1)]
    }

    /// "7.450 pontos", grouped the Brazilian way.
    static func formattedPoints(_ points: Int) -> String {
        let number = points.formatted(.number.grouping(.automatic).locale(Locale(identifier: "pt_BR")))
        return points == 1 ? "\(number) ponto" : "\(number) pontos"
    }
}
