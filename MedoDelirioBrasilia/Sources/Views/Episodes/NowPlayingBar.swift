//
//  NowPlayingBar.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import SwiftUI
import Kingfisher

/// A floating mini-player bar for platforms without `tabViewBottomAccessory`
/// (iOS <26, iPad, Mac). Uses a Material background instead of Liquid Glass.
struct NowPlayingBar: View {

    let episode: PodcastEpisode?
    let player: EpisodePlayer

    var body: some View {
        if let episode {
            HStack(spacing: 10) {
                KFImage(episode.imageURL)
                    .placeholder {
                        Image(systemName: "radio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if player.isPlaying {
                        Text("Reproduzindo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Pausado")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: .spacing(.xLarge)) {
                    Button {
                        Task {
                            await player.skipBackward()
                        }
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.body)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await player.togglePlayPause()
                        }
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, .spacing(.small))
            .padding(.leading, .spacing(.medium))
            .padding(.trailing, .spacing(.large))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
    }
}

#Preview {
    NowPlayingBar(
        episode: .mockLastWeek,
        player: EpisodePlayer()
    )
    .padding()
}
