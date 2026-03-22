//
//  TranscriptOverlayView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/03/26.
//

import SwiftUI

/// Displays SRT cues in an Apple Music lyrics style: previous line dimmed above,
/// current line highlighted in the center, next line dimmed below.
struct TranscriptOverlayView: View {

    let previousCue: SRTCue?
    let currentCue: SRTCue?
    let nextCue: SRTCue?

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.medium)) {
            cueText(previousCue?.text, role: .surrounding)

            cueText(currentCue?.text, role: .active)
                .id(currentCue?.id)

            cueText(nextCue?.text, role: .surrounding)
        }
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 400, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: currentCue?.id)
    }

    // MARK: - Subviews

    private func cueText(_ text: String?, role: CueRole) -> some View {
        Text(text ?? " ")
            .font(role == .active ? .title2 : .body)
            .fontWeight(role == .active ? .semibold : .regular)
            .foregroundStyle(role == .active ? .primary : .tertiary)
            .multilineTextAlignment(.leading)
            .lineLimit(5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum CueRole {
        case active
        case surrounding
    }
}

/// Shown when no SRT transcript is available for the current episode.
struct TranscriptDebugView: View {

    let reason: String

    var body: some View {
        VStack(spacing: .spacing(.small)) {
            Image(systemName: "text.quote")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 400)
    }
}

// MARK: - Preview

#Preview("With cues") {
    TranscriptOverlayView(
        previousCue: SRTCue(index: 1, startTime: 0, endTime: 3, text: "Boa noite, boa noite."),
        currentCue: SRTCue(index: 2, startTime: 3, endTime: 6, text: "Hoje o assunto é sério, gente."),
        nextCue: SRTCue(index: 3, startTime: 6, endTime: 9, text: "Vamos lá que o bagulho tá doido.")
    )
}

#Preview("Debug - not available") {
    TranscriptDebugView(reason: "Transcrição não encontrada para o episódio 12345.")
}
