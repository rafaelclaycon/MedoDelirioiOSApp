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

    /// URLs and email addresses extracted from the episode description.
    /// Combines `href` values from HTML `<a>` tags with bare links detected in plain text.
    var extractedLinks: [URL] {
        var seen = Set<String>()
        var results = [URL]()

        func normalizedKey(for url: URL) -> String {
            var key = url.absoluteString.lowercased()
            if url.scheme != "mailto" {
                key = key
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                while key.hasSuffix("/") { key.removeLast() }
            }
            return key
        }

        func addIfNew(_ url: URL) {
            let key = normalizedKey(for: url)
            guard !seen.contains(key) else { return }
            seen.insert(key)
            results.append(url)
        }

        if let html = description {
            if let regex = try? NSRegularExpression(pattern: "href=\"([^\"]+)\"", options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                for match in regex.matches(in: html, range: range) {
                    if let urlRange = Range(match.range(at: 1), in: html),
                       let url = URL(string: String(html[urlRange])) {
                        addIfNew(url)
                    }
                }
            }
        }

        if let plainText = plainTextDescription {
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let range = NSRange(plainText.startIndex..., in: plainText)
            detector?.enumerateMatches(in: plainText, range: range) { match, _, _ in
                if let url = match?.url {
                    addIfNew(url)
                }
            }
        }

        return results
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
