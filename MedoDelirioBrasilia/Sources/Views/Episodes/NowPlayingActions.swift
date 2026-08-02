//
//  NowPlayingActions.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import SwiftUI

/// The now-playing screen's action buttons, shared by the iOS 26 native bottom
/// bar and the custom `NowPlayingLegacyBottomBar` used below it.
///
/// Each button is its own small view so the two bars can arrange them
/// differently without duplicating their behaviour.
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

    struct Share: View {

        let isPreparing: Bool
        let onShare: () -> Void

        var body: some View {
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(isPreparing)
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

// MARK: - Legacy Bottom Bar

/// Reproduces the iOS 26 bottom bar's actions in a neutral gray, rounded bar for
/// iOS < 26, which otherwise gets plain, accent-tinted `.bottomBar` chrome that
/// doesn't fit the rest of the screen.
///
/// Attach via `safeAreaInset(edge: .bottom)` so it reserves the same space a
/// native bottom bar would.
struct NowPlayingLegacyBottomBar: View {

    let isPreparingShare: Bool
    let onAddBookmark: () -> Void
    let onShareClip: () -> Void
    let onShare: () -> Void
    let onOpenTranscript: () -> Void

    var body: some View {
        HStack(spacing: .spacing(.xxLarge)) {
            NowPlayingActions.Bookmark(onAdd: onAddBookmark)

            NowPlayingActions.ShareClip(onShare: onShareClip)

            NowPlayingActions.Favorite()

            NowPlayingActions.Share(isPreparing: isPreparingShare, onShare: onShare)

            if FeatureFlag.isEnabled(.transcriptFullView) {
                NowPlayingActions.Transcript(onOpen: onOpenTranscript)
            }
        }
        .font(.body)
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .padding(.horizontal, .spacing(.xLarge))
        .padding(.vertical, .spacing(.medium))
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: .spacing(.huge), style: .continuous))
        .padding(.horizontal, .spacing(.medium))
        .padding(.bottom, .spacing(.xSmall))
    }
}
