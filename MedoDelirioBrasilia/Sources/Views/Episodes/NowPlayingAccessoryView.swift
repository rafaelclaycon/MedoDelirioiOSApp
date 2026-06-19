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

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

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

    var body: some View {
        if let episode {
            HStack(spacing: .spacing(.xSmall)) {
                artwork(for: episode)

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

                controls
            }
            .padding(.leading, .spacing(.xSmall))
            .padding(.trailing, placement == .expanded ? .spacing(.medium) : .spacing(.xSmall))
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

    private func artwork(for episode: PodcastEpisode) -> some View {
        KFImage(episode.imageURL)
            .placeholder {
                Image(systemName: "radio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 7))
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
                        .fill(Color.primary.opacity(0.6))
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

    private var controls: some View {
        HStack(spacing: .spacing(.medium)) {
            if !isInline {
                Button {
                    player.skipBackward()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body)
                        .fontWeight(.bold)
                }
                .buttonStyle(.plain)
            }

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            if !isInline {
                Button {
                    player.skipForward()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                        .fontWeight(.bold)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
