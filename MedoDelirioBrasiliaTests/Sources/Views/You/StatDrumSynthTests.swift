//
//  StatDrumSynthTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 05/11/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct StatDrumSynthTests {

    @Test(arguments: StatDrum.allCases)
    func everyDrumStaysInRange_andEndsSilent(drum: StatDrum) {
        let samples = StatDrumSynth.samples(for: drum)

        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
        #expect(abs(samples.last ?? 1) < 0.001)
    }

    @Test(arguments: StatDrum.allCases)
    func everyDrumIsLoudAtTheStart_andFadesOut(drum: StatDrum) {
        let samples = StatDrumSynth.samples(for: drum)
        let tenth = samples.count / 10
        let loudestEarly = samples.prefix(tenth).map(abs).max() ?? 0
        let loudestLate = samples.suffix(tenth).map(abs).max() ?? 0

        #expect(loudestEarly > 0.3)
        #expect(loudestLate < loudestEarly / 4)
    }

    @Test
    func theSameDrumComesOutTheSameEveryTime() {
        #expect(StatDrumSynth.samples(for: .snare) == StatDrumSynth.samples(for: .snare))
    }

    @Test
    func theDrumsLastFromLongestToShortest() {
        let kick = StatDrumSynth.samples(for: .kick).count
        let snare = StatDrumSynth.samples(for: .snare).count
        let hiHat = StatDrumSynth.samples(for: .hiHat).count

        #expect(kick > snare)
        #expect(snare > hiHat)
    }

    @Test
    func wav_hasAMono16BitHeader_andTwoBytesPerSample() {
        let samples: [Float] = [0, 1, -1, 0.5]
        let wav = StatDrumSynth.wav(samples)
        let bytes = [UInt8](wav)

        func uint32(at offset: Int) -> UInt32 {
            bytes[offset..<offset + 4].reversed().reduce(0) { $0 << 8 | UInt32($1) }
        }
        func uint16(at offset: Int) -> UInt16 {
            UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
        }

        #expect(wav.count == 44 + samples.count * 2)
        #expect(String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: bytes[8..<12], as: UTF8.self) == "WAVE")
        #expect(uint16(at: 20) == 1) // PCM
        #expect(uint16(at: 22) == 1) // Mono
        #expect(uint32(at: 24) == UInt32(StatDrumSynth.sampleRate))
        #expect(uint16(at: 34) == 16)
        #expect(String(decoding: bytes[36..<40], as: UTF8.self) == "data")
        #expect(uint32(at: 40) == UInt32(samples.count * 2))
        #expect(Int16(bitPattern: uint16(at: 46)) == Int16.max)
    }
}

/// Telling a muted hit from a heard one, and what a visit reports.
@MainActor
struct StatDrumKitTests {

    @Test
    func aKickThatEndsRightAway_looksSilenced() {
        #expect(StatDrumKit.looksSilenced(.kick, elapsed: 0.005))
    }

    @Test
    func aKickThatRingsOut_isHeard() {
        #expect(!StatDrumKit.looksSilenced(.kick, elapsed: 0.46))
    }

    @Test
    func theHiHatIsTooShortToTell() {
        #expect(!StatDrumKit.canTellSilence(for: .hiHat))
        #expect(!StatDrumKit.looksSilenced(.hiHat, elapsed: 0.001))
        #expect(StatDrumKit.canTellSilence(for: .kick))
        #expect(StatDrumKit.canTellSilence(for: .snare))
    }

    @Test
    func aVisitWithHits_reportsEachDrum() {
        let action = YouNumbersView.drumsAnalyticsAction(hits: [.kick: 10, .hiHat: 3], wasSilenced: true)

        #expect(action == "didPlayStatDrums; 13; kick 10; snare 0; hiHat 3; silenced yes")
    }

    @Test
    func aVisitWithoutHits_reportsNothing() {
        #expect(YouNumbersView.drumsAnalyticsAction(hits: [:], wasSilenced: false) == nil)
        #expect(YouNumbersView.drumsAnalyticsAction(hits: [.snare: 0], wasSilenced: true) == nil)
    }

    @Test
    func theSilencedNote_hasNoEmDash() {
        #expect(!YouNumbersView.silencedMessage.contains("—"))
    }
}
