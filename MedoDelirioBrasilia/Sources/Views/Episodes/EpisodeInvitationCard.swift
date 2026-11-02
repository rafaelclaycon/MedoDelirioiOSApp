//
//  EpisodeInvitationCard.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/11/26.
//

import SwiftUI
import Kingfisher

/// An episode to play right where it shows, for people who have never listened to one in
/// the app. The play button is the episode rows' own, so it downloads, plays and pauses the
/// same way. See `EpisodeInvitation` for who sees it.
struct EpisodeInvitationCard: View {

    let episode: PodcastEpisode
    /// Above the episode. None where the screen already says why it's there.
    var title: String?
    /// The highlight's badge text, in place of the date, when this is the highlighted episode.
    var caption: String?
    /// Where it shows, for analytics.
    let originatingScreen: String
    /// Shows a close button when set.
    var onDismiss: (() -> Void)?
    /// Neutral, so the green play button is what stands out. Screens on a gray background
    /// pass their own card color.
    var background: Color = Color(.secondarySystemBackground)

    @Environment(EpisodePlayer.self) private var player
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        colorScheme == .dark ? .green : .darkerGreen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.medium)) {
            if let title {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: "headphones")
                        .foregroundStyle(accentColor)
                }
                .bold()
                    // Clear of the close button.
                    .padding(.trailing, onDismiss == nil ? 0 : 30)
            }

            HStack(alignment: .center, spacing: .spacing(.medium)) {
                KFImage(episode.imageURL)
                    .placeholder {
                        Image(systemName: "radio")
                            .foregroundStyle(.secondary)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                    Text(caption ?? episode.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(episode.title)
                        .font(.callout)
                        .bold()
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        // Wraps instead of cutting to one line in a scroll view's
                        // open-ended height.
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                EpisodePlaybackControlsColumn(episode: episode)
            }
        }
        .padding(.all, .spacing(.large))
        .background(background, in: RoundedRectangle(cornerRadius: 15))
        .overlay(alignment: .topTrailing) {
            if let onDismiss {
                Button {
                    Task {
                        await AnalyticsService().send(originatingScreen: originatingScreen, action: "didDismissEpisodeInvitation")
                    }
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        // Gray, not the button's tint, so play stays the only green.
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding()
                .accessibilityLabel("Fechar")
            }
        }
        .onChange(of: player.currentEpisode?.id) { _, id in
            guard id == episode.id else { return }
            Task {
                await AnalyticsService().send(originatingScreen: originatingScreen, action: "didPlayInvitedEpisode(\(episode.id))")
            }
        }
    }
}

#Preview("Vírgulas") {
    EpisodeInvitationCard(
        episode: .mockRecent,
        title: "Ouça o podcast aqui no app",
        originatingScreen: "Preview",
        onDismiss: {}
    )
    .padding()
    .environment(EpisodePlayer())
}

#Preview("Destaque, sem título") {
    EpisodeInvitationCard(
        episode: .mockLastWeek,
        caption: "Lula eleito",
        originatingScreen: "Preview"
    )
    .padding()
    .environment(EpisodePlayer())
}
