//
//  SocialVideoLimit.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 16/08/26.
//

import Foundation

/// Maximum video length accepted by each network a clip is likely headed to.
///
/// Drives the hint under the clip's duration so the user learns a clip is too
/// long for Stories *while picking it*, rather than after exporting and being
/// rejected by the app they're posting to.
struct SocialVideoLimit {

    /// Short form for the inline hint, where several names share one line.
    let name: String
    /// Spelled out for the info alert, where there's room to be unambiguous.
    let fullName: String
    let maxDuration: TimeInterval

    /// Ordered shortest first, so the "passa de" list reads from the tightest
    /// limit outwards.
    static let all: [SocialVideoLimit] = [
        .init(name: "Stories", fullName: "Instagram Stories", maxDuration: 60),
        .init(name: "X", fullName: "X (contas grátis)", maxDuration: 140),
        .init(name: "Reels", fullName: "Instagram Reels", maxDuration: 180),
        .init(name: "Bluesky", fullName: "Bluesky", maxDuration: 600),
    ]

    /// The longest clip any supported network accepts. `WaveformView.maxClipLength`
    /// is pinned to this — there's no point letting someone build a clip that
    /// every destination would reject.
    static var longest: TimeInterval {
        all.map(\.maxDuration).max() ?? 0
    }

    // MARK: - Hint

    /// One-line summary of where `duration` can be posted, e.g.
    /// "Cabe em Reels e Bluesky · passa de Stories e X".
    ///
    /// Returns nil for an empty selection — there's nothing useful to say about
    /// a zero-length clip.
    static func hint(for duration: TimeInterval) -> String? {
        guard duration > 0 else { return nil }

        let fitting = all.filter { duration <= $0.maxDuration }
        let exceeded = all.filter { duration > $0.maxDuration }

        guard !fitting.isEmpty else {
            return "Passa do limite de todas as redes."
        }
        guard !exceeded.isEmpty else {
            return "Cabe em todas as redes."
        }
        return "Cabe em \(list(fitting)) · passa de \(list(exceeded))."
    }

    // MARK: - Info Alert

    static let alertTitle = "Limites de duração"

    /// Every limit in one place, one per line, for the ⓘ alert.
    static var alertMessage: String {
        all
            .map { "\($0.fullName): até \(formatted($0.maxDuration))" }
            .joined(separator: "\n")
    }

    // MARK: - Formatting

    /// Whole minutes read better without a trailing `00s`, so "3min" rather than
    /// "3min00s".
    static func formatted(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60

        if minutes == 0 { return "\(seconds)s" }
        return seconds == 0 ? "\(minutes)min" : "\(minutes)min\(String(format: "%02d", seconds))s"
    }

    /// "A", "A e B", "A, B e C" — Portuguese list formatting, no Oxford comma.
    private static func list(_ limits: [SocialVideoLimit]) -> String {
        let names = limits.map(\.name)
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return names.dropLast().joined(separator: ", ") + " e " + last
    }
}
