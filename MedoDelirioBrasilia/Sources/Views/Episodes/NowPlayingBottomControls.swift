//
//  NowPlayingBottomControls.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import SwiftUI

/// The now-playing screen's fixed lower half: episode (or chapter) label,
/// scrubber, and transport controls.
///
/// The pieces that read `player.currentTime` — `ProgressScrubber` and
/// `ChapterControlView`'s countdown — keep that read inside themselves, so the
/// screen's toolbar host isn't invalidated twice a second.
struct NowPlayingBottomControls: View {

    let chapterProvider: ChapterProvider
    let chaptersEnabled: Bool
    /// Tapping the chapter title jumps to the chapters canvas.
    let onTapChapterTitle: () -> Void

    @Environment(EpisodePlayer.self) private var player
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore

    private var currentBookmarks: [EpisodeBookmark] {
        guard let episodeId = player.currentEpisode?.id else { return [] }
        return bookmarkStore.bookmarks(for: episodeId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // With chapters available the control stands in for the episode
            // title and date — the chapter name is the more useful label while
            // you're mid-episode.
            if chaptersEnabled, chapterProvider.hasChapters {
                ChapterControlView(
                    player: player,
                    chapterProvider: chapterProvider,
                    onTapTitle: onTapChapterTitle
                )
            } else {
                episodeInfo
            }

            Spacer()
                .frame(height: .spacing(.medium))

            ProgressScrubber(player: player, bookmarks: currentBookmarks)

            Spacer()
                .frame(height: .spacing(.small))

            playbackControls

            Spacer()
                .frame(height: .spacing(.medium))
        }
        .padding(.horizontal, .spacing(.xLarge))
    }

    // MARK: - Episode Info

    private var episodeInfo: some View {
        VStack(spacing: .spacing(.xxSmall)) {
            Text(player.currentEpisode?.title ?? "")
                .font(.title2)
                .fontDesign(.serif)
                .fontWeight(.semibold)
                .marquee(spacing: 40, delay: 2, speedBasis: .velocity(40), fadeWidth: 16, centersWhenFitting: true)

            if let pubDate = player.currentEpisode?.pubDate {
                Text(pubDate, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        ZStack {
            HStack(spacing: .spacing(.large)) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .fontWeight(.medium)
                        .padding(.all, .spacing(.small))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 74))
                        .contentTransition(.symbolEffect(.replace.wholeSymbol))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .fontWeight(.medium)
                        .padding(.all, .spacing(.small))
                }
                .buttonStyle(.plain)
            }

            HStack {
                speedButton
                Spacer()
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Speed Control

    private var speedButton: some View {
        Menu {
            ForEach(EpisodePlayer.availableSpeeds, id: \.self) { speed in
                Button {
                    player.setSpeed(speed)
                } label: {
                    if speed == player.playbackSpeed {
                        Label(EpisodePlayer.formattedSpeed(speed), systemImage: "checkmark")
                    } else {
                        Text(EpisodePlayer.formattedSpeed(speed))
                    }
                }
            }
        } label: {
            Text(EpisodePlayer.formattedSpeed(player.playbackSpeed))
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .padding(.vertical, .spacing(.xSmall))
                .padding(.trailing, .spacing(.medium))
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Scrubber

/// The scrubber and elapsed/remaining time labels. Owns its scrubbing gesture state
/// and reads `player.currentTime` itself, so the parent body — which hosts the
/// navigation toolbar — isn't re-evaluated on every playback tick.
private struct ProgressScrubber: View {

    let player: EpisodePlayer
    let bookmarks: [EpisodeBookmark]

    @State private var isScrubbing: Bool = false
    @State private var scrubValue: TimeInterval = 0

    private static let trackHeight: CGFloat = 4
    private static let thumbSize: CGFloat = 14
    private static let trackColor = Color.darkerGreen
    private static let trackBgColor = Color(.systemGray4)

    var body: some View {
        VStack(spacing: .spacing(.xxxSmall)) {
            scrubber

            HStack {
                Text((isScrubbing ? scrubValue : player.currentTime).asPlaybackTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text("-" + (player.duration - (isScrubbing ? scrubValue : player.currentTime)).asPlaybackTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var scrubber: some View {
        GeometryReader { geometry in
            let totalDuration = max(player.duration, 1)
            let currentValue = isScrubbing ? scrubValue : player.currentTime
            let fraction = CGFloat(currentValue / totalDuration)
            let thumbX = fraction * geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Self.trackBgColor)
                    .frame(height: Self.trackHeight)

                Capsule()
                    .fill(Self.trackColor)
                    .frame(width: max(thumbX, 0), height: Self.trackHeight)

                ForEach(bookmarks) { bookmark in
                    let bFraction = bookmark.timestamp / totalDuration
                    let bX = geometry.size.width * bFraction

                    Capsule()
                        .fill(Color.rubyRed)
                        .frame(width: 3, height: Self.trackHeight + 12)
                        .offset(x: bX - 1.5)
                }

                Circle()
                    .fill(Self.trackColor)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .offset(x: thumbX - Self.thumbSize / 2)
            }
            .frame(height: Self.thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing { isScrubbing = true }
                        let clamped = min(max(value.location.x, 0), geometry.size.width)
                        scrubValue = TimeInterval(clamped / geometry.size.width) * totalDuration
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        player.seek(to: scrubValue)
                    }
            )
        }
        .frame(height: Self.thumbSize)
    }
}
