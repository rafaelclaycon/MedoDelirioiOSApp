//
//  YouGamesSection.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import SwiftUI

/// "Jogos" in Você: a row of game cards that scrolls sideways, each opening its game
/// full screen, and a gray one at the end asking for a donation.
struct YouGamesSection: View {

    @State private var scoreStore = GameScoreStore()
    @State private var activeGame: GameKind?
    @State private var isShowingSupport = false


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

                    Button {
                        isShowingSupport = true
                    } label: {
                        SupportCard()
                    }
                    .buttonStyle(.plain)
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
        .sheet(isPresented: $isShowingSupport) {
            StandaloneSupportView(context: .games)
                .onAppear {
                    Task {
                        await AnalyticsService().send(
                            originatingScreen: "SupportPrompt",
                            action: "support_sheet_shown(trigger=games)"
                        )
                    }
                }
        }
    }
}

// MARK: - Support Card

extension YouGamesSection {

    /// Plain gray on purpose: a note at the end of the row, not a third game.
    struct SupportCard: View {

        private static let cornerRadius: CGFloat = 28

        var body: some View {
            VStack(spacing: .spacing(.xxSmall)) {
                Text("Gostou?")
                    .font(.system(.title2, design: .rounded))
                    .bold()

                Text("Que tal fazer uma doação? 🙏")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Toque no card para ver as opções.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, .spacing(.xxSmall))
            }
            .multilineTextAlignment(.center)
            .padding(.spacing(.medium))
            .frame(width: GameEntryCard.size.width, height: GameEntryCard.size.height)
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(Color(.systemGray5))
            )
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
    }
}

#Preview {
    YouGamesSection()
}
