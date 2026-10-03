//
//  EpisodesView+ViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation
import os

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "EpisodesViewModel")

extension EpisodesView {

    @Observable class ViewModel {

        var state: LoadingState<[PodcastEpisode]> = .loading
        var toast: Toast?

        /// Unique listeners in the last week, by episode id. Only holds the few episodes
        /// popular enough to be worth calling out — see `loadPopularEpisodes`.
        var weeklyListeners: [String: Int] = [:]

        /// Below this, "N ouvindo" reads as an empty room and works against the episode.
        private static let minimumListenersToDisplay = 20
        private static let popularEpisodesCount = 3

        private let apiClient: APIClientProtocol
        private let episodesService: EpisodesServiceProtocol
        private let database: LocalDatabaseProtocol
        private let analyticsService: AnalyticsServiceProtocol

        // MARK: - Initializer

        init(
            episodesService: EpisodesServiceProtocol,
            apiClient: APIClientProtocol = APIClient.shared,
            database: LocalDatabaseProtocol = LocalDatabase.shared,
            analyticsService: AnalyticsServiceProtocol = AnalyticsService()
        ) {
            self.episodesService = episodesService
            self.apiClient = apiClient
            self.database = database
            self.analyticsService = analyticsService
        }
    }
}

// MARK: - User Actions

extension EpisodesView.ViewModel {

    func onViewLoaded() async {
        await loadEpisodes()
        await loadPopularEpisodes()
    }

    func onTryAgainSelected() async {
        await loadEpisodes()
    }

    func onPullToRefresh() async {
        await syncFromNetwork()
    }
}

// MARK: - Internal Functions

extension EpisodesView.ViewModel {

    private func loadEpisodes() async {
        let cached = (try? database.allPodcastEpisodes()) ?? []

        if cached.isEmpty {
            state = .loading
        } else {
            state = .loaded(cached)
        }

        await syncFromNetwork()
    }

    /// Purely decorative, so any failure just leaves the chips off.
    private func loadPopularEpisodes() async {
        let refDate = Date.dateAsString(addingDays: -7)
        guard let url = URL(string: apiClient.serverPath + "v4/episode-play-count-stats-from/\(refDate)") else { return }

        guard let items: [PopularEpisodeItem] = try? await apiClient.get(from: url) else { return }

        weeklyListeners = items
            .sorted { $0.uniqueListeners > $1.uniqueListeners }
            .prefix(Self.popularEpisodesCount)
            .filter { $0.uniqueListeners >= Self.minimumListenersToDisplay }
            .reduce(into: [:]) { $0[$1.episodeId] = $1.uniqueListeners }
    }

    private func syncFromNetwork() async {
        do {
            try await episodesService.syncEpisodes(database: database)
            if let refreshed = try? database.allPodcastEpisodes() {
                state = .loaded(refreshed)
            }
        } catch {
            // The .task and .refreshable that drive this sync are cancelled by SwiftUI
            // whenever the view disappears (tab switch, pushing an episode detail).
            // That's not a failure — and the launch sync in MainView may well have
            // succeeded concurrently — so don't surface an error for it.
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                if case .loading = state {
                    state = .error("Não foi possível carregar os episódios.")
                }
                return
            }

            logger.error("Episode sync failed: \(error.localizedDescription, privacy: .public)")
            await analyticsService.send(
                originatingScreen: "EpisodesView",
                action: "syncFailed(\(error.localizedDescription))"
            )

            if case .loading = state {
                state = .error("Não foi possível carregar os episódios.")
            } else {
                toast = Toast(message: "Não foi possível atualizar os episódios.", type: .warning)
            }
        }
    }
}

// MARK: - Server Response

extension EpisodesView.ViewModel {

    private struct PopularEpisodeItem: Codable {
        let episodeId: String
        let uniqueListeners: Int
    }
}
