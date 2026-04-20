//
//  EpisodesBadgeStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 16/04/26.
//

import Foundation

@Observable
final class EpisodesBadgeStore {

    enum Badge: Equatable {
        case none
        case count(Int)
    }

    @ObservationIgnored private let database: LocalDatabaseProtocol
    @ObservationIgnored private let memory: AppPersistentMemory
    @ObservationIgnored private let userSettings: UserSettings

    private(set) var badge: Badge = .none

    init(
        database: LocalDatabaseProtocol = LocalDatabase.shared,
        memory: AppPersistentMemory = .shared,
        userSettings: UserSettings = UserSettings()
    ) {
        self.database = database
        self.memory = memory
        self.userSettings = userSettings
        seedIfNeeded()
        recompute()
    }

    func recompute() {
        // Gate on the existing "notify me about new episodes" preference.
        // Users who don't want push notifications shouldn't get a visual nag.
        guard userSettings.getEnableEpisodeNotifications() else {
            badge = .none
            return
        }
        guard let cutoff = memory.getEpisodesTabLastVisitedAt() else {
            badge = .none
            return
        }
        let episodes = (try? database.allPodcastEpisodes()) ?? []
        let unseen = episodes.filter { $0.pubDate > cutoff }.count
        badge = unseen > 0 ? .count(unseen) : .none
    }

    func markAsVisited() {
        memory.setEpisodesTabLastVisitedAt(Date())
        badge = .none
    }

    /// First-launch migration for existing installs. If the user already has
    /// cached episodes but no recorded visit, treat them as caught up now so
    /// they don't see a huge count after upgrading.
    private func seedIfNeeded() {
        guard memory.getEpisodesTabLastVisitedAt() == nil else { return }
        let hasCachedEpisodes = ((try? database.allPodcastEpisodes()) ?? []).isEmpty == false
        if hasCachedEpisodes {
            memory.setEpisodesTabLastVisitedAt(Date())
        }
    }
}
