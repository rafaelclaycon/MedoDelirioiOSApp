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
    var onExportComplete: () -> Void = {}

    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State private var generationPhase: ShareClipGenerator.GenerationPhase?
    @State private var error: Error?
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let player {
                videoPreview(player: player)
            } else if let error {
                errorView(error: error)
            } else {
                loadingView
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
        }
    }

    // MARK: - Subviews

    private func videoPreview(player: AVPlayer) -> some View {
        let videoSize = config.shareMode.videoSize ?? CGSize(width: 9, height: 16)
        let aspectRatio = videoSize.width / videoSize.height

        return VStack(spacing: .spacing(.xxLarge)) {
            Spacer()

            VideoPlayer(player: player)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            shareButton

            Spacer()
        }
        .padding(.horizontal, .spacing(.xLarge))
        .padding(.vertical, .spacing(.large))
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
            player = AVPlayer(url: url)
        } catch is CancellationError {
            // Task cancelled
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error
            Task { await AnalyticsService().send(originatingScreen: "ShareClip", action: "clip_generation_failed(\(error.localizedDescription))") }
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
        activityVC.completionWithItemsHandler = { [onExportComplete] _, completed, _, _ in
            guard completed else { return }
            onExportComplete()
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
