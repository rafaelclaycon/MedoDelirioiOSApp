//
//  EpisodesService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation
import FeedKit

protocol EpisodesServiceProtocol {

    func fetchEpisodes(from url: URL) async throws -> [PodcastEpisode]
    func syncEpisodes(database: LocalDatabaseProtocol) async throws
}

@MainActor
final class EpisodesService: EpisodesServiceProtocol {

    static let shared = EpisodesService()

    static let feedURL = URL(string: "https://www.spreaker.com/show/4711842/episodes/feed")!

    private var inFlightSync: Task<Void, Error>?

    /// Concurrent callers (e.g. the launch sync in MainView and the Episodes tab's own
    /// sync) share a single in-flight fetch instead of hitting the feed twice. The
    /// unstructured Task also keeps the sync alive if a SwiftUI caller is cancelled.
    func syncEpisodes(database: LocalDatabaseProtocol = LocalDatabase.shared) async throws {
        if let inFlightSync {
            return try await inFlightSync.value
        }
        let task = Task {
            let episodes = try await fetchEpisodes(from: Self.feedURL)
            try database.upsertPodcastEpisodes(episodes)
        }
        inFlightSync = task
        defer { inFlightSync = nil }
        try await task.value
    }

    func fetchEpisodes(from url: URL) async throws -> [PodcastEpisode] {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EpisodesServiceError.invalidHTTPResponse
        }

        let episodes: [PodcastEpisode] = try await Task.detached {
            let feed = try Feed(data: data)

            guard let rssFeed = feed.rss else {
                throw EpisodesServiceError.invalidFeedFormat
            }

            return (rssFeed.channel?.items ?? []).compactMap { item in
                Self.mapToPodcastEpisode(item)
            }
        }.value

        return episodes.sorted { $0.pubDate > $1.pubDate }
    }

    // MARK: - Mapping

    private nonisolated static func mapToPodcastEpisode(_ item: RSSFeedItem) -> PodcastEpisode? {
        guard let id = parseEpisodeId(from: item.guid?.text),
              let title = item.title,
              let pubDate = item.pubDate,
              let audioURLString = item.enclosure?.attributes?.url,
              let audioURL = URL(string: audioURLString) else {
            return nil
        }

        let imageURL: URL? = item.iTunes?.image?.attributes?.href.flatMap { URL(string: $0) }

        return PodcastEpisode(
            id: id,
            title: title,
            pubDate: pubDate,
            audioURL: audioURL,
            description: item.iTunes?.summary ?? item.description,
            imageURL: imageURL,
            duration: item.iTunes?.duration,
            explicit: item.iTunes?.explicit == "yes"
        )
    }

    /// Extracts a stable episode ID from a GUID that may be a full URL.
    /// Handles two known formats:
    /// - Spreaker: "https://api.spreaker.com/episode/69980761" -> "69980761"
    /// - WordPress (central3): "http://www.central3.com.br/?p=40097" -> "40097"
    nonisolated static func parseEpisodeId(from guid: String?) -> String? {
        guard let guid else { return nil }
        if let url = URL(string: guid), url.scheme != nil {
            let lastComponent = url.lastPathComponent
            if !lastComponent.isEmpty, lastComponent != "/" {
                return lastComponent
            }
            if let components = URLComponents(string: guid),
               let pValue = components.queryItems?.first(where: { $0.name == "p" })?.value,
               !pValue.isEmpty {
                return pValue
            }
            return guid
        }
        return guid
    }
}

// MARK: - Errors

enum EpisodesServiceError: Error, LocalizedError {

    case invalidFeedFormat
    case invalidHTTPResponse

    var errorDescription: String? {
        switch self {
        case .invalidFeedFormat:
            return "O feed do podcast possui um formato inválido."
        case .invalidHTTPResponse:
            return "O servidor retornou uma resposta inesperada."
        }
    }
}
