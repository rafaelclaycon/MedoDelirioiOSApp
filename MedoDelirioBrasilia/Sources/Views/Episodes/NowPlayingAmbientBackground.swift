//
//  NowPlayingAmbientBackground.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 31/10/26.
//

import SwiftUI

/// The app's greens drifting behind Now Playing's wide layout while the episode plays, and
/// holding still when it's paused, so the window breathes with the episode. Faint enough to
/// read over; still with Reduce Motion.
struct NowPlayingAmbientBackground: View {

    let isPlaying: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var clock = PlaybackClock()

    private static let deepGreen = Color(red: 0.01, green: 0.24, blue: 0.11)
    private static let midGreen = Color(red: 0.13, green: 0.55, blue: 0.29)

    /// Light and dark greens side by side, so the shapes they make can be seen moving.
    private static let colors: [Color] = [
        deepGreen, .brightGreen, .darkerGreen,
        midGreen, .darkestGreen, .brightGreen,
        .brightGreen, .darkerGreen, deepGreen
    ]

    var body: some View {
        Group {
            if reduceMotion {
                mesh(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
                    mesh(at: clock.elapsed(at: context.date))
                }
            }
        }
        .opacity(colorScheme == .dark ? 0.32 : 0.2)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            clock.setRunning(isPlaying)
        }
        .onChange(of: isPlaying) {
            clock.setRunning(isPlaying)
        }
    }

    /// The inner points wander, each at its own pace, so the colors keep shifting without
    /// lining up into bands. A full sway takes about 7 to 10 seconds.
    private func mesh(at time: TimeInterval) -> some View {
        let t = Float(time)
        let drift = { (speed: Float, phase: Float, amount: Float) in
            sin(t * speed + phase) * amount
        }

        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5 + drift(0.8, 0, 0.3), 0], [1, 0],
                [0, 0.5 + drift(0.7, 1, 0.3)],
                [0.5 + drift(0.9, 2, 0.32), 0.5 + drift(0.75, 3, 0.32)],
                [1, 0.5 + drift(0.65, 4, 0.3)],
                [0, 1], [0.5 + drift(0.85, 5, 0.3), 1], [1, 1]
            ],
            colors: Self.colors,
            smoothsColors: true
        )
    }
}

// MARK: - Clock

/// Time that only passes while the episode plays, so the gradient picks up where it
/// stopped instead of jumping ahead by however long it was paused.
private struct PlaybackClock {

    private var accumulated: TimeInterval = 0
    private var resumedAt: Date?

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (resumedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    mutating func setRunning(_ isRunning: Bool, at date: Date = .now) {
        if isRunning, resumedAt == nil {
            resumedAt = date
        } else if !isRunning, let resumedAt {
            accumulated += date.timeIntervalSince(resumedAt)
            self.resumedAt = nil
        }
    }
}
