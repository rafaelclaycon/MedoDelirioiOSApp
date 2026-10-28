//
//  RetroBanner.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 20/10/24.
//

import SwiftUI

/// The way into the Retrospectiva from Vírgulas, in the year's flat red: stars rising like
/// election night confetti, and the year rolling over from the last one, like an odometer.
struct RetroBanner: View {

    let year: Int
    let openStoriesAction: () -> Void
    let dismissAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shownYear: Int
    @State private var isButtonPulsing = false

    init(year: Int = 2026, openStoriesAction: @escaping () -> Void, dismissAction: @escaping () -> Void) {
        self.year = year
        self.openStoriesAction = openStoriesAction
        self.dismissAction = dismissAction
        _shownYear = State(initialValue: year - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("SUA RETROSPECTIVA")
                .font(.caption.weight(.heavy))
                .tracking(1.6)
                .opacity(0.8)

            Text(verbatim: String(shownYear))
                .font(.system(size: 64, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(shownYear)))
                .lineLimit(1)

            Text("Bora ver o que nós aprontamos juntos esse ano?")
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: openStoriesAction) {
                Text("Bora!")
                    .font(.callout.bold())
                    .foregroundStyle(RetroPalette.deepRed)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .scaleEffect(isButtonPulsing ? 1.06 : 1)
            .padding(.top, .spacing(.xxSmall))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacing(.xLarge))
        .background {
            Background(reduceMotion: reduceMotion)
        }
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Fechar")
            .padding(.spacing(.xxSmall))
        }
        .onAppear {
            rollOver()
        }
    }

    /// From last year to this one, a beat after the banner shows up. Then the button starts
    /// a slow pulse, so the eye lands on it.
    private func rollOver() {
        guard !reduceMotion else {
            shownYear = year
            return
        }
        shownYear = year - 1
        withAnimation(.spring(duration: 0.9, bounce: 0.3).delay(0.6)) {
            shownYear = year
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(1.6)) {
            isButtonPulsing = true
        }
    }
}

// MARK: - Background

extension RetroBanner {

    /// The year's red, a deeper disc breathing in one corner, and white stars drifting up and
    /// fading near the top. Holds still with Reduce Motion.
    struct Background: View {

        let reduceMotion: Bool

        var body: some View {
            if reduceMotion {
                frame(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    frame(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }

        private func frame(at time: TimeInterval) -> some View {
            ZStack {
                RetroPalette.red

                Circle()
                    .fill(RetroPalette.deepRed)
                    .frame(width: 260, height: 260)
                    .scaleEffect(1 + 0.06 * sin(time * 0.8))
                    .offset(x: 110, y: 70)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                Canvas { context, size in
                    for star in Self.stars {
                        draw(star, at: time, in: &context, size: size)
                    }
                }
            }
            .accessibilityHidden(true)
        }

        private struct Star {
            /// Across the banner, 0 to 1.
            let x: Double
            /// Where in its climb it starts, 0 to 1.
            let phase: Double
            /// Banner heights per second.
            let speed: Double
            let size: CGFloat
            let opacity: Double
        }

        /// Fixed, so the sky looks the same each time; spread so none overlap for long.
        private static let stars: [Star] = (0..<16).map { index in
            let i = Double(index)
            return Star(
                x: (i * 0.618).truncatingRemainder(dividingBy: 1) * 0.9 + 0.05,
                phase: (i * 0.377).truncatingRemainder(dividingBy: 1),
                speed: 0.05 + (i * 0.731).truncatingRemainder(dividingBy: 1) * 0.06,
                size: 6 + CGFloat((i * 0.419).truncatingRemainder(dividingBy: 1)) * 10,
                opacity: 0.25 + (i * 0.283).truncatingRemainder(dividingBy: 1) * 0.4
            )
        }

        private func draw(_ star: Star, at time: TimeInterval, in context: inout GraphicsContext, size: CGSize) {
            let progress = (star.phase + time * star.speed).truncatingRemainder(dividingBy: 1)
            // Rises from just below the bottom, swaying a little, and fades out up top.
            let y = size.height * (1.1 - progress * 1.2)
            let x = size.width * star.x + sin(time * 0.9 + star.phase * 6) * 8
            let fade = min(1, (1 - progress) * 3) * min(1, progress * 6)

            var star5 = context
            star5.opacity = star.opacity * fade
            star5.translateBy(x: x, y: y)
            star5.rotate(by: .radians(time * 0.4 + star.phase * 3))
            star5.fill(Self.starPath(radius: star.size / 2), with: .color(.white))
        }

        /// A five-pointed star, as on the flag of the party that won.
        private static func starPath(radius: CGFloat) -> Path {
            Path { path in
                for point in 0..<10 {
                    let angle = Double(point) * .pi / 5 - .pi / 2
                    let length = point.isMultiple(of: 2) ? radius : radius * 0.42
                    let location = CGPoint(x: cos(angle) * length, y: sin(angle) * length)
                    if point == 0 {
                        path.move(to: location)
                    } else {
                        path.addLine(to: location)
                    }
                }
                path.closeSubpath()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RetroBanner(openStoriesAction: {}, dismissAction: {})
        .padding()
}
