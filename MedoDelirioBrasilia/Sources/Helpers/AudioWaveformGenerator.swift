//
//  AudioWaveformGenerator.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/02/26.
//

import Accelerate
import AVFoundation

enum AudioWaveformGenerator {

    /// How many frames are decoded at a time. A full episode decoded in one go
    /// would need gigabytes of RAM (an hour of 44.1 kHz stereo float is ~1.3 GB),
    /// so the file is walked in chunks and only the per-bar averages are kept.
    private static let chunkFrameCount: AVAudioFrameCount = 1 << 18

    /// Reads the audio file at `url` and returns `barCount` normalised amplitude
    /// values in the range 0…1, suitable for waveform visualisation.
    static func generate(from url: URL, barCount: Int) async throws -> [Float] {
        try await Task.detached(priority: .userInitiated) {
            let silence = [Float](repeating: 0, count: max(barCount, 0))

            let file = try AVAudioFile(forReading: url)
            let totalFrames = Int(file.length)
            guard totalFrames > 0, barCount > 0 else { return silence }

            // The buffer's format has to be the file's *processing* format —
            // channel count included. Reading a stereo episode into a mono
            // buffer fails with com.apple.coreaudio.avfaudio error -50.
            let format = file.processingFormat
            let channelCount = Int(format.channelCount)
            guard channelCount > 0 else { return silence }

            let framesPerBar = totalFrames / barCount
            guard framesPerBar > 0 else { return silence }

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: chunkFrameCount
            ) else {
                return silence
            }

            // Sums are weighted by how many frames each contribution covered, so
            // bars split across two chunks still average correctly.
            var sums = [Float](repeating: 0, count: barCount)
            var counts = [Float](repeating: 0, count: barCount)
            var frameIndex = 0

            while frameIndex < totalFrames {
                try file.read(into: buffer)
                let framesRead = Int(buffer.frameLength)
                guard framesRead > 0, let channels = buffer.floatChannelData else { break }

                var offset = 0
                while offset < framesRead {
                    let position = frameIndex + offset
                    // The last bar absorbs the remainder of the integer division.
                    let bar = min(position / framesPerBar, barCount - 1)
                    let barEnd = bar == barCount - 1 ? totalFrames : (bar + 1) * framesPerBar
                    let length = min(framesRead - offset, barEnd - position)
                    guard length > 0 else { break }

                    var meanAcrossChannels: Float = 0
                    for channel in 0..<channelCount {
                        var mean: Float = 0
                        vDSP_meamgv(channels[channel] + offset, 1, &mean, vDSP_Length(length))
                        meanAcrossChannels += mean
                    }
                    meanAcrossChannels /= Float(channelCount)

                    sums[bar] += meanAcrossChannels * Float(length)
                    counts[bar] += Float(length)
                    offset += length
                }

                frameIndex += framesRead
            }

            var bars = [Float](repeating: 0, count: barCount)
            for i in 0..<barCount where counts[i] > 0 {
                bars[i] = sums[i] / counts[i]
            }

            let peak = bars.max() ?? 0
            if peak > 0 {
                for i in 0..<barCount {
                    bars[i] /= peak
                }
            }

            return bars
        }.value
    }
}
