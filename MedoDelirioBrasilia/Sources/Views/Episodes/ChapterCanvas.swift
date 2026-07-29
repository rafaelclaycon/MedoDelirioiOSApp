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

    var body: some View {
        switch chapterProvider.state {
        case .idle:
            EmptyView()

        case .notAvailable(let reason):
            unavailableView(reason: reason)

        case .loaded(let chapters):
            chapterList(chapters)
        }
    }

    // MARK: - List

    private func chapterList(_ chapters: [EpisodeChapter]) -> some View {
        let currentChapterID = chapterProvider.currentChapter?.id
        let episodeDuration = player.duration

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Capítulos")
                    .font(.headline)

                Spacer()

                Text("\(chapters.count)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, .spacing(.small))

            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                Button {
                    player.seek(to: chapter.start)
                } label: {
                    ChapterRow(
                        chapter: chapter,
                        length: Self.length(
                            at: index,
                            in: chapters,
                            episodeDuration: episodeDuration
                        ),
                        isCurrent: chapter.id == currentChapterID
                    )
                }
                .buttonStyle(.plain)

                if index < chapters.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func unavailableView(reason: String) -> some View {
        VStack(spacing: .spacing(.small)) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(reason)
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

    let chapter: EpisodeChapter
    let length: TimeInterval?
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spacing(.small)) {
            Text(chapter.formattedStart)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Color.darkerGreen : .secondary)
                .frame(width: 52, alignment: .leading)

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
        .padding(.vertical, .spacing(.xSmall))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        var label = "\(chapter.title), começa em \(chapter.formattedStart)"
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
                ChapterCanvas(chapterProvider: .mockLoaded())
                    .padding(.horizontal, .spacing(.xLarge))
                    .environment(player)
            }
        }
    }
    return Host()
}

#Preview("Sem capítulos") {
    ChapterCanvas(chapterProvider: .mockNotAvailable())
        .environment(EpisodePlayer())
}
