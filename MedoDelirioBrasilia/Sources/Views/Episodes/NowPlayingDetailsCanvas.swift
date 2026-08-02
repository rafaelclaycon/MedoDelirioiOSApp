//
//  NowPlayingDetailsCanvas.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import SwiftUI

/// Title, release date, running time and description for the playing episode —
/// the same fields `EpisodeDetailView`'s header shows, minus its playback and
/// delete-download controls, which belong to the episode list rather than a
/// screen already dedicated to playback.
struct NowPlayingDetailsCanvas: View {

    @Environment(EpisodePlayer.self) private var player

    var body: some View {
        if let episode = player.currentEpisode {
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                    Text(episode.title)
                        .font(.title2)
                        .fontDesign(.serif)

                    HStack(spacing: .spacing(.medium)) {
                        Label {
                            Text(episode.pubDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year())
                        } icon: {
                            Image(systemName: "calendar")
                        }

                        if let formattedDuration = episode.formattedDuration {
                            Label {
                                Text(formattedDuration)
                            } icon: {
                                Image(systemName: "clock")
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Divider()

                if let plainText = episode.plainTextDescription {
                    Text(plainText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, .spacing(.xLarge))
        }
    }
}

#Preview {
    let player: EpisodePlayer = {
        let player = EpisodePlayer()
        player.currentEpisode = .mockRecent
        return player
    }()

    return NowPlayingDetailsCanvas()
        .environment(player)
        .padding()
}
