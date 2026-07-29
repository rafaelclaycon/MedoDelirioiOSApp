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
    var onExportComplete: (Bool) -> Void = { _ in }

    @State private var artwork: UIImage = ShareClipGenerator.placeholderArtwork
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval
    @State private var playbackTask: Task<Void, Never>?
    @State private var showGeneration = false
    @State private var isScrubbing = false
    @State private var scrubValue: TimeInterval = 0
    @State private var includeTranscript = true

    private static let scrubberThumbSize: CGFloat = 14

    init(
        config: ShareClipGenerator.Configuration,
        onExportComplete: @escaping (Bool) -> Void = { _ in }
    ) {
        self.config = config
        self.onExportComplete = onExportComplete
        _currentTime = State(initialValue: config.clipStart)
    }

    private var clipDuration: TimeInterval { config.clipEnd - config.clipStart }
    private var displayedTime: TimeInterval { isScrubbing ? scrubValue : currentTime }
    private var elapsedInClip: TimeInterval {
        max(0, min(displayedTime - config.clipStart, clipDuration))
    }

    private var hasTranscript: Bool { config.includesTranscript }
    private var transcriptShown: Bool { hasTranscript && includeTranscript }

    /// The cue under the playhead, shown live in the frame preview.
    private var currentCueText: String? {
        guard transcriptShown else { return nil }
        return config.transcriptCues.first {
            displayedTime >= $0.startTime && displayedTime < $0.endTime
        }?.text
    }

    /// What actually gets exported: the incoming config, minus the transcript
    /// when the user switches it off.
    private var effectiveConfig: ShareClipGenerator.Configuration {
        includeTranscript ? config : config.removingTranscript()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .spacing(.xxLarge)) {
                Text("Essa é uma prévia do vídeo que será gerado, para você conferir se capturou o áudio desejado.")
                    .font(.callout)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)

                framePreview

                audioControls

                transcriptToggle
            }
            .padding(.horizontal, .spacing(.xLarge))
            .padding(.vertical, .spacing(.large))
        }
        .safeAreaInset(edge: .bottom) {
            generateButton
                .padding(.horizontal, .spacing(.xLarge))
                .padding(.vertical, .spacing(.small))
                .background(.bar)
        }
        .navigationTitle("Pré-visualização")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showGeneration) {
            ShareClipPreviewView(config: effectiveConfig, onExportComplete: onExportComplete)
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
            videoSize: .init(width: size, height: size),
            includesTranscript: transcriptShown,
            transcriptText: currentCueText
        )
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .frame(width: size * scale, height: size * scale)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }

    private var audioControls: some View {
        VStack(spacing: .spacing(.small)) {
            scrubber

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

    private var scrubber: some View {
        GeometryReader { geo in
            let fraction = clipDuration > 0 ? elapsedInClip / clipDuration : 0
            let thumbX = CGFloat(fraction) * geo.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.orange)
                    .frame(width: max(thumbX, 0), height: 4)

                Circle()
                    .fill(Color.orange)
                    .frame(width: Self.scrubberThumbSize, height: Self.scrubberThumbSize)
                    .offset(x: thumbX - Self.scrubberThumbSize / 2)
            }
            .frame(height: Self.scrubberThumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        let clamped = min(max(value.location.x, 0), geo.size.width)
                        let clampedFraction = geo.size.width > 0 ? clamped / geo.size.width : 0
                        scrubValue = config.clipStart + TimeInterval(clampedFraction) * clipDuration
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        seek(to: scrubValue)
                    }
            )
        }
        .frame(height: Self.scrubberThumbSize)
    }

    /// Only offered when the clip's range actually has transcript cues;
    /// episodes without a downloaded transcript never show it.
    @ViewBuilder
    private var transcriptToggle: some View {
        if hasTranscript {
            Toggle(isOn: $includeTranscript.animation(.easeInOut(duration: 0.2))) {
                Label("Incluir transcrição", systemImage: "text.quote")
                    .font(.subheadline)
            }
            .tint(.orange)
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

    private func seek(to time: TimeInterval) {
        currentTime = min(max(time, config.clipStart), config.clipEnd)
        audioPlayer?.currentTime = currentTime
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
