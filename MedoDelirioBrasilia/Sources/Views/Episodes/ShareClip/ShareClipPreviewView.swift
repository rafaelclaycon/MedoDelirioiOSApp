//
//  ShareClipPreviewView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/02/26.
//

import AVKit
import SwiftUI
import UIKit

struct ShareClipPreviewView: View {

    let config: ShareClipGenerator.Configuration
    /// Passes whether the exported clip included a transcript, so callers can
    /// reflect that in analytics without reaching back into this view's state.
    var onExportComplete: (Bool) -> Void = { _ in }

    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State private var generationPhase: ShareClipGenerator.GenerationPhase?
    @State private var error: Error?
    @State private var generationTask: Task<Void, Never>?
    @State private var isMuted: Bool = true
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        Group {
            if let player {
                videoPreview(player: player)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else if let error {
                errorView(error: error)
            } else {
                loadingView
                    .transition(.opacity)
            }
        }
        .navigationTitle("Exportar Clipe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generationTask = Task { await generateClip() }
        }
        .onDisappear {
            generationTask?.cancel()
            generationTask = nil
            player?.pause()
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
            }
        }
    }

    // MARK: - Subviews

    /// Mirrors the confirm screen's structure — scrollable content with the
    /// action pinned as a bottom safe-area inset — so the two feel consistent.
    private func videoPreview(player: AVPlayer) -> some View {
        let videoSize = ShareClipGenerator.videoSize
        let aspectRatio = videoSize.width / videoSize.height

        return ScrollView {
            VStack(spacing: .spacing(.xxLarge)) {
                Text("Seu clipe está pronto! 🎉")
                    .font(.title3)
                    .fontWeight(.semibold)

                VStack(spacing: .spacing(.small)) {
                    VideoPlayer(player: player)
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) { muteButton }

                    if let clipDetails {
                        Text(clipDetails)
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, .spacing(.xLarge))
            .padding(.vertical, .spacing(.large))
        }
        .safeAreaInset(edge: .bottom) {
            shareButton
                .padding(.horizontal, .spacing(.xLarge))
                .padding(.vertical, .spacing(.small))
                .background(.bar)
        }
    }

    /// The clip auto-plays muted, so this is the one way to hear it here.
    private var muteButton: some View {
        Button {
            isMuted.toggle()
            player?.isMuted = isMuted
        } label: {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.5), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .padding(.spacing(.small))
        .accessibilityLabel(isMuted ? "Ativar som" : "Silenciar")
    }

    /// Quiet spec line: duration, pixel dimensions, format and file size.
    private var clipDetails: String? {
        guard let videoURL else { return nil }
        let size = ShareClipGenerator.videoSize
        var parts: [String] = [(max(config.clipEnd - config.clipStart, 0)).asPlaybackTime]
        parts.append("\(Int(size.width))×\(Int(size.height))")
        parts.append("MP4")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path),
           let bytes = (attributes[.size] as? NSNumber)?.int64Value {
            parts.append(bytes.formatted(.byteCount(style: .file)))
        }
        return parts.joined(separator: " · ")
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: .spacing(.large)) {
            ContentUnavailableView(
                "Erro ao gerar clipe",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )

            Button {
                retryGeneration()
            } label: {
                Label("Tentar Novamente", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .shareClipButtonStyle()
            .padding(.horizontal, .spacing(.xLarge))
        }
    }

    private var loadingView: some View {
        VStack(spacing: .spacing(.medium)) {
            ProgressView()
                .controlSize(.large)

            Text(generationPhase?.rawValue ?? "Preparando…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: generationPhase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shareButton: some View {
        Button {
            guard let videoURL else { return }
            presentShareSheet(for: videoURL)
        } label: {
            HStack {
                Spacer()
                Label("Compartilhar Clipe", systemImage: "square.and.arrow.up")
                    .font(.headline)
                Spacer()
            }
        }
        .shareClipButtonStyle()
    }

    // MARK: - Generation

    private func generateClip() async {
        do {
            let url = try await ShareClipGenerator.generate(
                config: config
            ) { phase in
                Task { @MainActor in
                    generationPhase = phase
                }
            }
            videoURL = url

            // Auto-play muted on a loop: the movement makes it obvious this is
            // a playable video, without blasting audio the user already vetted.
            let avPlayer = AVPlayer(url: url)
            avPlayer.isMuted = true
            isMuted = true
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: avPlayer.currentItem,
                queue: .main
            ) { _ in
                avPlayer.seek(to: .zero)
                avPlayer.play()
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.35)) {
                player = avPlayer
            }
            avPlayer.play()
        } catch is CancellationError {
            // Task cancelled
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error
            Task {
                await AnalyticsService().send(
                    originatingScreen: "ShareClip",
                    action: "clip_generation_failed(transcript=\(config.includesTranscript), error=\(error.localizedDescription))"
                )
            }
        }
    }

    private func retryGeneration() {
        error = nil
        generationPhase = nil
        generationTask?.cancel()
        generationTask = Task { await generateClip() }
    }

    // MARK: - Sharing

    /// Presents the share sheet imperatively from the top-most view controller.
    ///
    /// This screen lives three sheets deep (Now Playing › Create Clip › this
    /// pushed view), so a SwiftUI `.sheet` for the activity controller silently
    /// fails to present. Presenting via UIKit from the top-most VC sidesteps it.
    @MainActor
    private func presentShareSheet(for url: URL) {
        guard let top = UIApplication.shared.topMostViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        activityVC.completionWithItemsHandler = { [onExportComplete, config] _, completed, _, _ in
            guard completed else { return }
            onExportComplete(config.includesTranscript)
        }
        top.present(activityVC, animated: true)
    }
}

// MARK: - Shared Button Style

extension View {

    @ViewBuilder
    func shareClipButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .controlSize(.large)
                .buttonStyle(.glassProminent)
                .tint(.orange)
        } else {
            self
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
    }
}
