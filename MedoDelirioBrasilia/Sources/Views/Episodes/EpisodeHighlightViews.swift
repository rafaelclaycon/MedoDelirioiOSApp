//
//  EpisodeHighlightViews.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/10/26.
//

import SwiftUI

/// How a highlighted episode's row is dressed, by style. `lulaWin`: the Retrospectiva's
/// red, a red edge on the leading side and stars rising behind the text, like election
/// night confetti, faint enough to read over.

// MARK: - Badge

/// A small capsule over the date, with a star that beats slowly.
struct EpisodeHighlightBadge: View {

    let highlight: EpisodeHighlightStore.Highlight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBeating = false

    private var text: String {
        highlight.label ?? "Episódio especial"
    }

    var body: some View {
        switch highlight.style {
        case .lulaWin:
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .scaleEffect(isBeating ? 1.25 : 1)
                Text(text.uppercased())
                    .tracking(0.6)
            }
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(RetroPalette.red))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isBeating = true
                }
            }
        }
    }
}

// MARK: - Background

/// Goes in the row's `listRowBackground`, so it fills the row edge to edge.
struct EpisodeHighlightBackground: View {

    let style: EpisodeHighlightStore.Style

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch style {
        case .lulaWin:
            if reduceMotion {
                lulaWin(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    lulaWin(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    /// A light red wash in light mode, a deep wine in dark; red stars on the light one,
    /// white on the dark.
    private func lulaWin(at time: TimeInterval) -> some View {
        ZStack(alignment: .leading) {
            Color(.systemBackground)
            (colorScheme == .dark ? RetroPalette.wine.opacity(0.75) : RetroPalette.red.opacity(0.08))

            RisingStars(
                time: time,
                color: colorScheme == .dark ? .white : RetroPalette.red,
                intensity: colorScheme == .dark ? 0.45 : 0.35
            )

            RetroPalette.red
                .frame(width: 4)
        }
    }
}

// MARK: - Row Background

extension View {

    /// The highlight's background for a highlighted row; the list's own for the rest.
    @ViewBuilder
    func episodeHighlightRowBackground(_ highlight: EpisodeHighlightStore.Highlight?) -> some View {
        if let highlight {
            listRowBackground(EpisodeHighlightBackground(style: highlight.style))
        } else {
            self
        }
    }
}
