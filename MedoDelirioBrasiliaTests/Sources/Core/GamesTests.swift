//
//  GamesTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

/// Deterministic, so a failing game can be reproduced.
private struct SeededGenerator: RandomNumberGenerator {

    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func authors(_ count: Int, withPhotos: Bool = true) -> [Author] {
    (0..<count).map { Author(id: "author-\($0)", name: "Autor \($0)", photo: withPhotos ? "https://example.com/\($0).jpg" : nil) }
}

private func sounds(for authors: [Author], perAuthor: Int = 2, duration: Double = 3) -> [Sound] {
    authors.flatMap { author in
        (0..<perAuthor).map { Sound(id: "\(author.id)-sound-\($0)", title: "Som \($0)", authorId: author.id, duration: duration) }
    }
}

// MARK: - Round Factory

struct GameRoundFactoryTests {

    @Test
    func faceRounds_shouldMakeTenRoundsWithFourOptionsIncludingTheAnswer() {
        var generator = SeededGenerator(state: 1)

        let rounds = GameRoundFactory.faceRounds(authors: authors(30), using: &generator)

        #expect(rounds.count == GameRoundFactory.roundCount)
        for round in rounds {
            #expect(round.options.count == GameRoundFactory.optionCount)
            #expect(round.options.contains(round.answer))
            #expect(Set(round.options.map(\.id)).count == round.options.count)
            #expect(round.prompt == .photo(round.answer.photo!))
        }
    }

    @Test
    func faceRounds_shouldNotRepeatAnAnswer() {
        var generator = SeededGenerator(state: 2)

        let rounds = GameRoundFactory.faceRounds(authors: authors(30), using: &generator)

        #expect(Set(rounds.map(\.answer.id)).count == rounds.count)
    }

    @Test
    func faceRounds_shouldOnlyUseAuthorsWithPhotos() {
        var generator = SeededGenerator(state: 3)
        let pool = authors(6) + authors(20, withPhotos: false).map {
            Author(id: "nophoto-\($0.id)", name: "Sem foto \($0.name)")
        }

        let rounds = GameRoundFactory.faceRounds(authors: pool, using: &generator)

        #expect(rounds.count == 6)
        #expect(rounds.flatMap(\.options).allSatisfy { $0.photo != nil })
    }

    @Test
    func faceRounds_withFewerThanFourAuthorsWithPhotos_shouldBeEmpty() {
        var generator = SeededGenerator(state: 4)

        #expect(GameRoundFactory.faceRounds(authors: authors(3), using: &generator).isEmpty)
    }

    @Test
    func rounds_shouldNotOfferTwoAuthorsWithTheSameName() {
        var generator = SeededGenerator(state: 5)
        let twins = authors(4) + [Author(id: "twin", name: "Autor 0", photo: "https://example.com/twin.jpg")]

        let rounds = GameRoundFactory.faceRounds(authors: twins, using: &generator)

        for round in rounds {
            #expect(Set(round.options.map(\.name)).count == round.options.count)
        }
    }

    @Test
    func voiceRounds_shouldUseASoundByTheAnswer() {
        var generator = SeededGenerator(state: 6)
        let pool = authors(12, withPhotos: false)

        let rounds = GameRoundFactory.voiceRounds(sounds: sounds(for: pool), authors: pool, using: &generator)

        #expect(rounds.count == GameRoundFactory.roundCount)
        for round in rounds {
            guard case .sound(let sound) = round.prompt else {
                Issue.record("Expected a sound prompt")
                continue
            }
            #expect(sound.authorId == round.answer.id)
            #expect(round.options.count == GameRoundFactory.optionCount)
            #expect(round.options.contains(round.answer))
        }
        #expect(Set(rounds.map(\.answer.id)).count == rounds.count)
    }

    @Test
    func voiceRounds_shouldOfferOnlyAuthorsWithSounds() {
        var generator = SeededGenerator(state: 7)
        let voiced = authors(5, withPhotos: false)
        let silent = (0..<20).map { Author(id: "silent-\($0)", name: "Calado \($0)") }

        let rounds = GameRoundFactory.voiceRounds(sounds: sounds(for: voiced), authors: voiced + silent, using: &generator)

        let voicedIDs = Set(voiced.map(\.id))
        #expect(rounds.flatMap(\.options).allSatisfy { voicedIDs.contains($0.id) })
    }

    @Test
    func voiceRounds_shouldSkipSoundsTooShortToGuess() {
        var generator = SeededGenerator(state: 8)
        let pool = authors(5, withPhotos: false)
        let tooShort = sounds(for: [pool[0]], duration: 0.5)
        let fine = sounds(for: Array(pool.dropFirst()))

        let rounds = GameRoundFactory.voiceRounds(sounds: tooShort + fine, authors: pool, using: &generator)

        #expect(rounds.count == 4)
        #expect(!rounds.map(\.answer.id).contains(pool[0].id))
    }

    @Test
    func voiceRounds_withFewerThanFourVoices_shouldBeEmpty() {
        var generator = SeededGenerator(state: 9)
        let pool = authors(3, withPhotos: false)

        #expect(GameRoundFactory.voiceRounds(sounds: sounds(for: pool), authors: pool, using: &generator).isEmpty)
    }
}

// MARK: - Session

@MainActor
struct GameSessionTests {

    private func session(rounds count: Int = 3) -> GameSession {
        var generator = SeededGenerator(state: 10)
        let rounds = GameRoundFactory.faceRounds(authors: authors(20), count: count, using: &generator)
        return GameSession(kind: .whoseFace, rounds: rounds)
    }

    @Test
    func pick_theAnswer_shouldScore() throws {
        let sut = session()
        let answer = try #require(sut.current?.answer)

        #expect(sut.pick(answer))
        #expect(sut.hits == 1)
        #expect(sut.pickedCorrectly)
    }

    @Test
    func pick_aWrongOption_shouldNotScore() throws {
        let sut = session()
        let round = try #require(sut.current)
        let wrong = try #require(round.options.first { $0.id != round.answer.id })

        #expect(!sut.pick(wrong))
        #expect(sut.hits == 0)
        #expect(!sut.pickedCorrectly)
    }

    @Test
    func pick_twiceInARound_shouldOnlyCountTheFirst() throws {
        let sut = session()
        let round = try #require(sut.current)
        let wrong = try #require(round.options.first { $0.id != round.answer.id })

        sut.pick(wrong)
        sut.pick(round.answer)

        #expect(sut.hits == 0)
        #expect(sut.pickedID == wrong.id)
    }

    @Test
    func advance_beforeAnswering_shouldStayOnTheRound() {
        let sut = session()

        sut.advance()

        #expect(sut.index == 0)
    }

    @Test
    func advance_pastTheLastRound_shouldFinish() throws {
        let sut = session(rounds: 2)

        for _ in 0..<2 {
            sut.pick(try #require(sut.current?.answer))
            sut.advance()
        }

        #expect(sut.isFinished)
        #expect(sut.hits == 2)
        #expect(sut.current == nil)
    }

    @Test
    func init_shouldKeepRoundsBeyondTheLengthAsSpares() {
        var generator = SeededGenerator(state: 12)
        let rounds = GameRoundFactory.faceRounds(authors: authors(20), count: 5, using: &generator)

        let sut = GameSession(kind: .whoseFace, rounds: rounds, length: 3)

        #expect(sut.rounds == Array(rounds.prefix(3)))
        #expect(sut.spares == Array(rounds.suffix(2)))
    }

    @Test
    func replaceRound_shouldSwapInASpareInPlace() throws {
        var generator = SeededGenerator(state: 13)
        let rounds = GameRoundFactory.faceRounds(authors: authors(20), count: 5, using: &generator)
        let sut = GameSession(kind: .whoseFace, rounds: rounds, length: 3)

        #expect(sut.replaceRound(id: rounds[1].id))

        #expect(sut.rounds.map(\.id) == [rounds[0].id, rounds[3].id, rounds[2].id])
        #expect(sut.spares.map(\.id) == [rounds[4].id])
    }

    @Test
    func replaceRound_withNoSparesLeft_shouldDropTheRound() {
        let sut = session(rounds: 3)
        let dropped = sut.rounds[2].id

        #expect(sut.replaceRound(id: dropped))

        #expect(sut.rounds.count == 2)
        #expect(!sut.rounds.map(\.id).contains(dropped))
    }

    @Test
    func replaceRound_onAnAnsweredRound_shouldDoNothing() throws {
        let sut = session(rounds: 3)
        let first = try #require(sut.current)
        sut.pick(first.answer)

        #expect(!sut.replaceRound(id: first.id))
        #expect(sut.current == first)
    }

    @Test
    func replaceRound_droppingTheLastRoundUnanswered_shouldFinish() throws {
        let sut = session(rounds: 2)
        sut.pick(try #require(sut.current?.answer))
        sut.advance()

        sut.replaceRound(id: try #require(sut.current?.id))

        #expect(sut.isFinished)
        #expect(sut.hits == 1)
    }

    @Test
    func restart_shouldStartOver() throws {
        let sut = session()
        sut.pick(try #require(sut.current?.answer))
        sut.advance()

        var generator = SeededGenerator(state: 11)
        sut.restart(with: GameRoundFactory.faceRounds(authors: authors(20), count: 3, using: &generator))

        #expect(sut.index == 0)
        #expect(sut.hits == 0)
        #expect(sut.pickedID == nil)
    }
}

// MARK: - Scoring

struct GameScoringTests {

    @Test(arguments: [
        (0.0, 1000),
        (5.0, 550),
        (10.0, 100),
        (60.0, 100),
        (-1.0, 1000)
    ])
    func points_shouldFallFromMaxToMinOverTheReveal(elapsed: Double, expected: Int) {
        #expect(GameScoring.points(afterElapsed: elapsed) == expected)
    }

    @Test
    func points_shouldBeRoundedToTens() {
        #expect(GameScoring.points(afterElapsed: 1.234) % 10 == 0)
    }

    @Test
    func pixelSize_shouldShrinkStepByStepAndEndSharp() {
        let sizes = stride(from: 0.0, to: GameScoring.revealDuration, by: 0.5).map(GameScoring.pixelSize(afterElapsed:))

        #expect(sizes.first == GameScoring.pixelSteps.first)
        #expect(zip(sizes, sizes.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(GameScoring.pixelSize(afterElapsed: GameScoring.revealDuration) == 1)
    }

    @Test
    func formattedPoints_shouldGroupTheBrazilianWay() {
        #expect(GameScoring.formattedPoints(7450) == "7.450 pontos")
        #expect(GameScoring.formattedPoints(1) == "1 ponto")
    }
}

// MARK: - Session Points

@MainActor
struct GameSessionPointsTests {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func session() -> GameSession {
        var generator = SeededGenerator(state: 20)
        let rounds = GameRoundFactory.faceRounds(authors: authors(20), count: 3, using: &generator)
        return GameSession(kind: .whoseFace, rounds: rounds)
    }

    @Test
    func pick_rightAway_shouldEarnTheMostPoints() throws {
        let sut = session()
        sut.startClock(at: start)

        sut.pick(try #require(sut.current?.answer), at: start)

        #expect(sut.roundPoints == GameScoring.maxPoints)
        #expect(sut.score == GameScoring.maxPoints)
    }

    @Test
    func pick_later_shouldEarnFewerPoints() throws {
        let sut = session()
        sut.startClock(at: start)

        sut.pick(try #require(sut.current?.answer), at: start.addingTimeInterval(5))

        #expect(sut.points == GameScoring.points(afterElapsed: 5))
    }

    @Test
    func pick_beforeThePhotoShowed_shouldEarnTheMinimum() throws {
        let sut = session()

        sut.pick(try #require(sut.current?.answer), at: start)

        #expect(sut.points == GameScoring.minPoints)
    }

    @Test
    func pick_wrong_shouldEarnNothing() throws {
        let sut = session()
        sut.startClock(at: start)
        let round = try #require(sut.current)

        sut.pick(try #require(round.options.first { $0.id != round.answer.id }), at: start)

        #expect(sut.roundPoints == 0)
        #expect(sut.points == 0)
    }

    @Test
    func startClock_twice_shouldKeepTheFirstStart() throws {
        let sut = session()
        sut.startClock(at: start)
        sut.startClock(at: start.addingTimeInterval(8))

        sut.pick(try #require(sut.current?.answer), at: start.addingTimeInterval(8))

        #expect(sut.points == GameScoring.points(afterElapsed: 8))
    }

    @Test
    func advance_shouldResetTheClockForTheNextRound() throws {
        let sut = session()
        sut.startClock(at: start)
        sut.pick(try #require(sut.current?.answer), at: start)

        sut.advance()

        #expect(sut.roundStartedAt == nil)
        #expect(sut.roundPoints == nil)
        #expect(sut.points == GameScoring.maxPoints)
    }

    @Test
    func score_inTheVoiceGame_shouldCountHits() throws {
        var generator = SeededGenerator(state: 21)
        let pool = authors(8, withPhotos: false)
        let rounds = GameRoundFactory.voiceRounds(sounds: sounds(for: pool), authors: pool, count: 3, using: &generator)
        let sut = GameSession(kind: .whoseVoice, rounds: rounds)

        sut.pick(try #require(sut.current?.answer))

        #expect(sut.score == 1)
    }
}

// MARK: - Game Result

@MainActor
struct GameResultTests {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func playedFaceGame() throws -> GameSession {
        var generator = SeededGenerator(state: 30)
        let rounds = GameRoundFactory.faceRounds(authors: authors(20), count: 2, using: &generator)
        let sut = GameSession(kind: .whoseFace, rounds: rounds)

        // Right in 2 seconds, then wrong in 4.
        sut.startClock(at: start)
        sut.pick(try #require(sut.current?.answer), at: start.addingTimeInterval(2))
        sut.advance()
        sut.startClock(at: start)
        let round = try #require(sut.current)
        sut.pick(try #require(round.options.first { $0.id != round.answer.id }), at: start.addingTimeInterval(4))
        sut.advance()
        return sut
    }

    @Test
    func init_fromAFinishedSession_shouldRecordHowItWent() throws {
        let session = try playedFaceGame()

        let result = GameResult(session: session, finishedAt: start, appVersion: "13.6")

        #expect(result.gameKind == "whoseFace")
        #expect(result.rounds == 2)
        #expect(result.hits == 1)
        #expect(result.points == GameScoring.points(afterElapsed: 2))
        #expect(result.averageAnswerSeconds == 3)
        #expect(result.appVersion == "13.6")
        #expect(result.score == result.points)
    }

    @Test
    func averageAnswerSeconds_whenTheClockNeverStarted_shouldBeNil() throws {
        var generator = SeededGenerator(state: 31)
        let sut = GameSession(kind: .whoseFace, rounds: GameRoundFactory.faceRounds(authors: authors(20), count: 1, using: &generator))

        sut.pick(try #require(sut.current?.answer))

        #expect(sut.averageAnswerSeconds == nil)
    }

    @Test
    func restart_shouldForgetAnswerTimes() throws {
        let sut = try playedFaceGame()
        var generator = SeededGenerator(state: 32)

        sut.restart(with: GameRoundFactory.faceRounds(authors: authors(20), count: 2, using: &generator))

        #expect(sut.averageAnswerSeconds == nil)
    }

    @Test
    func score_forTheVoiceGame_shouldBeHits() {
        let result = GameResult(
            gameKind: GameKind.whoseVoice.rawValue,
            finishedAt: start,
            rounds: 10,
            hits: 7,
            points: 4200,
            averageAnswerSeconds: nil,
            appVersion: "13.6"
        )

        #expect(result.score == 7)
    }
}

// MARK: - Scores

struct GameScoreStoreTests {

    private let defaults = UserDefaults(suiteName: "GameScoreStoreTests-\(UUID().uuidString)")!

    @Test
    func bestScore_beforePlaying_shouldBeNil() {
        #expect(GameScoreStore(defaults: defaults).bestScore(for: .whoseFace) == nil)
    }

    @Test
    func record_shouldKeepTheBestAndSayWhenItBeatsIt() {
        let sut = GameScoreStore(defaults: defaults)

        #expect(sut.record(5, for: .whoseFace))
        #expect(!sut.record(3, for: .whoseFace))
        #expect(!sut.record(5, for: .whoseFace))
        #expect(sut.record(8, for: .whoseFace))
        #expect(sut.bestScore(for: .whoseFace) == 8)
    }

    @Test
    func record_aFirstGameOfZero_shouldShowButNotCelebrate() {
        let sut = GameScoreStore(defaults: defaults)

        #expect(!sut.record(0, for: .whoseVoice))
        #expect(sut.bestScore(for: .whoseVoice) == 0)
    }

    @Test
    func bestScore_forThePointsGame_shouldIgnoreABestFromWhenItCountedHits() {
        defaults.set(9, forKey: "gameBestScore.whoseFace")

        #expect(GameScoreStore(defaults: defaults).bestScore(for: .whoseFace) == nil)
    }

    @Test
    func record_shouldKeepEachGameApartAndSurviveARelaunch() {
        GameScoreStore(defaults: defaults).record(7, for: .whoseVoice)

        let relaunched = GameScoreStore(defaults: defaults)

        #expect(relaunched.bestScore(for: .whoseVoice) == 7)
        #expect(relaunched.bestScore(for: .whoseFace) == nil)
    }
}
