//
//  NowPlayingTranscriptCanvas.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import SwiftUI

/// The now-playing screen's transcript canvas: download prompt, unavailable
/// notice, or the live cue overlay, depending on what's on hand.
struct NowPlayingTranscriptCanvas: View {

    let transcriptProvider: TranscriptProvider

    @Environment(EpisodePlayer.self) private var player
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService

    var body: some View {
        if !transcriptDownloadService.transcriptsDownloaded {
            if case .downloading = transcriptDownloadService.state {
                TranscriptDownloadingView()
            } else {
                TranscriptDownloadPromptView(
                    icon: "text.quote",
                    title: "Acompanhe o que está sendo dito",
                    subtitle: "Baixe as transcrições para ler junto enquanto ouve. É rápido e usa poucos dados.",
                    priorityEpisodeId: player.currentEpisode?.id,
                    analyticsSource: "NowPlaying"
                )
                .frame(minHeight: 280, maxHeight: 400)
            }
        } else {
            switch transcriptProvider.state {
            case .idle:
                NowPlayingArtworkCanvas()
            case .notAvailable(let reason, let isComingSoon):
                TranscriptNotAvailableView(reason: reason, isComingSoon: isComingSoon)
            case .loaded:
                // Reads the live cues in its own view so the parent (and the toolbar)
                // isn't invalidated every tick as the highlighted cue advances.
                LoadedOverlay(transcriptProvider: transcriptProvider)
            }
        }
    }
}

// MARK: - Loaded Overlay

/// The live transcript overlay. Reads the advancing cues in its own view so the
/// parent canvas (and the toolbar above it) isn't invalidated as the highlighted
/// cue moves.
private struct LoadedOverlay: View {

    let transcriptProvider: TranscriptProvider

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
            TranscriptOverlayView(
                previousCue: transcriptProvider.previousCue,
                currentCue: transcriptProvider.currentCue,
                nextCue: transcriptProvider.nextCue
            )

            Text("Transcrição gerada por IA. Pode conter erros.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
