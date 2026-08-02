//
//  NowPlayingArtworkCanvas.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import SwiftUI
import Kingfisher

/// The now-playing screen's cover-art canvas. Also stands in for the transcript
/// canvas before a transcript has loaded.
struct NowPlayingArtworkCanvas: View {

    @Environment(EpisodePlayer.self) private var player
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        KFImage(player.currentEpisode?.imageURL)
            .placeholder {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onFailure { _ in }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 300, maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: player.isPlaying
                    ? (colorScheme == .dark ? .green.opacity(0.4) : .black.opacity(0.25))
                    : .clear,
                radius: colorScheme == .dark ? 16 : 8,
                y: colorScheme == .dark ? 0 : 4
            )
            .scaleEffect(player.isPlaying ? 1.0 : 0.88)
            .animation(.spring(duration: 0.35, bounce: 0.4), value: player.isPlaying)
    }
}

#Preview {
    let player: EpisodePlayer = {
        let player = EpisodePlayer()
        player.currentEpisode = .mockRecent
        return player
    }()

    return NowPlayingArtworkCanvas()
        .environment(player)
}
