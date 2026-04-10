//
//  NowPlayingAccessoryView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import SwiftUI
import Kingfisher

/// A compact now-playing view designed for the iOS 26 tab bar bottom accessory.
///
/// Shows the episode artwork, title, and a play/pause toggle button.
/// The liquid glass capsule background is automatically applied by `tabViewBottomAccessory`.
@available(iOS 26.0, *)
struct NowPlayingAccessoryView: View {

    let episode: PodcastEpisode?
    let player: EpisodePlayer

    var body: some View {
        if let episode {
            HStack(spacing: .spacing(.xSmall)) {
                KFImage(episode.imageURL)
                    .placeholder {
                        Image(systemName: "radio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(episode.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .marquee()

                Spacer(minLength: 0)

                Button {
                    Task {
                        await player.togglePlayPause()
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, .spacing(.xSmall))
            .padding(.trailing, .spacing(.medium))
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
}
