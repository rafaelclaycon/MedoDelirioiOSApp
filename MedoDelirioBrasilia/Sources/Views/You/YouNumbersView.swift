//
//  YouNumbersView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// A few counts near the top of Você, so even a fresh install has something there.
struct YouNumbersView: View {

    @Environment(EpisodePlayedStore.self) private var playedStore

    @State private var shareCount = 0
    @State private var favoriteCount = 0

    /// An `HStack` sized to its tallest card, with every card filling that height, so a
    /// label that wraps doesn't leave the others shorter.
    var body: some View {
        HStack(alignment: .top, spacing: .spacing(.small)) {
            EpisodeStatsView.StatCard(
                value: "\(shareCount)",
                label: "Compartilhamentos",
                systemImage: "square.and.arrow.up",
                fillsHeight: true,
                shrinksLabelToFit: true
            )

            EpisodeStatsView.StatCard(
                value: "\(favoriteCount)",
                label: "Favoritas",
                systemImage: "star.fill",
                fillsHeight: true
            )

            EpisodeStatsView.StatCard(
                value: "\(playedStore.playedIDs.count)",
                label: "Episódios Finalizados",
                systemImage: "checkmark.circle.fill",
                fillsHeight: true
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .onAppear {
            shareCount = (try? LocalDatabase.shared.getUserShareLogCount()) ?? 0
            favoriteCount = (try? LocalDatabase.shared.favoriteCount()) ?? 0
        }
    }
}

#Preview {
    YouNumbersView()
        .environment(EpisodePlayedStore(database: FakeLocalDatabase()))
}
