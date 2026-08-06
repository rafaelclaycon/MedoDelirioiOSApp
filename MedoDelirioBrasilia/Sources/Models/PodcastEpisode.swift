//
//  PodcastEpisode.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

struct PodcastEpisode: Identifiable, Equatable, Hashable {

    let id: String
    let title: String
    let pubDate: Date
    let audioURL: URL
    let description: String?
    let imageURL: URL?
    let duration: TimeInterval?
    let explicit: Bool

    /// The episode description with HTML tags stripped and entities decoded.
    var plainTextDescription: String? {
        description?.strippingHTML()
    }

    /// Returns a relative date string (e.g. "Today", "3 days ago") for episodes
    /// published within the last week, and an absolute date for older episodes.
    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        if let daysAgo = calendar.dateComponents([.day], from: calendar.startOfDay(for: pubDate), to: calendar.startOfDay(for: now)).day,
           daysAgo >= 0, daysAgo <= 7 {
            return Formatter.relativeDateTime.localizedString(for: pubDate, relativeTo: now)
        } else {
            return Formatter.episodeAbsoluteDate.string(from: pubDate)
        }
    }

    /// The episode description as an `AttributedString`, with `<a href>` links and
    /// bare URLs in the text preserved as tappable `.link` runs — so `Text` can
    /// render the description with its links highlighted in place, instead of
    /// needing a separate extracted-links list.
    var descriptionAttributedString: AttributedString? {
        guard let html = description else { return nil }

        let normalized = html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let linkRegex = try? NSRegularExpression(
            pattern: "<a\\s+[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return AttributedString(normalized.strippingTagsAndDecodingEntities())
        }

        var result = AttributedString()
        var lastEnd = normalized.startIndex
        let nsRange = NSRange(normalized.startIndex..., in: normalized)

        linkRegex.enumerateMatches(in: normalized, range: nsRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: normalized),
                  let hrefRange = Range(match.range(at: 1), in: normalized),
                  let textRange = Range(match.range(at: 2), in: normalized) else { return }

            if lastEnd < matchRange.lowerBound {
                let plain = String(normalized[lastEnd..<matchRange.lowerBound]).strippingTagsAndDecodingEntities()
                result += Self.linkifyingBareURLs(in: plain)
            }

            let linkText = String(normalized[textRange]).strippingTagsAndDecodingEntities()
            if !linkText.isEmpty, let url = URL(string: String(normalized[hrefRange])) {
                var linkRun = AttributedString(linkText)
                linkRun.link = url
                result += linkRun
            } else {
                result += AttributedString(linkText)
            }

            lastEnd = matchRange.upperBound
        }

        if lastEnd < normalized.endIndex {
            let trailing = String(normalized[lastEnd...]).strippingTagsAndDecodingEntities()
            result += Self.linkifyingBareURLs(in: trailing)
        }

        return result
    }

    /// Turns bare URLs found in already-tag-stripped text into tappable `.link`
    /// runs — covers links the feed left as plain text instead of an `<a>` tag.
    private static func linkifyingBareURLs(in plainText: String) -> AttributedString {
        guard !plainText.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return AttributedString(plainText)
        }

        var result = AttributedString()
        var lastEnd = plainText.startIndex
        let range = NSRange(plainText.startIndex..., in: plainText)

        detector.enumerateMatches(in: plainText, range: range) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: plainText),
                  let url = match.url else { return }

            if lastEnd < matchRange.lowerBound {
                result += AttributedString(String(plainText[lastEnd..<matchRange.lowerBound]))
            }

            var linkRun = AttributedString(String(plainText[matchRange]))
            linkRun.link = url
            result += linkRun

            lastEnd = matchRange.upperBound
        }

        if lastEnd < plainText.endIndex {
            result += AttributedString(String(plainText[lastEnd...]))
        }

        return result
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let totalSeconds = Int(duration)
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
