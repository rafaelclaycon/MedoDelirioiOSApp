//
//  YouNumbersView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// A few counts right below the hero, so even a fresh install has something there.
///
/// Solid cards rather than glass: they're for reading, not tapping, and they sit on the
/// end of the hero's fade, which made see-through cards hard to read.
struct YouNumbersView: View {

    @Environment(EpisodePlayedStore.self) private var playedStore

    @State private var shareCount = 0
    @State private var favoriteCount = 0

    /// An `HStack` sized to its tallest card, with every card filling that height, so a
    /// label that wraps doesn't leave the others shorter.
    var body: some View {
        HStack(alignment: .top, spacing: .spacing(.small)) {
            StatCard(
                value: shareCount,
                label: "Compartilhamentos",
                systemImage: "square.and.arrow.up",
                color: .green
            )

            StatCard(
                value: favoriteCount,
                label: "Favoritas",
                systemImage: "star.fill",
                color: .orange
            )

            StatCard(
                value: playedStore.playedIDs.count,
                label: "Episódios Finalizados",
                systemImage: "checkmark.circle.fill",
                color: .teal
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .onAppear {
            shareCount = (try? LocalDatabase.shared.getUserShareLogCount()) ?? 0
            favoriteCount = (try? LocalDatabase.shared.favoriteCount()) ?? 0
        }
    }
}

// MARK: - Stat Card

extension YouNumbersView {

    struct StatCard: View {

        let value: Int
        let label: String
        let systemImage: String
        let color: Color

        private static let cornerRadius: CGFloat = 18

        /// A label of several words wraps between them; a single long word shrinks a
        /// little instead of breaking in the middle.
        private var labelLineLimit: Int {
            label.contains(" ") ? 2 : 1
        }

        var body: some View {
            VStack(spacing: .spacing(.xxxSmall)) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(color)

                Text(value, format: .number)
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(labelLineLimit)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.vertical, .spacing(.small))
            .padding(.horizontal, .spacing(.xSmall))
            // White in light mode, the raised dark gray in dark mode.
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label): \(value)")
        }
    }
}

#Preview {
    YouNumbersView()
        .padding(.vertical)
        .background(Color.green.opacity(0.4))
        .environment(EpisodePlayedStore(database: FakeLocalDatabase()))
}
