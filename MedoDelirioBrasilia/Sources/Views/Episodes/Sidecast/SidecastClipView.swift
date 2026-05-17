//
//  SidecastClipView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/02/26.
//

import AVFoundation
import SwiftUI

struct SidecastClipView: View {

    let episode: PodcastEpisode

    @Environment(EpisodePlayer.self) private var player
    @Environment(\.dismiss) private var dismiss

    @State private var samples: [Float]?
    @State private var clipStart: TimeInterval = 0
    @State private var clipEnd: TimeInterval = 0
    @State private var loadError: String?
    @State private var previewPlayer: AVAudioPlayer?
    @State private var isPreviewPlaying: Bool = false
    @State private var previewCurrentTime: TimeInterval = 0
    @State private var previewTask: Task<Void, Never>?
    @State private var showPreview: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing(.xxLarge)) {
                    waveformSection

                    previewControls
                }
                .padding(.horizontal, .spacing(.xLarge))
                .padding(.vertical, .spacing(.large))
            }
            .navigationTitle("Criar Clipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Próximo") {
                        pausePreview()
                        showPreview = true
                    }
                    .fontWeight(.semibold)
                    .tint(.orange)
                    .disabled(samples == nil)
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                SidecastClipConfirmView(config: clipConfiguration)
            }
        }
        .task {
            await loadWaveform()
        }
        .onChange(of: clipStart) {
            if isPreviewPlaying { pausePreview() }
            previewCurrentTime = clipStart
        }
        .onChange(of: clipEnd) {
            if isPreviewPlaying { pausePreview() }
            previewCurrentTime = clipStart
        }
        .onDisappear {
            pausePreview()
            previewPlayer = nil
            SidecastClipGenerator.cleanupOutputDirectory()
        }
    }

    private var clipConfiguration: SidecastClipGenerator.Configuration {
        .init(
            episode: episode,
            audioFileURL: EpisodePlayer.localFileURL(for: episode),
            clipStart: clipStart,
            clipEnd: clipEnd,
            shareMode: .square
        )
    }

    // MARK: - Waveform

    @ViewBuilder
    private var waveformSection: some View {
        if let samples {
            WaveformView(
                samples: samples,
                duration: player.duration,
                clipStart: $clipStart,
                clipEnd: $clipEnd,
                playheadTime: previewCurrentTime,
                showPlayhead: previewPlayer != nil,
                onPlayheadDrag: { time in
                    if isPreviewPlaying { pausePreview() }
                    previewCurrentTime = time
                    previewPlayer?.currentTime = time
                }
            )
        } else if loadError != nil {
            ContentUnavailableView(
                "Não foi possível carregar o áudio",
                systemImage: "waveform.slash",
                description: Text(loadError ?? "")
            )
            .frame(height: 100)
        } else {
            ProgressView("Carregando forma de onda…")
                .frame(height: 100)
                .frame(maxWidth: .infinity)
        }
    }

    private var previewControls: some View {
        HStack(spacing: .spacing(.small)) {
            Button {
                if isPreviewPlaying {
                    pausePreview()
                } else {
                    playPreview()
                }
            } label: {
                Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.orange, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(previewPlayer == nil)

            Label(
                NowPlayingView.formatTime(clipStart),
                systemImage: "scissors"
            )

            Text("–")

            Text(NowPlayingView.formatTime(clipEnd))
        }
        .font(.subheadline)
        .monospacedDigit()
        .foregroundStyle(.orange)
    }

    // MARK: - Preview Playback

    private func playPreview() {
        guard let previewPlayer else { return }
        if player.isPlaying {
            player.togglePlayPause()
        }
        if previewCurrentTime < clipStart || previewCurrentTime >= clipEnd {
            previewCurrentTime = clipStart
        }
        previewPlayer.currentTime = previewCurrentTime
        previewPlayer.play()
        isPreviewPlaying = true
        startPlayheadUpdates()
    }

    private func pausePreview() {
        if let p = previewPlayer {
            previewCurrentTime = p.currentTime
        }
        previewPlayer?.pause()
        isPreviewPlaying = false
        previewTask?.cancel()
        previewTask = nil
    }

    private func startPlayheadUpdates() {
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            while !Task.isCancelled {
                guard let p = previewPlayer, p.isPlaying else { break }
                previewCurrentTime = p.currentTime
                if p.currentTime >= clipEnd {
                    previewPlayer?.pause()
                    isPreviewPlaying = false
                    previewCurrentTime = clipStart
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    // MARK: - Data Loading

    private func loadWaveform() async {
        let fileURL = EpisodePlayer.localFileURL(for: episode)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loadError = "Episódio não baixado."
            return
        }
        do {
            let barCount = min(2000, max(200, Int(player.duration * 0.4)))
            let bars = try await AudioWaveformGenerator.generate(from: fileURL, barCount: barCount)
            samples = bars
            let initialLength = min(30, player.duration)
            let maxStart = max(player.duration - initialLength, 0)
            clipStart = min(max(player.currentTime - initialLength / 2, 0), maxStart)
            clipEnd = clipStart + initialLength
            previewCurrentTime = clipStart
            previewPlayer = try? AVAudioPlayer(contentsOf: fileURL)
            previewPlayer?.prepareToPlay()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Subviews

extension SidecastClipView {

    struct ShareModeButton: View {

        let mode: SidecastClipShareMode
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            if #available(iOS 26, *) {
                buttonContent
                    .padding(.vertical, .spacing(.small))
                    .padding(.horizontal, .spacing(.small))
                    .glassEffect(
                        .regular.tint(
                            isSelected ? Color.orange.opacity(colorScheme == .dark ? 0.3 : 0.5) : nil
                        ).interactive()
                    )
                    .onTapGesture { action() }
            } else {
                Button(action: action) {
                    buttonContent
                        .padding(.vertical, .spacing(.small))
                        .padding(.horizontal, .spacing(.small))
                        .background {
                            RoundedRectangle(cornerRadius: .spacing(.huge))
                                .fill(isSelected ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
            }
        }

        private var buttonContent: some View {
            Image(systemName: mode.symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? .orange : .secondary)
                .frame(maxWidth: .infinity)
        }
    }

    struct BrandingButton: View {

        let branding: SidecastClipBranding
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            if #available(iOS 26, *) {
                Button { action() } label: {
                    buttonContent
                        .padding(.vertical, .spacing(.small))
                        .padding(.horizontal, .spacing(.small))
                        .glassEffect(
                            .regular.tint(
                                isSelected ? Color.orange.opacity(colorScheme == .dark ? 0.3 : 0.5) : nil
                            ).interactive()
                        )
//                        .onTapGesture { action() }
                }
            } else {
                Button(action: action) {
                    buttonContent
                        .padding(.vertical, .spacing(.small))
                        .padding(.horizontal, .spacing(.small))
                        .background {
                            RoundedRectangle(cornerRadius: .spacing(.huge))
                                .fill(isSelected ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
            }
        }

        private var buttonContent: some View {
            Image(systemName: branding.symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? .orange : .secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    SidecastClipView(episode: .mockRecent)
        .environment({
            let p = EpisodePlayer()
            p.currentEpisode = .mockRecent
            p.duration = PodcastEpisode.mockRecent.duration ?? 3945
            p.currentTime = 620
            return p
        }())
}
