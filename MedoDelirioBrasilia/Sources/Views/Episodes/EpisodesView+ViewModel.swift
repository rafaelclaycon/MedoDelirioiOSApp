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

        private let episodesService: EpisodesServiceProtocol
        private let database: LocalDatabaseProtocol
        private let analyticsService: AnalyticsServiceProtocol

        // MARK: - Initializer

        init(
            episodesService: EpisodesServiceProtocol,
            database: LocalDatabaseProtocol = LocalDatabase.shared,
            analyticsService: AnalyticsServiceProtocol = AnalyticsService()
        ) {
            self.episodesService = episodesService
            self.database = database
            self.analyticsService = analyticsService
        }
    }
}

// MARK: - User Actions

extension EpisodesView.ViewModel {

    func onViewLoaded() async {
        await loadEpisodes()
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
