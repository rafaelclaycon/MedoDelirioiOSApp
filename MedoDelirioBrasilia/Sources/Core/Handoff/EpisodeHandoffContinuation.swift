//
//  EpisodeHandoffContinuation.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 10/10/26.
//

import Foundation

/// What the receiving device does with an episode handed off from another one.
enum EpisodeHandoffContinuation: Equatable {

    /// The episode is already in this device's player: jump to the position and play.
    case resume(at: TimeInterval)
    /// Load the episode (downloading it if needed) and play from the position.
    case start(PodcastEpisode, at: TimeInterval)
    /// This device doesn't know the episode yet, usually because its feed hasn't
    /// refreshed since the episode came out.
    case episodeNotFound

    static func resolve(
        _ payload: EpisodeHandoffPayload,
        loadedEpisodeID: String?,
        findEpisode: (String) -> PodcastEpisode?
    ) -> EpisodeHandoffContinuation {
        if loadedEpisodeID == payload.episodeID {
            return .resume(at: payload.position)
        }
        guard let episode = findEpisode(payload.episodeID) else {
            return .episodeNotFound
        }
        return .start(episode, at: payload.position)
    }
}
