//
//  TranscriptFullView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/05/26.
//

import SwiftUI

/// The episode's whole transcript, searchable, opened from Now Playing. Text and search
/// only: playback pauses on the way in, and tapping a line plays from there.
struct TranscriptFullView: View {

    /// Where the transcript is shown, which decides where the search field goes.
    enum Presentation {
        /// Pushed over Now Playing as its own screen, searching from the navigation bar.
        case screen
        /// In the canvas pane of Now Playing's split layout (unfolded iPhone Duo, wide
        /// iPad or Mac window). The other pane keeps the cover and the transport, and the
        /// navigation bar spans both panes, crease included, so the search field sits at
        /// the top of this one instead.
        case pane(onClose: () -> Void)
    }

    let transcriptProvider: TranscriptProvider
    /// Held by Now Playing, so the query is still there when search is opened again
    /// after playing a line.
    @Binding var searchText: String
    var presentation: Presentation = .screen
    let onPlayCue: (SRTCue) -> Void
    /// The lines matching the query, or nil with no query. Recomputed when the query or
    /// the cues change rather than in `body`, which also re-runs every time the current
    /// line advances.
    @State private var matchingCues: [SRTCue]?

    private static let searchPrompt = "Buscar na transcrição"

    /// Keeps lines to a comfortable length where the screen is wide (unfolded iPhone Duo
    /// in portrait, iPad).
    private static let readableWidth: CGFloat = 640

    private var allCues: [SRTCue] {
        if case .loaded(let cues) = transcriptProvider.state { return cues }
        return []
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            switch presentation {
            case .screen:
                content
                    .navigationTitle("Transcrição")
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Self.searchPrompt
                    )
            case .pane(let onClose):
                VStack(spacing: 0) {
                    paneSearchBar(onClose: onClose)
                    content
                }
            }
        }
        .onChange(of: searchText) { updateMatches() }
        .onChange(of: allCues.count) { updateMatches() }
        // A query kept from the last time search was open.
        .onAppear { updateMatches() }
    }

    private func updateMatches() {
        let query = query
        guard !query.isEmpty else {
            matchingCues = nil
            return
        }
        // Case and accent insensitive: people type "nao" for "não".
        matchingCues = allCues.filter { $0.text.localizedStandardContains(query) }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if allCues.isEmpty {
            ContentUnavailableView(
                "Transcrição indisponível",
                systemImage: "text.quote",
                description: Text("A transcrição deste episódio não foi carregada.")
            )
            .frame(maxHeight: .infinity)
        } else if let matchingCues, matchingCues.isEmpty {
            ContentUnavailableView.search(text: query)
                .frame(maxHeight: .infinity)
        } else {
            cueList(matchingCues ?? allCues)
        }
    }

    private func cueList(_ cues: [SRTCue]) -> some View {
        let currentCueID = transcriptProvider.currentCue?.id

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(cues) { cue in
                        FullTranscriptLineRow(cue: cue, query: query, isCurrent: cue.id == currentCueID) {
                            onPlayCue(cue)
                        }
                        .id(cue.id)
                    }
                }
                .frame(maxWidth: Self.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, .spacing(.small))
                .padding(.vertical, .spacing(.small))
            }
            .scrollDismissesKeyboard(.immediately)
            // Opens on the line being played, and goes back to it when a search is
            // cleared, rather than at the top of a long episode.
            .onAppear {
                scrollToCurrentCue(proxy)
            }
            .onChange(of: matchingCues == nil) { _, isShowingAll in
                if isShowingAll {
                    scrollToCurrentCue(proxy)
                }
            }
        }
    }

    private func scrollToCurrentCue(_ proxy: ScrollViewProxy) {
        guard let id = transcriptProvider.currentCue?.id else { return }
        proxy.scrollTo(id, anchor: .center)
    }

    // MARK: - Pane Search Bar

    private func paneSearchBar(onClose: @escaping () -> Void) -> some View {
        HStack(spacing: .spacing(.small)) {
            HStack(spacing: .spacing(.xSmall)) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(Self.searchPrompt, text: $searchText)
                    .submitLabel(.search)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Limpar busca")
                }
            }
            .padding(.horizontal, .spacing(.small))
            .padding(.vertical, .spacing(.xSmall))
            .background(.quaternary, in: Capsule())

            Button("Fechar", action: onClose)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: Self.readableWidth)
        .padding(.horizontal, .spacing(.xLarge))
        .padding(.bottom, .spacing(.xSmall))
    }
}

// MARK: - Cue Row

private struct FullTranscriptLineRow: View {

    let cue: SRTCue
    /// Already trimmed. Empty when not searching.
    let query: String
    let isCurrent: Bool
    let onPlay: () -> Void

    var body: some View {
        // The whole line is the target: a search result is something to jump to, and the
        // timestamp alone is too small to aim for. Copying moves to the context menu.
        Button(action: onPlay) {
            HStack(alignment: .firstTextBaseline, spacing: .spacing(.medium)) {
                Text(cue.startTime.asPlaybackTime)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.darkerGreen)
                    .frame(width: 52, alignment: .leading)

                Text(highlightedText)
                    .font(.body)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, .spacing(.xSmall))
            .padding(.horizontal, .spacing(.small))
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copiar", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = cue.text
            }
        }
        .accessibilityHint("Toque para ouvir a partir deste trecho")
    }

    /// The line with every occurrence of the query picked out. Matches the same way the
    /// filter does, ignoring case and accents.
    private var highlightedText: AttributedString {
        var text = AttributedString(cue.text)
        guard !query.isEmpty else { return text }

        var searchStart = text.startIndex
        while let range = text[searchStart...].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            text[range].foregroundColor = Color.darkerGreen
            text[range].inlinePresentationIntent = .stronglyEmphasized
            searchStart = range.upperBound
        }
        return text
    }
}

// MARK: - Preview

#Preview("Screen") {
    @Previewable @State var searchText = ""

    NavigationStack {
        TranscriptFullView(
            transcriptProvider: .mockLoaded(),
            searchText: $searchText,
            onPlayCue: { _ in }
        )
    }
}

#Preview("Pane") {
    @Previewable @State var searchText = ""

    TranscriptFullView(
        transcriptProvider: .mockLoaded(),
        searchText: $searchText,
        presentation: .pane(onClose: {}),
        onPlayCue: { _ in }
    )
}
