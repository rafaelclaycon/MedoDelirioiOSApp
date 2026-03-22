//
//  SRTParser.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/03/26.
//

import Foundation

struct SRTCue: Identifiable, Equatable {

    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

    var id: Int { index }
}

enum SRTParser {

    /// Extracts plain text from SRT content, stripping timestamps and sequence numbers.
    static func plainText(from content: String) -> String {
        parse(content).map(\.text).joined(separator: " ")
    }

    /// Parses standard SRT content into an array of cues sorted by start time.
    static func parse(_ content: String) -> [SRTCue] {
        let blocks = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")

        return blocks.compactMap { parseBlock($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    // MARK: - Private

    private static func parseBlock(_ block: String) -> SRTCue? {
        let lines = block.components(separatedBy: "\n")
        guard lines.count >= 3,
              let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        let timeParts = lines[1].components(separatedBy: " --> ")
        guard timeParts.count == 2,
              let start = parseTimestamp(timeParts[0]),
              let end = parseTimestamp(timeParts[1]) else {
            return nil
        }

        let text = lines[2...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return SRTCue(index: index, startTime: start, endTime: end, text: text)
    }

    /// Parses `HH:MM:SS,mmm` into a `TimeInterval`.
    private static func parseTimestamp(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: ":,"))
        guard parts.count == 4,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]),
              let millis = Double(parts[3]) else {
            return nil
        }
        return hours * 3600 + minutes * 60 + seconds + millis / 1000
    }
}
