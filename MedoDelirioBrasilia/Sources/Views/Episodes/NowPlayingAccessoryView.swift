//
//  NowPlayingAccessoryView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import SwiftUI
import Kingfisher

/// A compact now-playing view designed for the iOS 26+ tab bar bottom accessory.
///
/// Shows the episode artwork, title, progress bar with time remaining, and playback controls.
/// The liquid glass capsule background is automatically applied by `tabViewBottomAccessory`.
@available(iOS 26.0, *)
struct NowPlayingAccessoryView: View {

    let episode: PodcastEpisode?
    let player: EpisodePlayer
    let onShare: () -> Void
    let onGoToEpisode: () -> Void

    @Environment(EpisodeFavoritesStore.self) private var favoritesStore
    @Environment(EpisodePlayedStore.self) private var playedStore
    @Environment(EpisodeProgressStore.self) private var progressStore

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var colorScheme

    /// In `.inline` the accessory is collapsed into the tab bar and severely
    /// width-constrained, so we drop the progress bar and skip buttons.
    private var isInline: Bool {
        placement == .inline
    }

    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(player.currentTime / player.duration, 1)
    }

    private var timeRemaining: String {
        let remaining = max(player.duration - player.currentTime, 0)
        let total = max(Int(remaining), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "-%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "-%d:%02d", minutes, seconds)
        }
    }

    private var highlightColor: Color {
        colorScheme == .dark ? .primary : .darkestGreen
    }

    var body: some View {
        if let episode {
            if hSizeClass == .compact {
                HStack(spacing: .spacing(.xSmall)) {
                    Artwork(
                        imageURL: episode.imageURL,
                        isLarge: false
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(episode.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .marquee()

                        if !isInline {
                            progressRow
                        }
                    }

                    Spacer(minLength: 0)

                    SmallControls(
                        isInline: isInline,
                        color: highlightColor,
                        isPlaying: player.isPlaying,
                        skipBackwardAction: { player.skipBackward() },
                        playPauseAction: { player.togglePlayPause() },
                        skipForwardAction: { player.skipForward() }
                    )
                }
                .padding(.leading, .spacing(.xSmall))
                .padding(.trailing, placement == .expanded ? .spacing(.medium) : .spacing(.xSmall))
            } else {
                HStack(spacing: .spacing(.large)) {
                    LargeControls(
                        isInline: isInline,
                        color: highlightColor,
                        isPlaying: player.isPlaying,
                        skipBackwardAction: { player.skipBackward() },
                        playPauseAction: { player.togglePlayPause() },
                        skipForwardAction: { player.skipForward() }
                    )

                    Artwork(
                        imageURL: episode.imageURL,
                        isLarge: false
                    )

                    VStack(alignment: .leading, spacing: .spacing(.xxSmall)) {
                        Text(episode.title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .marquee()

                        progressRow
                    }

                    Spacer()

                    Menu {
                        Button {
                            onShare()
                        } label: {
                            Label("Compartilhar", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            favoritesStore.toggle(episode.id)
                        } label: {
                            Label(
                                favoritesStore.isFavorite(episode.id) ? "Desfavoritar" : "Marcar como Favorito",
                                systemImage: favoritesStore.isFavorite(episode.id) ? "star.slash" : "star"
                            )
                        }

                        Button {
                            toggleFinished(episode)
                        } label: {
                            Label(
                                playedStore.isPlayed(episode.id) ? "Marcar como Não Finalizado" : "Marcar como Finalizado",
                                systemImage: playedStore.isPlayed(episode.id) ? "arrow.uturn.backward" : "checkmark"
                            )
                        }

                        Button {
                            onGoToEpisode()
                        } label: {
                            Label("Ir para o Episódio", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, .spacing(.large))
                .padding(.vertical, .spacing(.xLarge))
            }
        } else {
            HStack(spacing: .spacing(.xSmall)) {
                Text("Não Reproduzindo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, .spacing(.medium))
        }
    }

    /// Marks the now-playing episode as finished: stops playback, persists progress
    /// at 100%, marks it as played, bumps the completed count, and honors the
    /// auto-delete setting. Unmarking just flips the played flag back.
    private func toggleFinished(_ episode: PodcastEpisode) {
        if playedStore.isPlayed(episode.id) {
            playedStore.toggle(episode.id)
            return
        }

        // Capture the duration before stopping, since `stop()` resets the player.
        let totalDuration = player.duration > 0 ? player.duration : (episode.duration ?? 0)

        player.stop()

        // Persist full progress so the episode reads as completely listened.
        if totalDuration > 0 {
            progressStore.save(episodeID: episode.id, currentTime: totalDuration, duration: totalDuration)
        }

        playedStore.toggle(episode.id)

        let memory = AppPersistentMemory.shared
        memory.setEpisodesCompletedCount(memory.getEpisodesCompletedCount() + 1)

        if UserSettings().getAutoDeletePlayedEpisodes() {
            try? FileManager.default.removeItem(at: EpisodePlayer.localFileURL(for: episode))
        }
    }

    private var progressRow: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width * 0.3

            HStack(spacing: .spacing(.xSmall)) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: barWidth, height: 5)

                    Capsule()
                        .fill(highlightColor)
                        .frame(width: barWidth * progress, height: 5)
                }

                Text(timeRemaining)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()

                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 10)
    }
}

// MARK: - Subviews

@available(iOS 26.0, *)
extension NowPlayingAccessoryView {

    struct Artwork: View {

        let imageURL: URL?
        let isLarge: Bool

        private var sideSize: CGFloat {
            isLarge ? 50 : 34
        }

        var body: some View {
            KFImage(imageURL)
                .placeholder {
                    Image(systemName: "radio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: sideSize, height: sideSize)
                .clipShape(RoundedRectangle(cornerRadius: isLarge ? 15 : 7))
        }
    }

    struct SmallControls: View {

        let isInline: Bool
        let color: Color
        let isPlaying: Bool
        let skipBackwardAction: () -> Void
        let playPauseAction: () -> Void
        let skipForwardAction: () -> Void

        var body: some View {
            HStack(spacing: .spacing(.medium)) {
                if !isInline {
                    Button {
                        skipBackwardAction()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    playPauseAction()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                if !isInline {
                    Button {
                        skipForwardAction()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(color)
        }
    }

    struct LargeControls: View {

        let isInline: Bool
        let color: Color
        let isPlaying: Bool
        let skipBackwardAction: () -> Void
        let playPauseAction: () -> Void
        let skipForwardAction: () -> Void

        var body: some View {
            HStack(spacing: .spacing(.xLarge)) {
                if !isInline {
                    Button {
                        skipBackwardAction()
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                            //.fontWeight(.bold)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    playPauseAction()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                if !isInline {
                    Button {
                        skipForwardAction()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title2)
                            //.fontWeight(.bold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(color)
        }
    }
}
