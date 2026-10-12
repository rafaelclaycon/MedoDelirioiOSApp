//
//  GameEntryCard.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import SwiftUI

/// A colorful card that opens a game: the title up top, and the best score (or "Nunca
/// jogado") in the bottom corner.
struct GameEntryCard: View {

    let kind: GameKind
    let bestScore: Int?

    static let size = CGSize(width: 270, height: 164)
    private static let cornerRadius: CGFloat = 28

    private var status: String {
        guard let bestScore else { return "Nunca jogado" }
        return "Melhor pontuação: \(bestScore) de \(GameRoundFactory.roundCount)"
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(kind.title)
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)

                Spacer(minLength: .spacing(.xxLarge))
            }

            Spacer(minLength: 0)

            HStack(spacing: .spacing(.small)) {
                Image(systemName: kind.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(kind.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(kind.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.spacing(.medium))
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            Background(kind: kind)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .shadow(color: kind.accentColor.opacity(0.35), radius: 14, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title) \(kind.subtitle). \(status)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Background

extension GameEntryCard {

    /// The game's mesh with a soft light and the game's symbol, big and faint, in the
    /// top-right corner the title leaves free.
    struct Background: View {

        let kind: GameKind

        var body: some View {
            ZStack(alignment: .topTrailing) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.45, 0], [1, 0],
                        [0, 0.55], [0.6, 0.4], [1, 0.45],
                        [0, 1], [0.55, 1], [1, 1]
                    ],
                    colors: kind.meshColors,
                    smoothsColors: true
                )

                RadialGradient(
                    colors: [.white.opacity(0.35), .clear],
                    // With the mesh's light end, away from the title.
                    center: UnitPoint(x: 0.85, y: 0.05),
                    startRadius: 0,
                    endRadius: 200
                )
                .blendMode(.softLight)

                Image(systemName: kind.systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130)
                    .foregroundStyle(.white.opacity(0.1))
                    .rotationEffect(.degrees(12))
                    .offset(x: 24, y: -18)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    VStack {
        GameEntryCard(kind: .whoseFace, bestScore: nil)
        GameEntryCard(kind: .whoseVoice, bestScore: 7)
    }
}
