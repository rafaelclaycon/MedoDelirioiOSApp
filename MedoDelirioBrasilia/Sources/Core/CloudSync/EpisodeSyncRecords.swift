//
//  EpisodeSyncRecords.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Foundation

/// A piece of per-episode state that travels through iCloud. Whichever copy was
/// changed last wins, so every record carries the moment it changed.
protocol EpisodeSyncRecord: Codable, Equatable {

    var updatedAt: Date { get }
}

extension EpisodeSyncRecord {

    /// SQLite keeps dates to the millisecond and the round trip can shave one off, so
    /// copies this close together count as the same change. Without the slack, two
    /// devices could keep overwriting each other with the "newer" copy forever.
    func isNewer(than other: Self) -> Bool {
        updatedAt.timeIntervalSince(other.updatedAt) > 0.002
    }
}

/// One episode's playback position. The short keys keep the payload small, since the
/// whole dictionary is rewritten on every push.
struct EpisodeProgressRecord: EpisodeSyncRecord {

    var currentTime: TimeInterval
    var duration: TimeInterval
    var updatedAt: Date
    /// The progress was cleared (the episode finished, or someone reset it). Kept so
    /// the clearing beats any older position still on another device.
    var isCleared: Bool

    enum CodingKeys: String, CodingKey {
        case currentTime = "t"
        case duration = "d"
        case updatedAt = "u"
        case isCleared = "x"
    }

    static func cleared(at date: Date) -> EpisodeProgressRecord {
        EpisodeProgressRecord(currentTime: 0, duration: 0, updatedAt: date, isCleared: true)
    }
}

/// A yes/no mark on an episode, like played or favorite. Removing the mark is a record
/// too, with `isMarked == false`, so it isn't undone by an older mark from another device.
protocol EpisodeMarkRecord: EpisodeSyncRecord {

    var isMarked: Bool { get }
}

/// Whether an episode is marked as played.
struct EpisodePlayedRecord: EpisodeMarkRecord {

    var isPlayed: Bool
    var updatedAt: Date

    var isMarked: Bool { isPlayed }

    enum CodingKeys: String, CodingKey {
        case isPlayed = "p"
        case updatedAt = "u"
    }
}

/// Whether an episode is a favorite.
struct EpisodeFavoriteRecord: EpisodeMarkRecord {

    var isFavorite: Bool
    var updatedAt: Date

    var isMarked: Bool { isFavorite }

    enum CodingKeys: String, CodingKey {
        case isFavorite = "f"
        case updatedAt = "u"
    }
}
