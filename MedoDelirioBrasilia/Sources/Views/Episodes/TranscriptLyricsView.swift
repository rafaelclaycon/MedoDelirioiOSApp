//
//  TranscriptLyricsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 31/10/26.
//

import SwiftUI

/// The whole transcript, read like song lyrics, for wide layouts where the three live lines
/// would float in empty space: big type, the line being said bold and centered, the rest
/// dimmed, said lines more than upcoming ones. It follows playback, steps aside for a few
/// seconds while the person scrolls, and a tapped line plays from there.
struct TranscriptLyricsView: View {

    let transcriptProvider: TranscriptProvider
    let onDisableTranscripts: () -> Void
    let onPlayCue: (SRTCue) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// When the person last scrolled by hand. Following waits a little after that, so it
    /// doesn't yank the text away from what they're reading.
    @State private var lastManualScroll: Date = .distantPast

    private static let followPause: TimeInterval = 4
    private static let readableWidth: CGFloat = 640

    var body: some View {
        if case .loaded(let cues) = transcriptProvider.state {
            VStack(spacing: 0) {
                lines(cues)

                TranscriptAIFooter(onDisableTranscripts: onDisableTranscripts)
                    .frame(maxWidth: Self.readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, .spacing(.xLarge))
                    .padding(.vertical, .spacing(.small))
            }
        }
    }

    private func lines(_ cues: [SRTCue]) -> some View {
        let current = transcriptProvider.currentCue

        return GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: .spacing(.medium)) {
                        ForEach(cues) { cue in
                            LyricLine(cue: cue, distance: current.map { cue.index - $0.index }) {
                                onPlayCue(cue)
                            }
                            .id(cue.id)
                        }
                    }
                    .frame(maxWidth: Self.readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, .spacing(.xLarge))
                }
                // Half the height above the first line and below the last, so either can
                // come to the middle like the rest.
                .contentMargins(.vertical, geometry.size.height / 2, for: .scrollContent)
                .scrollIndicators(.hidden)
                .mask(fadeAtTheEdges)
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting {
                        lastManualScroll = .now
                    }
                }
                .onAppear {
                    if let id = current?.id {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                .onChange(of: current?.id) { _, id in
                    guard let id, Date.now.timeIntervalSince(lastManualScroll) > Self.followPause else { return }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.6)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    /// Lines fade in and out at the top and bottom instead of being cut.
    private var fadeAtTheEdges: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Line

private struct LyricLine: View {

    let cue: SRTCue
    /// Lines away from the one being said: negative for said lines, nil before playback
    /// reaches the first.
    let distance: Int?
    let onPlay: () -> Void

    private var isCurrent: Bool { distance == 0 }

    /// Said lines step back more than upcoming ones, which the eye goes to next.
    private var opacity: Double {
        switch distance {
        case 0: 1
        case let distance? where distance < 0: 0.3
        default: 0.5
        }
    }

    var body: some View {
        Button(action: onPlay) {
            Text(cue.text)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .opacity(opacity)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.3), value: isCurrent)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copiar", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = cue.text
            }
        }
        .accessibilityHint("Toque para ouvir a partir deste trecho")
    }
}

// MARK: - Preview

#Preview {
    TranscriptLyricsView(transcriptProvider: .mockLoadedFullTranscript(), onDisableTranscripts: {}, onPlayCue: { _ in })
}
