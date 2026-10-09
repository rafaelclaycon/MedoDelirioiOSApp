//
//  ElectionFinalThemeEffects.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 08/10/26.
//

import CoreHaptics
import SwiftUI

/// How the results screen dresses the final result. The numbers never change: like the final
/// message, this is only what goes around them.
enum ElectionFinalTheme {
    /// Confetti, fireworks in the hand and the winner's badge pulsing.
    case celebration
    /// Night falls over the card and stars come out one by one. No sound, no haptics.
    case comfort
}

// MARK: - Confetti

/// One throw of confetti. Every piece is decided when the burst is made, so the screen only
/// computes where each one is at the current frame.
struct ElectionConfettiBurst: Identifiable {

    let id = UUID()
    let start = Date.now
    fileprivate let pieces: [ConfettiPiece]

    static let lifetime: TimeInterval = 5.5

    /// Two cannons from the bottom corners and a rain from the top, for when the result arrives.
    static func celebration() -> ElectionConfettiBurst {
        var pieces: [ConfettiPiece] = []
        for side in [-1.0, 1.0] {
            for _ in 0..<70 {
                // Up and towards the middle, 10° to 35° off vertical.
                let angle = Double.random(in: 10...35) * .pi / 180
                let speed = Double.random(in: 1700...2600)
                pieces.append(.random(
                    origin: .unit(UnitPoint(x: side < 0 ? 0 : 1, y: 1)),
                    velocity: CGVector(dx: -side * sin(angle) * speed, dy: -cos(angle) * speed),
                    delay: .random(in: 0...0.15)
                ))
            }
        }
        for _ in 0..<60 {
            pieces.append(.random(
                origin: .unit(UnitPoint(x: .random(in: 0...1), y: 0)),
                velocity: CGVector(dx: .random(in: -60...60), dy: .random(in: 0...120)),
                delay: .random(in: 0.3...1.6)
            ))
        }
        return ElectionConfettiBurst(pieces: pieces)
    }

    /// A small pop from a point in global coordinates, for taps on the winner's photo.
    static func pop(at point: CGPoint) -> ElectionConfettiBurst {
        let pieces = (0..<40).map { _ in
            let angle = Double.random(in: -70...70) * .pi / 180
            let speed = Double.random(in: 500...1100)
            return ConfettiPiece.random(
                origin: .global(point),
                velocity: CGVector(dx: sin(angle) * speed, dy: -cos(angle) * speed),
                delay: 0
            )
        }
        return ElectionConfettiBurst(pieces: pieces)
    }
}

fileprivate struct ConfettiPiece {

    enum Origin {
        /// Relative to the confetti view, for the cannons and the rain.
        case unit(UnitPoint)
        /// Where a tap landed.
        case global(CGPoint)
    }

    enum Shape {
        case strip, square, star
    }

    let origin: Origin
    let velocity: CGVector
    let delay: TimeInterval
    let color: Color
    let shape: Shape
    let size: CGSize
    /// Turns in the plane, radians per second.
    let spin: Double
    /// Turns around its own vertical axis, the paper showing its edge, radians per second.
    let flip: Double
    let phase: Double
    /// How far it drifts side to side while falling.
    let sway: Double

    // Brazil's green, yellow and blue, and the red star.
    private static let green = Color(red: 0, green: 0.61, blue: 0.23)
    private static let yellow = ElectionResultsPalette.bar
    private static let blue = Color(red: 0, green: 0.15, blue: 0.46)
    private static let red = Color(red: 0.89, green: 0, blue: 0.06)

    static func random(origin: Origin, velocity: CGVector, delay: TimeInterval) -> ConfettiPiece {
        let isStar = Double.random(in: 0..<1) < 0.15
        let shape: Shape = isStar ? .star : (Bool.random() ? .strip : .square)
        let size: CGSize
        switch shape {
        case .strip:
            size = CGSize(width: .random(in: 5...7), height: .random(in: 10...15))
        case .square:
            let side = CGFloat.random(in: 7...9)
            size = CGSize(width: side, height: side)
        case .star:
            let side = CGFloat.random(in: 11...15)
            size = CGSize(width: side, height: side)
        }
        return ConfettiPiece(
            origin: origin,
            velocity: velocity,
            delay: delay,
            color: isStar ? red : [green, green, yellow, yellow, .white, blue].randomElement()!,
            shape: shape,
            size: size,
            spin: .random(in: -6...6),
            flip: isStar ? 0 : .random(in: 4...10),
            phase: .random(in: 0...(2 * .pi)),
            sway: .random(in: 8...28)
        )
    }
}

/// Draws every live burst over the whole screen. Paper falls through air: pieces leave fast,
/// slow down and settle at a gentle falling speed instead of accelerating like stones.
struct ElectionConfettiView: View {

    let bursts: [ElectionConfettiBurst]

    /// Air drag, per second.
    private static let drag = 3.2
    /// Points per second squared. With the drag, pieces settle at about 230 pt/s.
    private static let gravity = 750.0

    var body: some View {
        GeometryReader { proxy in
            let globalOrigin = proxy.frame(in: .global).origin
            TimelineView(.animation(paused: bursts.isEmpty)) { timeline in
                Canvas { context, size in
                    let now = timeline.date
                    for burst in bursts {
                        let elapsed = now.timeIntervalSince(burst.start)
                        guard elapsed < ElectionConfettiBurst.lifetime else { continue }
                        let fade = min(1, ElectionConfettiBurst.lifetime - elapsed)
                        for piece in burst.pieces {
                            draw(piece, at: elapsed - piece.delay, fade: fade, in: &context, size: size, globalOrigin: globalOrigin)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(
        _ piece: ConfettiPiece,
        at t: TimeInterval,
        fade: Double,
        in context: inout GraphicsContext,
        size: CGSize,
        globalOrigin: CGPoint
    ) {
        guard t >= 0 else { return }

        let start: CGPoint
        switch piece.origin {
        case .unit(let unit):
            start = CGPoint(x: unit.x * size.width, y: unit.y * size.height)
        case .global(let point):
            start = CGPoint(x: point.x - globalOrigin.x, y: point.y - globalOrigin.y)
        }

        // Motion with linear drag, solved for t: no state to step frame by frame.
        let k = Self.drag
        let terminal = Self.gravity / k
        let slowed = (1 - exp(-k * t)) / k
        let sway = piece.sway * sin(3 * t + piece.phase) * min(t / 0.6, 1)
        let x = start.x + piece.velocity.dx * slowed + sway
        let y = start.y + terminal * t + (piece.velocity.dy - terminal) * slowed
        guard y < size.height + 30 else { return }

        var layer = context
        layer.opacity = fade
        layer.translateBy(x: x, y: y)
        layer.rotate(by: .radians(piece.spin * t + piece.phase))
        if piece.flip != 0 {
            // Never quite zero, or the piece vanishes for a frame.
            let edge = cos(piece.flip * t + piece.phase)
            layer.scaleBy(x: abs(edge) < 0.05 ? 0.05 : edge, y: 1)
        }

        let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2, width: piece.size.width, height: piece.size.height)
        let path = piece.shape == .star
            ? Self.starPath(in: rect)
            : Path(roundedRect: rect, cornerRadius: 1.5)
        layer.fill(path, with: .color(piece.color))
    }

    static func starPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        var path = Path()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Night Sky

/// Stars coming out one by one over the card, slowly, the first few in a couple of seconds
/// and the last around ten. The very last one is a little five-pointed star, warmer than the
/// rest. With Reduce Motion, they are all there from the start and don't twinkle.
struct ElectionNightSkyView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var start = Date.now

    private struct Star {
        let position: UnitPoint
        let radius: CGFloat
        let appearsAt: TimeInterval
        let brightness: Double
        let twinkleSpeed: Double
        let phase: Double
    }

    /// The same sky every time.
    private static let stars: [Star] = {
        var generator = SeededGenerator(seed: 2026)
        let count = 42
        return (0..<count).map { index in
            let progress = Double(index) / Double(count - 1)
            return Star(
                position: UnitPoint(x: .random(in: 0.03...0.97, using: &generator), y: .random(in: 0.03...0.97, using: &generator)),
                radius: .random(in: 0.6...1.6, using: &generator),
                appearsAt: 0.8 + 9 * pow(progress, 1.6) + .random(in: -0.2...0.2, using: &generator),
                brightness: .random(in: 0.45...0.95, using: &generator),
                twinkleSpeed: .random(in: 0.8...2.2, using: &generator),
                phase: .random(in: 0...(2 * .pi), using: &generator)
            )
        }
    }()

    private static let guidingStarPosition = UnitPoint(x: 0.86, y: 0.09)
    private static let guidingStarAppearsAt: TimeInterval = 11
    private static let guidingStarColor = Color(red: 1, green: 0.93, blue: 0.75)
    private static let fadeIn: TimeInterval = 1.8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let elapsed = reduceMotion ? .infinity : timeline.date.timeIntervalSince(start)

                for star in Self.stars {
                    let shown = Self.shown(elapsed - star.appearsAt)
                    guard shown > 0 else { continue }
                    let twinkle = reduceMotion ? 1 : 0.7 + 0.3 * sin(star.twinkleSpeed * elapsed + star.phase)
                    let center = CGPoint(x: star.position.x * size.width, y: star.position.y * size.height)
                    let dot = CGRect(x: center.x - star.radius, y: center.y - star.radius, width: star.radius * 2, height: star.radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(star.brightness * shown * twinkle)))
                }

                let shown = Self.shown(elapsed - Self.guidingStarAppearsAt)
                if shown > 0 {
                    let center = CGPoint(x: Self.guidingStarPosition.x * size.width, y: Self.guidingStarPosition.y * size.height)
                    context.drawLayer { glow in
                        glow.addFilter(.blur(radius: 6))
                        glow.fill(
                            Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)),
                            with: .color(Self.guidingStarColor.opacity(0.35 * shown))
                        )
                    }
                    context.fill(
                        ElectionConfettiView.starPath(in: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)),
                        with: .color(Self.guidingStarColor.opacity(shown))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0 to 1 over the fade-in, eased at both ends.
    private static func shown(_ sinceAppearing: TimeInterval) -> Double {
        let progress = min(max(sinceAppearing / fadeIn, 0), 1)
        return progress * progress * (3 - 2 * progress)
    }
}

/// SplitMix64, so the night sky is the same on every phone.
private struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Fireworks Haptics

/// Six rockets: a faint hum going up, the bang, and a crackle after it. Core Haptics, because
/// `sensoryFeedback` plays one tap at a time.
@MainActor
final class ElectionFireworksHaptics {

    /// Kept alive while the pattern plays; it shuts itself down when idle.
    private var engine: CHHapticEngine?

    func play() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            try engine.start()
            try engine.makePlayer(with: Self.pattern()).start(atTime: CHHapticTimeImmediate)
            self.engine = engine
        } catch {
            // Decoration: without haptics, the confetti still falls.
        }
    }

    private static func pattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var time: TimeInterval = 0
        for _ in 0..<6 {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                ],
                relativeTime: time,
                duration: 0.25
            ))
            time += 0.28
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                ],
                relativeTime: time
            ))
            for crackle in 1...4 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: .random(in: 0.3...0.5)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                    ],
                    relativeTime: time + 0.08 * Double(crackle) + .random(in: 0...0.03)
                ))
            }
            time += .random(in: 0.35...0.6)
        }
        return try CHHapticPattern(events: events, parameters: [])
    }
}
