//
//  YouGamesSection.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import SwiftUI

/// "Jogos" in Você: a row of game cards that scrolls sideways, each opening its game
/// full screen.
struct YouGamesSection: View {

    @State private var scoreStore = GameScoreStore()
    @State private var activeGame: GameKind?

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("Jogos")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            ScrollView(.horizontal) {
                HStack(spacing: .spacing(.medium)) {
                    ForEach(GameKind.allCases) { kind in
                        Button {
                            activeGame = kind
                        } label: {
                            GameEntryCard(kind: kind, bestScore: scoreStore.bestScore(for: kind))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, .spacing(.medium), for: .scrollContent)
            // The cards' colored shadows spill past the scroll view's bounds.
            .scrollClipDisabled()
        }
        .padding(.top, .spacing(.medium))
        .padding(.bottom, .spacing(.large))
        .fullScreenCover(item: $activeGame) { kind in
            GameView(kind: kind, scoreStore: scoreStore)
        }
    }
}

#Preview {
    YouGamesSection()
}
