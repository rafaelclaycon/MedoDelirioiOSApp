//
//  StatDrums.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 05/11/26.
//

import AudioToolbox
import Foundation
import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// The easter egg on Você's stat cards: each one is a drum, a kick, a snare and a hi-hat,
/// like a tiny drum machine to pass the time.
///
/// The sounds are drawn in code, 808 style, and played as system sounds. That keeps them
/// out of the audio session the episodes and Vírgulas use: they mix with whatever's playing,
/// go quiet with the silent switch and follow the ringer volume, like any other tap sound.
enum StatDrum: String, CaseIterable {

    case kick
    case snare
    case hiHat

    /// Heavier for the bigger drum.
    var haptic: SensoryFeedback {
        switch self {
        case .kick: .impact(weight: .heavy, intensity: 0.8)
        case .snare: .impact(weight: .medium, intensity: 0.6)
        case .hiHat: .impact(weight: .light, intensity: 0.4)
        }
    }

    /// In seconds, how long the sound rings.
    var duration: Double {
        switch self {
        case .kick: 0.45
        case .snare: 0.25
        case .hiHat: 0.08
        }
    }
}

// MARK: - Kit

/// The three drums as system sounds, written to Caches as WAV files the first time.
@MainActor
final class StatDrumKit {

    static let shared = StatDrumKit()

    /// Part of the file names: change it when the sounds change, so the old files aren't reused.
    private static let soundVersion = 1

    private var soundIDs: [StatDrum: SystemSoundID] = [:]

    /// Cheap after the first time. Called when the cards show up, so the first hit isn't late.
    func prepare() {
        guard soundIDs.isEmpty else { return }
        guard let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "StatDrums", directoryHint: .isDirectory)
        else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for drum in StatDrum.allCases {
            let url = folder.appending(path: "\(drum.rawValue)-v\(Self.soundVersion).wav")
            if !FileManager.default.fileExists(atPath: url.path()) {
                let wav = StatDrumSynth.wav(StatDrumSynth.samples(for: drum))
                guard (try? wav.write(to: url, options: .atomic)) != nil else { continue }
            }
            var soundID: SystemSoundID = 0
            if AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError {
                soundIDs[drum] = soundID
            }
        }
    }

    func play(_ drum: StatDrum) {
        prepare()
        guard let soundID = soundIDs[drum] else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

// MARK: - Synthesis

/// Kick, snare and hi-hat from sine waves and noise. Pure and deterministic, the same
/// samples every time, so the files can be cached and tested.
enum StatDrumSynth {

    static let sampleRate = 44_100

    /// Mono, from -1 to 1.
    static func samples(for drum: StatDrum) -> [Float] {
        switch drum {
        case .kick: kick()
        case .snare: snare()
        case .hiHat: hiHat()
        }
    }

    /// A sine that drops from about 160 Hz to 50 Hz as it fades, with a click on top for
    /// the beater.
    private static func kick() -> [Float] {
        var noise = Noise(seed: 1)
        var phase: Float = 0
        let samples = render(duration: Float(StatDrum.kick.duration)) { t in
            let frequency = 50 + 110 * exp(-t / 0.03)
            phase += 2 * .pi * frequency / Float(sampleRate)
            let body = sin(phase) * exp(-t / 0.12)
            let click = noise.next() * exp(-t / 0.002) * 0.3
            return tanh(1.5 * (body + click))
        }
        return finished(samples, peak: 0.95)
    }

    /// Two short tones for the drum and bright noise for the wires.
    private static func snare() -> [Float] {
        var noise = Noise(seed: 2)
        var wires = HighPass(coefficient: 0.82)
        let samples = render(duration: Float(StatDrum.snare.duration)) { t in
            let drum = sin(2 * .pi * 185 * t) * exp(-t / 0.05) * 0.5
                + sin(2 * .pi * 330 * t) * exp(-t / 0.03) * 0.3
            let snares = wires.filter(noise.next()) * exp(-t / 0.07) * 0.8
            return drum + snares
        }
        return finished(samples, peak: 0.8)
    }

    /// Noise with the lows taken out twice, closing fast.
    private static func hiHat() -> [Float] {
        var noise = Noise(seed: 3)
        var first = HighPass(coefficient: 0.5)
        var second = HighPass(coefficient: 0.5)
        let samples = render(duration: Float(StatDrum.hiHat.duration)) { t in
            second.filter(first.filter(noise.next())) * exp(-t / 0.018)
        }
        return finished(samples, peak: 0.6)
    }

    private static func render(duration: Float, _ sample: (Float) -> Float) -> [Float] {
        let count = Int(duration * Float(sampleRate))
        return (0..<count).map { sample(Float($0) / Float(sampleRate)) }
    }

    /// Scaled to `peak`, with the last 5 ms faded out so the end doesn't click.
    private static func finished(_ samples: [Float], peak: Float) -> [Float] {
        let loudest = samples.map(abs).max() ?? 0
        guard loudest > 0 else { return samples }
        let fadeLength = min(sampleRate / 200, samples.count)
        return samples.enumerated().map { index, sample in
            let remaining = samples.count - index
            let fade = remaining < fadeLength ? Float(remaining) / Float(fadeLength) : 1
            return sample / loudest * peak * fade
        }
    }

    /// 16-bit mono PCM in a WAV file, which system sounds can play.
    static func wav(_ samples: [Float]) -> Data {
        let dataSize = UInt32(samples.count * 2)
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1)) // PCM
        data.appendLittleEndian(UInt16(1)) // Mono
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2)) // Bytes per second
        data.appendLittleEndian(UInt16(2)) // Bytes per frame
        data.appendLittleEndian(UInt16(16)) // Bits per sample
        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(dataSize)
        for sample in samples {
            data.appendLittleEndian(Int16(max(-1, min(1, sample)) * Float(Int16.max)))
        }
        return data
    }

    /// White noise from a fixed seed, so every build draws the same drums.
    private struct Noise {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed &* 0x9E37_79B9_7F4A_7C15 | 1
        }

        mutating func next() -> Float {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Float(state >> 40) / Float(1 << 23) - 1
        }
    }

    /// One-pole high-pass. Closer to 1 lets more of the lows through.
    private struct HighPass {
        let coefficient: Float
        private var lastInput: Float = 0
        private var lastOutput: Float = 0

        init(coefficient: Float) {
            self.coefficient = coefficient
        }

        mutating func filter(_ input: Float) -> Float {
            lastOutput = coefficient * (lastOutput + input - lastInput)
            lastInput = input
            return lastOutput
        }
    }
}

private extension Data {

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

// MARK: - Touch Down

/// Fires the moment a finger lands, like a drum pad, rather than when it lifts like a
/// button. A UIKit recognizer because it hears the touch right away, without the scroll
/// view's wait to see whether a scroll is starting. It then steps aside, so scrolling from
/// the card still works (and plays one hit).
struct TouchDownGesture: UIGestureRecognizerRepresentable {

    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> Recognizer {
        let recognizer = Recognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: Recognizer, context: Context) {
        recognizer.onTouchDown = action
    }

    final class Recognizer: UIGestureRecognizer {

        var onTouchDown: (() -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            onTouchDown?()
            state = .failed
        }
    }
}
