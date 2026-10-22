//
//  BookmarkTitleSuggester.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 22/10/26.
//

import Foundation

/// Names a new bookmark after what was being said when it was made, so it's
/// recognisable in the list without the user typing anything. Nil, and the bookmark
/// stays untitled, when there's no transcript or nothing was being said.
enum BookmarkTitleSuggester {

    /// Long enough for a recognisable phrase, short enough for one line in the lists.
    static let maxLength = 60

    /// A bookmark made in a pause still gets the line just said, if it ended this
    /// recently. Any longer and the line probably isn't what the bookmark is about.
    static let pauseTolerance: TimeInterval = 5

    /// The line playing at `timestamp`, or the one just before it during a short pause.
    static func title(from cues: [SRTCue], at timestamp: TimeInterval) -> String? {
        guard
            let cue = cues.last(where: { $0.startTime <= timestamp }),
            timestamp <= cue.endTime + pauseTolerance
        else { return nil }
        return shortened(cue.text)
    }

    /// Reads the episode's transcript off the main actor, for a bookmark made without
    /// Now Playing's already loaded copy (the lock screen's bookmark button).
    static func title(episodeId: String, at timestamp: TimeInterval) async -> String? {
        guard TranscriptPreferences.isEnabled, let fileURL = TranscriptProvider.findSRTFile(for: episodeId) else {
            return nil
        }
        return await Task.detached(priority: .userInitiated) {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
            return title(from: SRTParser.parse(content), at: timestamp)
        }.value
    }

    /// One line of at most `maxLength` characters, cut at a word. A line cut short, or
    /// one that stops at a comma because the sentence goes on in the next cue, ends in
    /// an ellipsis, unless the cut happens to land at the end of a sentence.
    static func shortened(_ text: String) -> String? {
        let singleLine = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !singleLine.isEmpty else { return nil }

        var result = Substring(singleLine)
        var continues = false

        if result.count > maxLength {
            result = result.prefix(maxLength)
            if let lastSpace = result.lastIndex(of: " ") {
                result = result[..<lastSpace]
            }
            continues = true
        }

        // A cut can land after a comma or a dash, and a cue can end on one when the
        // sentence carries on: either way, the ellipsis replaces it.
        while let last = result.last, Self.trailingJoiners.contains(last) {
            result.removeLast()
            continues = true
        }

        guard !result.isEmpty else { return nil }
        if let last = result.last, Self.sentenceEnds.contains(last) {
            continues = false
        }
        return continues ? String(result) + "…" : String(result)
    }

    private static let sentenceEnds: Set<Character> = [".", "!", "?", "…"]

    private static let trailingJoiners: Set<Character> = [",", ";", ":", "-", "–", "—", " "]
}
