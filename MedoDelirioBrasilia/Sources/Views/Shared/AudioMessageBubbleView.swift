//
//  AudioMessageBubbleView.swift
//  MedoDelirioBrasilia
//

import AVFoundation
import SwiftUI

struct AudioMessageBubbleView: View {

    let audioURL: URL
    let senderName: String

    @Environment(\.colorScheme) private var colorScheme

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?

    private var bubbleColor: Color {
        colorScheme == .dark ? .whatsAppDarkGreen : .whatsAppLightGreen
    }

    private var displayTime: String {
        let time = isPlaying ? duration * (1 - progress) : duration
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
            HStack(spacing: .spacing(.small)) {
                Circle()
                    .fill(Color.darkerGreen)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(senderName.prefix(1)).uppercased())
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(Color.darkerGreen)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            waveformBars(width: geometry.size.width, filled: false)

                            waveformBars(width: geometry.size.width, filled: true)
                                .mask(alignment: .leading) {
                                    Rectangle()
                                        .frame(width: geometry.size.width * progress)
                                }
                        }
                    }
                    .frame(height: 20)

                    Text(displayTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, .spacing(.small))
            .padding(.vertical, .spacing(.xSmall))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(bubbleColor)
            )

            Text(senderName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, .spacing(.xxxSmall))
        }
        .onAppear {
            preparePlayer()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Waveform

    private func waveformBars(width: CGFloat, filled: Bool) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount(for: width), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(filled ? Color.darkerGreen : Color.darkerGreen.opacity(0.3))
                    .frame(width: 2.5, height: barHeight(for: index))
            }
        }
    }

    private func barCount(for width: CGFloat) -> Int {
        max(1, Int(width / 4.5))
    }

    private func barHeight(for index: Int) -> CGFloat {
        let seed = Double(index)
        let height = 4 + 14 * abs(sin(seed * 0.8 + 0.3) * cos(seed * 0.4 + 1.2))
        return CGFloat(height)
    }

    // MARK: - Playback

    private func preparePlayer() {
        guard let audioPlayer = try? AVAudioPlayer(contentsOf: audioURL) else { return }
        audioPlayer.prepareToPlay()
        player = audioPlayer
        duration = audioPlayer.duration
    }

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            timer?.invalidate()
            timer = nil
            isPlaying = false
        } else {
            if progress >= 1.0 {
                player.currentTime = 0
                progress = 0
            }

            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let p = self.player else { return }
                if p.isPlaying {
                    self.progress = p.currentTime / p.duration
                } else {
                    self.progress = 1.0
                    self.isPlaying = false
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        isPlaying = false
    }
}

// MARK: - Preview

#Preview {
    AudioMessageBubbleView(
        audioURL: Bundle.main.url(forResource: "cristiano-4-anos", withExtension: "mp3")
            ?? URL(fileURLWithPath: "/dev/null"),
        senderName: "Cristiano"
    )
    .padding()
}
