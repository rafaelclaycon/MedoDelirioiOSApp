//
//  RisingStars.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/10/26.
//

import SwiftUI

/// Five-pointed stars drifting up and fading near the top, like election night confetti,
/// drawn at a given moment. The caller drives `time` (a `TimelineView`, or 0 to hold still
/// with Reduce Motion). Used by the Retrospectiva banner and the highlighted episode row.
struct RisingStars: View {

    let time: TimeInterval
    var color: Color = .white
    /// Scales every star's own opacity, for places where they should stay faint.
    var intensity: Double = 1

    var body: some View {
        Canvas { context, size in
            for star in Self.stars {
                draw(star, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Star {
        /// Across the area, 0 to 1.
        let x: Double
        /// Where in its climb it starts, 0 to 1.
        let phase: Double
        /// Area heights per second.
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

    private func draw(_ star: Star, in context: inout GraphicsContext, size: CGSize) {
        let progress = (star.phase + time * star.speed).truncatingRemainder(dividingBy: 1)
        // Rises from just below the bottom, swaying a little, and fades out up top.
        let y = size.height * (1.1 - progress * 1.2)
        let x = size.width * star.x + sin(time * 0.9 + star.phase * 6) * 8
        let fade = min(1, (1 - progress) * 3) * min(1, progress * 6)

        var starContext = context
        starContext.opacity = star.opacity * fade * intensity
        starContext.translateBy(x: x, y: y)
        starContext.rotate(by: .radians(time * 0.4 + star.phase * 3))
        starContext.fill(Self.starPath(radius: star.size / 2), with: .color(color))
    }

    /// A five-pointed star, as on the flag of the party that won.
    static func starPath(radius: CGFloat) -> Path {
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
