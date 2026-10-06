//
//  PlayDeduplicator.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Foundation

/// Decides whether a play is a new one or more of the same burst.
///
/// Tapping a sound over and over — to hear the punchline again, or just for fun — is one
/// play, not twenty. A play of some content counts unless the same content was last
/// started less than `burstWindow` ago, and every tap inside the burst pushes the window
/// along. So hammering a sound for a minute is one play, while hearing a short sound
/// through and replaying it after a beat is two.
///
/// Tracked per content, so alternating between two sounds can't sneak a burst past it,
/// and other content in between doesn't end a burst either.
struct PlayDeduplicator {

    /// Long enough to swallow tap-stop-tap restarts, short enough that a deliberate
    /// replay of a two- or three-second sound still counts.
    static let burstWindow: TimeInterval = 3

    private var lastStartByContentId: [String: Date] = [:]

    mutating func shouldCount(contentId: String, at date: Date) -> Bool {
        let lastStart = lastStartByContentId[contentId]

        // Entries past the window can never fold a play again; dropping them keeps this
        // to the handful of sounds touched in the last few seconds.
        lastStartByContentId = lastStartByContentId.filter {
            date.timeIntervalSince($0.value) < Self.burstWindow
        }
        lastStartByContentId[contentId] = date

        guard let lastStart else { return true }
        return date.timeIntervalSince(lastStart) >= Self.burstWindow
    }
}
