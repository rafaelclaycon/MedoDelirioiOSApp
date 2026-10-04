//
//  EpisodePopularityStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 03/10/26.
//

import Foundation

/// How many people listened to the week's most popular episodes, counted from plays
/// in this app only (the server's `didPlayEpisode` usage metrics), not from Spotify
/// or other podcast platforms. The server fixes the 7-day window and caches the
/// answer for an hour.
///
/// Shared through the environment so the list and Episode Detail show the same number,
/// whichever way the detail was reached.
@Observable
final class EpisodePopularityStore {

    /// Below this, "N pessoas ouviram" reads as an empty room and works against the episode.
    static let minimumListenersToDisplay = 20
    static let popularEpisodesCount = 3

    @ObservationIgnored private let apiClient: APIClientProtocol
    @ObservationIgnored private var hasLoaded = false

    /// Unique listeners in the last 7 days, by episode id. Only holds the popular few.
    private(set) var weeklyListeners: [String: Int] = [:]

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func weeklyListeners(for episodeId: String) -> Int? {
        weeklyListeners[episodeId]
    }

    /// Dev Options: forgets the numbers and fetches them again after `delay`, long enough
    /// to close Settings and watch them arrive in the list again.
    func replayArrival(after delay: Duration = .seconds(15)) async {
        weeklyListeners = [:]
        hasLoaded = false
        try? await Task.sleep(for: delay)
        await loadIfNeeded()
    }

    /// Fetches once per launch. Purely decorative, so any failure just leaves the numbers off.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard
            let url = URL(string: apiClient.serverPath + "v4/popular-episodes-this-week"),
            let items: [PopularEpisodeItem] = try? await apiClient.get(from: url)
        else {
            hasLoaded = false
            return
        }

        weeklyListeners = items
            .sorted { $0.uniqueListeners > $1.uniqueListeners }
            .prefix(Self.popularEpisodesCount)
            .filter { $0.uniqueListeners >= Self.minimumListenersToDisplay }
            .reduce(into: [:]) { $0[$1.episodeId] = $1.uniqueListeners }
    }
}

// MARK: - Server Response

extension EpisodePopularityStore {

    private struct PopularEpisodeItem: Codable {
        let episodeId: String
        let uniqueListeners: Int
    }
}
