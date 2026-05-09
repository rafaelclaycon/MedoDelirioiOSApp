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
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?

    private var bubbleColor: Color {
        colorScheme == .dark
            ? Color(.systemGray5)
            : Color(.systemGray6)
    }

    private var displayTime: String {
        let currentProgress = isScrubbing ? scrubProgress : progress
        let time = (isPlaying || isScrubbing) ? duration * (1 - currentProgress) : duration
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
                let displayProgress = isScrubbing ? scrubProgress : progress
                let thumbSize: CGFloat = 10
                let thumbOffset = max(
                    0,
                    min(geometry.size.width - thumbSize, geometry.size.width * displayProgress - thumbSize / 2)
                )

                ZStack(alignment: .leading) {
                    waveformBars(width: geometry.size.width, played: false)

                    waveformBars(width: geometry.size.width, played: true)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width * displayProgress)
                        }

                    Circle()
                        .fill(thumbColor)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: thumbOffset)
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(scrubGesture(width: geometry.size.width))
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

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                updateScrubProgress(for: value.location.x, width: width, shouldSeekPlayer: true)
            }
            .onEnded { value in
                updateScrubProgress(for: value.location.x, width: width, shouldSeekPlayer: true)
                progress = scrubProgress
                isScrubbing = false
            }
    }

    private func updateScrubProgress(for xPosition: CGFloat, width: CGFloat, shouldSeekPlayer: Bool) {
        guard duration > 0, width > 0 else { return }

        if !isScrubbing {
            scrubProgress = progress
            isScrubbing = true
        }

        let clampedXPosition = min(max(xPosition, 0), width)
        let nextProgress = Double(clampedXPosition / width)
        scrubProgress = min(max(nextProgress, 0), 1)

        guard shouldSeekPlayer else { return }

        player?.currentTime = duration * scrubProgress
    }

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
                scrubProgress = 0
            }

            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let p = self.player else { return }
                guard !self.isScrubbing else { return }

                if p.isPlaying {
                    self.progress = p.currentTime / p.duration
                } else {
                    self.progress = 1.0
                    self.scrubProgress = 1.0
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
