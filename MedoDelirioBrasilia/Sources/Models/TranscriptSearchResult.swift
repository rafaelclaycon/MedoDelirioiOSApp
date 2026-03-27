//
//  TranscriptSearchResult.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 22/03/26.
//

import Foundation

struct EpisodeTranscriptGroup: Identifiable, Equatable {

    let episode: PodcastEpisode
    let matches: [TranscriptMatch]

    var id: String { episode.id }
}

struct TranscriptMatch: Identifiable, Equatable {

    let cueText: String
    let timestamp: TimeInterval

    var id: String { "\(Int(timestamp))" }

    var formattedTimestamp: String {
        let totalSeconds = Int(timestamp)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
