//
//  EpisodeHandoffPayload.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Foundation

/// What a Handoff of the episode in the player carries to the other device: which
/// episode, and where in it.
struct EpisodeHandoffPayload: Equatable {

    var episodeID: String
    var position: TimeInterval
    var duration: TimeInterval

    enum Key {
        static let episodeID = "episodeId"
        static let position = "position"
        static let duration = "duration"
    }

    static let requiredKeys: Set<String> = [Key.episodeID, Key.position, Key.duration]

    init(episodeID: String, position: TimeInterval, duration: TimeInterval) {
        self.episodeID = episodeID
        self.position = position
        self.duration = duration
    }

    /// Reads a payload from another device, rejecting anything that couldn't be
    /// played. The position is clamped, since it's estimated and can overshoot.
    init?(userInfo: [AnyHashable: Any]?) {
        guard
            let userInfo,
            let episodeID = userInfo[Key.episodeID] as? String, !episodeID.isEmpty,
            let position = userInfo[Key.position] as? Double, position.isFinite,
            let duration = userInfo[Key.duration] as? Double, duration.isFinite, duration > 0
        else { return nil }

        self.init(episodeID: episodeID, position: min(max(position, 0), duration), duration: duration)
    }

    var userInfo: [String: Any] {
        [Key.episodeID: episodeID, Key.position: position, Key.duration: duration]
    }
}
