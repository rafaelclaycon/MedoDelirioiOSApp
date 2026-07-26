//
//  ShareClipConfirmView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/05/26.
//

import AVFoundation
import SwiftUI

struct ShareClipConfirmView: View {

    let config: ShareClipGenerator.Configuration
    var onExportComplete: () -> Void = {}

    @State private var artwork: UIImage = placeholder
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval
    @State private var playbackTask: Task<Void, Never>?
    @State private var showGeneration = false

    init(
        config: ShareClipGenerator.Configuration,
        onExportComplete: @escaping () -> Void = {}
    ) {
        self.config = config
        self.onExportComplete = onExportComplete
        _currentTime = State(initialValue: config.clipStart)
    }

    private var clipDuration: TimeInterval { config.clipEnd - config.clipStart }
    private var elapsedInClip: TimeInterval {
        max(0, min(currentTime - config.clipStart, clipDuration))
    }

    var body: some View {
        VStack(spacing: .spacing(.xxLarge)) {
            Spacer()

            framePreview

            audioControls

            Spacer()

            generateButton
        }
        .padding(.horizontal, .spacing(.xLarge))
        .padding(.vertical, .spacing(.large))
        .navigationTitle("Pré-visualização")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showGeneration) {
            ShareClipPreviewView(config: config, onExportComplete: onExportComplete)
        }
        .task { await setup() }
        .onDisappear {
            pause()
            audioPlayer = nil
        }
    }

    // MARK: - Subviews

    private var framePreview: some View {
        let size = CGFloat(1080)
        let scale = CGFloat(0.3)
        return ShareClipVideoFrameView(
            artwork: artwork,
            episodeTitle: config.episode.title,
            episodeDate: config.episode.pubDate,
            clipStart: config.clipStart,
            shareMode: config.shareMode,
            videoSize: .init(width: size, height: size)
        )
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .frame(width: size * scale, height: size * scale)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }

    private var audioControls: some View {
        VStack(spacing: .spacing(.small)) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                    Capsule()
                        .fill(Color.orange)
                        .frame(
                            width: clipDuration > 0
                                ? geo.size.width * elapsedInClip / clipDuration
                                : 0
                        )
                }
            }
            .frame(height: 4)

            HStack {
                Text(NowPlayingView.formatTime(elapsedInClip))
                    .frame(minWidth: 40, alignment: .leading)

                Spacer()

                Button {
                    isPlaying ? pause() : play()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.orange, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(audioPlayer == nil)

                Spacer()

                Text(NowPlayingView.formatTime(clipDuration))
                    .frame(minWidth: 40, alignment: .trailing)
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
    }

    private var generateButton: some View {
        Button {
            pause()
            showGeneration = true
        } label: {
            HStack {
                Spacer()
                Label("Gerar Clipe", systemImage: "wand.and.sparkles")
                    .font(.headline)
                Spacer()
            }
        }
        .shareClipButtonStyle()
    }

    // MARK: - Setup

    private func setup() async {
        if let imageURL = config.episode.imageURL,
           let (data, _) = try? await URLSession.shared.data(from: imageURL),
           let image = UIImage(data: data) {
            artwork = image
        }
        audioPlayer = try? AVAudioPlayer(contentsOf: config.audioFileURL)
        audioPlayer?.prepareToPlay()
    }

    // MARK: - Playback

    private func play() {
        guard let player = audioPlayer else { return }
        if currentTime < config.clipStart || currentTime >= config.clipEnd {
            currentTime = config.clipStart
        }
        player.currentTime = currentTime
        player.play()
        isPlaying = true
        startTracking()
    }

    private func pause() {
        if let p = audioPlayer { currentTime = p.currentTime }
        audioPlayer?.pause()
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    private func startTracking() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            while !Task.isCancelled {
                guard let p = audioPlayer, p.isPlaying else { break }
                currentTime = p.currentTime
                if p.currentTime >= config.clipEnd {
                    audioPlayer?.pause()
                    isPlaying = false
                    currentTime = config.clipStart
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}

// MARK: - Placeholder artwork

private let placeholder: UIImage = UIGraphicsImageRenderer(
    size: .init(width: 100, height: 100)
).image { ctx in
    UIColor.gray.withAlphaComponent(0.2).setFill()
    ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
}
