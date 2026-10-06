//
//  PlayDeduplicatorTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct PlayDeduplicatorTests {

    private var sut = PlayDeduplicator()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    @Test
    mutating func firstPlay_counts() {
        let counted = sut.shouldCount(contentId: "a", at: at(0))
        #expect(counted)
    }

    @Test
    mutating func quickRetapOfSameContent_isFolded() {
        _ = sut.shouldCount(contentId: "a", at: at(0))
        let counted = sut.shouldCount(contentId: "a", at: at(1))
        #expect(!counted)
    }

    @Test
    mutating func replayAfterWindow_counts() {
        _ = sut.shouldCount(contentId: "a", at: at(0))
        let counted = sut.shouldCount(contentId: "a", at: at(PlayDeduplicator.burstWindow))
        #expect(counted)
    }

    @Test
    mutating func continuousSpamming_staysOnePlay() {
        let counted = sut.shouldCount(contentId: "a", at: at(0))
        #expect(counted)
        // Every tap inside the window pushes it along, so a long burst never re-counts,
        // even once it has lasted far longer than the window itself.
        for second in stride(from: 1.0, through: 30.0, by: 1.0) {
            let counted = sut.shouldCount(contentId: "a", at: at(second))
            #expect(!counted)
        }
    }

    @Test
    mutating func pauseAfterSpamming_startsANewPlay() {
        _ = sut.shouldCount(contentId: "a", at: at(0))
        _ = sut.shouldCount(contentId: "a", at: at(2))
        _ = sut.shouldCount(contentId: "a", at: at(4))
        let counted = sut.shouldCount(contentId: "a", at: at(4 + PlayDeduplicator.burstWindow))
        #expect(counted)
    }

    @Test
    mutating func differentContent_countsSeparately() {
        let counted = [
            sut.shouldCount(contentId: "a", at: at(0)),
            sut.shouldCount(contentId: "b", at: at(0.5))
        ]
        #expect(counted == [true, true])
    }

    @Test
    mutating func alternatingBetweenTwoSounds_doesNotBreakEitherBurst() {
        let counted = [
            sut.shouldCount(contentId: "a", at: at(0)),
            sut.shouldCount(contentId: "b", at: at(0.5)),
            sut.shouldCount(contentId: "a", at: at(1)),
            sut.shouldCount(contentId: "b", at: at(1.5))
        ]
        #expect(counted == [true, true, false, false])
    }

    @Test
    mutating func clockGoingBackwards_isFolded() {
        _ = sut.shouldCount(contentId: "a", at: at(10))
        let counted = sut.shouldCount(contentId: "a", at: at(5))
        #expect(!counted)
    }
}
