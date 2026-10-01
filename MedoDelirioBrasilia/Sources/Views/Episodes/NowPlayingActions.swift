//
//  NowPlayingActions.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import SwiftUI

/// The now-playing screen's action buttons, each its own small view so the
/// native bottom bar can arrange them without duplicating their behaviour.
enum NowPlayingActions {

    struct Bookmark: View {

        let onAdd: () -> Void

        var body: some View {
            Button(action: onAdd) {
                Image(systemName: "bookmark")
            }
        }
    }

    struct ShareClip: View {

        let onShare: () -> Void

        var body: some View {
            Button(action: onShare) {
                Image(systemName: "scissors")
            }
        }
    }

    struct Favorite: View {

        @Environment(EpisodePlayer.self) private var player
        @Environment(EpisodeFavoritesStore.self) private var favoritesStore

        private var isFavorite: Bool {
            player.currentEpisode.map { favoritesStore.isFavorite($0.id) } ?? false
        }

        var body: some View {
            Button {
                guard let episodeId = player.currentEpisode?.id else { return }
                favoritesStore.toggle(episodeId)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .primary)
            }
        }
    }

    /// Shares the episode's link. `image` is the preview image, loaded by the screen ahead
    /// of time (see `LinkShareButton`).
    struct Share: View {

        let episode: PodcastEpisode?
        let image: Image?

        var body: some View {
            if let episode, let url = URL(string: APIConfig.baseLinkURL + "episodio/\(episode.id)") {
                LinkShareButton(
                    url: url,
                    title: episode.title,
                    image: image,
                    placeholderSymbol: "radio",
                    accessibilityLabel: "Compartilhar episódio",
                    onShared: { [id = episode.id] in
                        Task { await AnalyticsService().send(originatingScreen: "NowPlaying", action: "didShareLink(\(id))") }
                    }
                )
            }
        }
    }

    struct Transcript: View {

        let onOpen: () -> Void

        var body: some View {
            Button(action: onOpen) {
                Image(systemName: "magnifyingglass")
            }
        }
    }

    struct Close: View {

        let onClose: () -> Void

        var body: some View {
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
        }
    }
}
