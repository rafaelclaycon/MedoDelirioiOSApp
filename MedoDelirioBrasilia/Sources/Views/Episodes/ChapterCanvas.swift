//
//  ChapterCanvas.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/07/26.
//

import SwiftUI

/// Chapter list for the now-playing canvas.
///
/// Reads the live chapter in its own view so the parent — which hosts the
/// navigation toolbar — isn't invalidated as playback moves between chapters.
struct ChapterCanvas: View {

    @Environment(EpisodePlayer.self) private var player
    let chapterProvider: ChapterProvider
    let onHideChapters: () -> Void
    let onReportIssue: () -> Void

    @State private var showChapterOptions: Bool = false
    @State private var showHideConfirmation: Bool = false

    var body: some View {
        switch chapterProvider.state {
        case .idle:
            EmptyView()

        case .notAvailable(let reason, let showsCoverageNotice):
            unavailableView(reason: reason, showsCoverageNotice: showsCoverageNotice)

        case .loaded(let chapters):
            chapterList(chapters)
        }
    }

    // MARK: - List

    private func chapterList(_ chapters: [EpisodeChapter]) -> some View {
        let currentChapterID = chapterProvider.currentChapter?.id
        let episodeDuration = player.duration

        // Scrolls the enclosing scroll view in `NowPlayingView`, which is what
        // actually moves — this list is rendered as its canvas content.
        return ScrollViewReader { proxy in
            list(chapters, currentChapterID: currentChapterID, episodeDuration: episodeDuration)
                .onAppear {
                    scrollToCurrentChapter(using: proxy)
                }
        }
    }

    /// Brings the playing chapter into view when the list appears — opening a
    /// 25-chapter list scrolled to the top hides where you actually are.
    private func scrollToCurrentChapter(using proxy: ScrollViewProxy) {
        guard let id = chapterProvider.currentChapter?.id else { return }

        // One runloop hop: on the first `onAppear` the rows aren't laid out yet,
        // and `scrollTo` silently does nothing for an id it can't resolve.
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func list(
        _ chapters: [EpisodeChapter],
        currentChapterID: Int?,
        episodeDuration: TimeInterval
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: .spacing(.small)) {
                Text("Gerados por IA. Pode conter erros.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    showChapterOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sobre os capítulos")
            }
            .padding(.bottom, .spacing(.xSmall))
            .alert("Capítulos", isPresented: $showChapterOptions) {
                Button("Relatar um problema") {
                    onReportIssue()
                }

                // Doesn't hide anything on its own — hands off to the
                // confirmation alert below, since this one is reachable by
                // accident and the choice is easy to mistap.
                Button("Ocultar capítulos", role: .destructive) {
                    showHideConfirmation = true
                }

                Button("Cancelar", role: .cancel) {}
            }
            .alert("Ocultar capítulos?", isPresented: $showHideConfirmation) {
                Button("Ocultar", role: .destructive) {
                    onHideChapters()
                }

                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Os capítulos deixam de aparecer no player. Você pode reativá-los nos Ajustes.")
            }

            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                let length = Self.length(at: index, in: chapters, episodeDuration: episodeDuration)
                let isCurrent = chapter.id == currentChapterID

                Button {
                    player.seek(to: chapter.start)
                } label: {
                    // Only the playing row reads `currentTime`, so the rest of the
                    // list isn't invalidated on every playback tick.
                    if isCurrent {
                        PlayingChapterRow(
                            player: player,
                            number: index + 1,
                            chapter: chapter,
                            length: length
                        )
                    } else {
                        ChapterRow(
                            number: index + 1,
                            chapter: chapter,
                            length: length,
                            isCurrent: false
                        )
                    }
                }
                .buttonStyle(.plain)
                .id(chapter.id)

                // Kept in the tree and hidden rather than omitted, so every element
                // contributes the same number of views.
                Divider()
                    .opacity(index < chapters.count - 1 ? 1 : 0)
            }

            Spacer()
                .frame(height: .spacing(.small))
        }
    }

    private func unavailableView(reason: String, showsCoverageNotice: Bool) -> some View {
        VStack(spacing: .spacing(.medium)) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(
                showsCoverageNotice ?
                    "\(reason)\n\nCapítulos estão disponíveis para episódios a partir de \(ChapterPreferences.formattedCoverageStart)." :
                    reason
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, .spacing(.large))
    }

    // MARK: - Helpers

    /// How long a chapter runs — the gap to the next one, or to the end of the
    /// episode for the last chapter. Returns nil when the episode duration isn't
    /// known yet, so the row simply omits the length.
    private static func length(
        at index: Int,
        in chapters: [EpisodeChapter],
        episodeDuration: TimeInterval
    ) -> TimeInterval? {
        let end: TimeInterval
        if index < chapters.count - 1 {
            end = chapters[index + 1].start
        } else {
            guard episodeDuration > 0 else { return nil }
            end = episodeDuration
        }

        let length = end - chapters[index].start
        return length > 0 ? length : nil
    }
}

// MARK: - Row

/// Purely presentational so SwiftUI can diff rows by value — the enclosing
/// `Button` owns the tap action.
private struct ChapterRow: View {

    let number: Int
    let chapter: EpisodeChapter
    let length: TimeInterval?
    let isCurrent: Bool

    static let cornerRadius: CGFloat = 10

    var body: some View {
        // `.center` rather than `.firstTextBaseline`: the number and length stay
        // centred against a title that wraps to two lines instead of riding up to
        // align with its first line.
        HStack(alignment: .center, spacing: .spacing(.medium)) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(isCurrent ? .bold : .medium)
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Color.darkerGreen : .secondary)
                .frame(width: 28, alignment: .leading)

            Text(chapter.title)
                .font(.body)
                .fontWeight(isCurrent ? .semibold : .regular)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let length {
                Text(Self.formattedLength(length))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, .spacing(.small))
        .padding(.horizontal, .spacing(.small))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        var label = "Capítulo \(number): \(chapter.title), começa em \(chapter.formattedStart)"
        if isCurrent {
            label += ", capítulo atual"
        }
        return label
    }

    /// Rounded to the nearest minute — chapter lengths are a glanceable signal of
    /// pacing, not something worth reading to the second.
    private static func formattedLength(_ length: TimeInterval) -> String {
        let minutes = Int((length / 60).rounded())
        return minutes < 1 ? "<1 min" : "\(minutes) min"
    }
}

// MARK: - Playing Row

/// The row for the chapter currently playing, with progress filling its
/// background. Isolated from the rest of the list because it reads
/// `player.currentTime` and so redraws on every playback tick.
private struct PlayingChapterRow: View {

    let player: EpisodePlayer
    let number: Int
    let chapter: EpisodeChapter
    let length: TimeInterval?

    var body: some View {
        ChapterRow(number: number, chapter: chapter, length: length, isCurrent: true)
            .background(progressBackground)
    }

    private var progress: CGFloat {
        guard let length, length > 0 else { return 0 }
        return min(max(CGFloat((player.currentTime - chapter.start) / length), 0), 1)
    }

    private var progressBackground: some View {
        GeometryReader { geometry in
            // Both grays are semantic, so the bar stays subtle in dark mode instead
            // of becoming a bright band behind the title.
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray6))

                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: geometry.size.width * progress)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChapterRow.cornerRadius))
        }
    }
}

// MARK: - Preview

#Preview("Com capítulos") {
    struct Host: View {
        let player: EpisodePlayer = {
            let player = EpisodePlayer()
            player.currentEpisode = .mockRecent
            player.duration = 3945
            player.currentTime = 620
            return player
        }()

        var body: some View {
            ScrollView {
                ChapterCanvas(
                    chapterProvider: .mockLoaded(),
                    onHideChapters: {},
                    onReportIssue: {}
                )
                .padding(.horizontal, .spacing(.xLarge))
                .environment(player)
            }
        }
    }
    return Host()
}

#Preview("Sem capítulos") {
    ChapterCanvas(
        chapterProvider: .mockNotAvailable(),
        onHideChapters: {},
        onReportIssue: {}
    )
    .environment(EpisodePlayer())
}
