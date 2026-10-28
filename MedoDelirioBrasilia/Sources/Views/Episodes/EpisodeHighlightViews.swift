//
//  EpisodeHighlightViews.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/10/26.
//

import SwiftUI

/// How a highlighted episode's row is dressed, by style. `lulaWin`: a thin red outline
/// around the row, a quiet badge, and Lula's head, Brazilian flags and stars flying up in
/// front of the row, like election night confetti. The confetti is the show; the rest
/// stays out of its way.

// MARK: - Badge

/// A small line over the date with the server's text: a star and the words in red, on a
/// faint red tint.
struct EpisodeHighlightBadge: View {

    let style: EpisodeHighlightStore.Style
    let label: String

    @Environment(\.colorScheme) private var colorScheme

    /// Coral in dark mode, where the bright red is hard to read.
    private var tint: Color {
        colorScheme == .dark ? RetroPalette.coral : RetroPalette.red
    }

    var body: some View {
        switch style {
        case .lulaWin:
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                Text(label)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.12)))
        }
    }
}

// MARK: - Background

/// The outline around a highlighted row. Drawn a little larger than the row's content (see
/// `episodeHighlight(_:)`), so the text keeps some room inside it.
struct EpisodeHighlightBackground: View {

    static let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    /// How far the card, and the particles in it, reach past the row's content.
    static let outset = EdgeInsets(top: -4, leading: -10, bottom: -4, trailing: -10)

    let style: EpisodeHighlightStore.Style

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch style {
        case .lulaWin:
            // The soft light red would glow on a dark list; the system red sits better there.
            Self.shape
                .strokeBorder(colorScheme == .dark ? Color.red : RetroPalette.blush, lineWidth: 2)
        }
    }
}

// MARK: - Particles

/// What flies up in front of a highlighted row, inside its card. Lets taps through, and
/// holds still with Reduce Motion.
struct EpisodeHighlightParticles: View {

    let style: EpisodeHighlightStore.Style

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch style {
        case .lulaWin:
            Group {
                if reduceMotion {
                    canvas(at: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        canvas(at: context.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private enum Kind: Int, CaseIterable {
        case head, flag, star
    }

    private struct Particle {
        let kind: Kind
        /// Across the row, 0 to 1.
        let x: Double
        /// Where in its climb it starts, 0 to 1.
        let phase: Double
        /// Row heights per second.
        let speed: Double
        let size: CGFloat
    }

    /// Fixed, so the row looks the same each time: a few heads, more flags and stars, each
    /// in its own column so the heads come up at the left, the middle and the right.
    private static let particles: [Particle] = {
        let layout: [(Kind, Double)] = [
            (.head, 0.12), (.flag, 0.30), (.star, 0.48), (.flag, 0.66), (.star, 0.84), (.head, 0.56),
            (.star, 0.22), (.flag, 0.92), (.star, 0.38), (.flag, 0.06), (.head, 0.86), (.star, 0.72)
        ]
        return layout.enumerated().map { index, item in
            let (kind, x) = item
            let i = Double(index)
            let base: CGFloat = switch kind {
            case .head: 34
            case .flag: 20
            case .star: 16
            }
            return Particle(
                kind: kind,
                x: x,
                phase: (i * 0.377).truncatingRemainder(dividingBy: 1),
                speed: 0.12 + (i * 0.731).truncatingRemainder(dividingBy: 1) * 0.1,
                size: base + CGFloat((i * 0.419).truncatingRemainder(dividingBy: 1)) * 10
            )
        }
    }()

    private func canvas(at time: TimeInterval) -> some View {
        Canvas { context, size in
            for (index, particle) in Self.particles.enumerated() {
                guard let symbol = context.resolveSymbol(id: particle.kind) else { continue }
                let progress = (particle.phase + time * particle.speed).truncatingRemainder(dividingBy: 1)
                // Rises from just below the bottom to just above the top, swaying, and fades
                // in and out at the ends.
                let y = size.height * (1.15 - progress * 1.3)
                let x = size.width * particle.x + sin(time * 1.1 + Double(index)) * 10
                let fade = min(1, (1 - progress) * 4) * min(1, progress * 6)

                var particleContext = context
                particleContext.opacity = 0.9 * fade
                particleContext.translateBy(x: x, y: y)
                // Heads wobble, flags flutter, stars spin.
                let angle: Double = switch particle.kind {
                case .head: sin(time * 2 + Double(index)) * 0.25
                case .flag: sin(time * 3 + Double(index)) * 0.15
                case .star: time * 1.2 + Double(index)
                }
                particleContext.rotate(by: .radians(angle))
                let scale = particle.size / 40
                particleContext.scaleBy(x: scale, y: scale)
                particleContext.draw(symbol, at: .zero)
            }
        } symbols: {
            Image("EpisodeHighlightLulaHead")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .tag(Kind.head)
            Text("🇧🇷")
                .font(.system(size: 34))
                .tag(Kind.flag)
            Text("⭐")
                .font(.system(size: 34))
                .tag(Kind.star)
        }
    }
}

// MARK: - Row

extension View {

    /// The card behind a highlighted row and the particles in front of it. Both reach past
    /// the content by the same `outset` and share the card's shape, so they line up whatever
    /// insets the list gives the row.
    @ViewBuilder
    func episodeHighlight(_ highlight: EpisodeHighlightStore.Highlight?) -> some View {
        if let highlight {
            background {
                EpisodeHighlightBackground(style: highlight.style)
                    .padding(EpisodeHighlightBackground.outset)
            }
            .overlay {
                // Clipped before the padding, which is what makes it bigger than the row.
                EpisodeHighlightParticles(style: highlight.style)
                    .clipShape(EpisodeHighlightBackground.shape)
                    .padding(EpisodeHighlightBackground.outset)
            }
        } else {
            self
        }
    }
}
