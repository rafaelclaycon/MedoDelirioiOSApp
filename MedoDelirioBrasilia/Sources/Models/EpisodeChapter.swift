//
//  EpisodeChapter.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/07/26.
//

import Foundation

/// A single chapter within an episode.
///
/// Only the start is stored — a chapter runs until the next one begins, or until
/// the end of the episode for the last one. Keeping the end implicit makes gaps
/// and overlaps structurally impossible.
struct EpisodeChapter: Identifiable, Equatable, Hashable, Codable {

    let start: TimeInterval
    let title: String

    /// Whole seconds of `start`. Stable for the lifetime of a loaded episode:
    /// chapters are immutable once parsed and `ChapterProvider` drops duplicate
    /// starts, so this is unique within a chapter list.
    var id: Int { Int(start) }

    var formattedStart: String {
        let totalSeconds = max(Int(start), 0)
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

// MARK: - On-Disk Format

/// Shape of `chapters.json` — a single file holding every episode's chapters.
///
/// Chapters are a few hundred bytes per episode, so unlike transcripts the whole
/// catalog is small enough to ship as one file rather than a manifest plus one
/// file per episode.
struct EpisodeChaptersFile: Codable {

    let version: Int
    let episodes: [String: EpisodeChapterEntry]
}

/// One episode's chapters plus the provenance of how they were produced.
///
/// The provenance fields exist so a regeneration pass can tell which episodes
/// came from which model, and so `source == "manual"` can mark hand-corrected
/// episodes that batch runs must leave alone.
struct EpisodeChapterEntry: Codable {

    let source: String?
    let modelVersion: String?
    let generatedAt: String?
    let chapters: [EpisodeChapter]
}
