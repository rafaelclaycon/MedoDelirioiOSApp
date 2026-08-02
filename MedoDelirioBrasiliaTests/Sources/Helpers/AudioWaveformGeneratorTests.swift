//
//  AudioWaveformGeneratorTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 01/08/26.
//

import AVFoundation
import XCTest
@testable import MedoDelirio

final class AudioWaveformGeneratorTests: XCTestCase {

    /// A stereo, 48 kHz MP3 — the same shape as the podcast episodes Share Clip
    /// reads. Reading it into a mono buffer used to fail with
    /// `com.apple.coreaudio.avfaudio error -50`, which broke the Criar Clipe screen.
    private var stereoFileURL: URL {
        Bundle(for: type(of: self))
            .url(forResource: "A9AFA060-B5E9-4A76-9E8C-12DB5DED51C5", withExtension: "mp3")!
    }

    func testGenerate_whenFileIsStereo_shouldReturnNormalisedBars() async throws {
        let file = try AVAudioFile(forReading: stereoFileURL)
        XCTAssertEqual(file.processingFormat.channelCount, 2, "Fixture is expected to be stereo.")

        let barCount = 200
        let bars = try await AudioWaveformGenerator.generate(from: stereoFileURL, barCount: barCount)

        XCTAssertEqual(bars.count, barCount)
        XCTAssertEqual(try XCTUnwrap(bars.max()), 1, accuracy: 0.0001, "Bars should be normalised to a peak of 1.")
        XCTAssertTrue(bars.allSatisfy { $0 >= 0 && $0 <= 1 })
        XCTAssertTrue(bars.contains { $0 > 0 }, "A file with audio should not produce an all-silent waveform.")
    }

    /// More bars than frames leaves nothing to average per bar, which should
    /// degrade to silence instead of dividing by zero.
    func testGenerate_whenBarCountExceedsFrameCount_shouldReturnSilence() async throws {
        let file = try AVAudioFile(forReading: stereoFileURL)
        let barCount = Int(file.length) + 1

        let bars = try await AudioWaveformGenerator.generate(from: stereoFileURL, barCount: barCount)

        XCTAssertEqual(bars.count, barCount)
        XCTAssertTrue(bars.allSatisfy { $0 == 0 })
    }
}
