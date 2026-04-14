//
//  AudioMessageBubbleView.swift
//  MedoDelirioBrasilia
//

import AVFoundation
import SwiftUI

struct AudioMessageBubbleView: View {

    let audioURL: URL
    let senderName: String
    var senderImage: Image?

    @Environment(\.colorScheme) private var colorScheme

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?

    private var bubbleColor: Color {
        colorScheme == .dark
            ? Color(.systemGray5)
            : Color(.systemGray6)
    }

    private var displayTime: String {
        let time = isPlaying ? duration * (1 - progress) : duration
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private let thumbColor = Color.accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
            HStack(spacing: .spacing(.small)) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                waveformSection

                avatarView
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(thumbColor)
                            .offset(x: 2, y: 2)
                    }
            }
            .padding(.leading, .spacing(.small))
            .padding(.trailing, .spacing(.xSmall))
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

    // MARK: - Subviews

    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    waveformBars(width: geometry.size.width, played: false)

                    waveformBars(width: geometry.size.width, played: true)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width * progress)
                        }

                    Circle()
                        .fill(thumbColor)
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, geometry.size.width * progress - 5))
                }
            }
            .frame(height: 24)

            Text(displayTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let senderImage {
            senderImage
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color.darkerGreen)
                .overlay {
                    Text(String(senderName.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
        }
    }

    // MARK: - Waveform

    private func waveformBars(width: CGFloat, played: Bool) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount(for: width), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(played ? thumbColor : Color(.systemGray3))
                    .frame(width: 2.5, height: barHeight(for: index))
            }
        }
    }

    private func barCount(for width: CGFloat) -> Int {
        max(1, Int(width / 5))
    }

    private func barHeight(for index: Int) -> CGFloat {
        let seed = Double(index)
        let height = 3 + 18 * abs(sin(seed * 0.8 + 0.3) * cos(seed * 0.4 + 1.2))
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
