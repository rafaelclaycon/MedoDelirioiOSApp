//
//  YouNumbersView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// A few counts right below the hero, so even a fresh install has something there.
///
/// Solid cards rather than glass: they're mostly for reading, and they sit on the end of
/// the hero's fade, which made see-through cards hard to read. Mostly, because each is also
/// a drum (`StatDrum`), with nothing saying so: a little easter egg to play with.
struct YouNumbersView: View {

    /// For the note about the silent switch, shown by `YouView`.
    @Binding var toast: Toast?

    @Environment(EpisodePlayedStore.self) private var playedStore

    @State private var shareCount = 0
    @State private var favoriteCount = 0

    /// Once per launch is enough to make the point.
    private static var hasWarnedAboutSilence = false

    /// An `HStack` sized to its tallest card, with every card filling that height, so a
    /// label that wraps doesn't leave the others shorter.
    var body: some View {
        HStack(alignment: .top, spacing: .spacing(.small)) {
            StatCard(
                value: shareCount,
                label: "Compartilhamentos",
                systemImage: "square.and.arrow.up",
                color: .green,
                drum: .kick,
                onHit: { hit(.kick) }
            )

            StatCard(
                value: favoriteCount,
                label: "Favoritas",
                systemImage: "star.fill",
                color: .orange,
                drum: .snare,
                onHit: { hit(.snare) }
            )

            StatCard(
                value: playedStore.playedIDs.count,
                label: "Episódios Finalizados",
                systemImage: "checkmark.circle.fill",
                color: .teal,
                drum: .hiHat,
                onHit: { hit(.hiHat) }
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .onAppear {
            shareCount = (try? LocalDatabase.shared.getUserShareLogCount()) ?? 0
            favoriteCount = (try? LocalDatabase.shared.favoriteCount()) ?? 0
            StatDrumKit.shared.prepare()
        }
    }

    // MARK: - Drums

    private func hit(_ drum: StatDrum) {
        StatDrumKit.shared.play(drum, onSilenced: drumWasSilenced)
    }

    private func drumWasSilenced() {
        guard !Self.hasWarnedAboutSilence else { return }
        Self.hasWarnedAboutSilence = true
        toast = Toast(message: Self.silencedMessage, type: .silenced)
    }

    static let silencedMessage = "Tá no silencioso! Desliga o modo silencioso pra ouvir a bateria 🥁"
}

// MARK: - Stat Card

extension YouNumbersView {

    struct StatCard: View {

        let value: Int
        let label: String
        let systemImage: String
        let color: Color
        let drum: StatDrum
        /// Plays the drum. The card itself only bumps and buzzes.
        let onHit: () -> Void

        /// Counts the hits, to bump the card and buzz once per hit.
        @State private var hits = 0

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
            .keyframeAnimator(initialValue: 1.0, trigger: hits) { card, scale in
                card.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(0.94, duration: 0.05)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
            .contentShape(.rect(cornerRadius: Self.cornerRadius))
            .gesture(TouchDownGesture {
                onHit()
                hits += 1
            })
            .sensoryFeedback(drum.haptic, trigger: hits)
            // Still read as a plain number: the drums are a surprise for whoever taps.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label): \(value)")
        }
    }
}

#Preview {
    YouNumbersView(toast: .constant(nil))
        .padding(.vertical)
        .background(Color.green.opacity(0.4))
        .environment(EpisodePlayedStore(database: FakeLocalDatabase()))
}
