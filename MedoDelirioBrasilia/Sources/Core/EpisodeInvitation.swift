//
//  EpisodeInvitation.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/11/26.
//

import Foundation

/// Offers people who have never played an episode one to try, right where they are: a card
/// on Vírgulas, and in place of the empty episode stats. Nothing to set up on the server, and
/// it goes away on its own once they listen.
struct EpisodeInvitation {

    /// The Vírgulas card steps aside after showing on this many days, so it never turns into
    /// something to scroll past every time.
    static let maximumCardDays = 5

    private let database: LocalDatabaseProtocol
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    init(
        database: LocalDatabaseProtocol = LocalDatabase.shared,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.database = database
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    // MARK: - Who and What

    /// No listens logged here and no place saved in any episode, which also syncs over from
    /// their other devices. When the database can't say, assume they have, and stay quiet.
    func hasNeverListened() -> Bool {
        guard
            let progress = try? database.allEpisodeProgress(), progress.isEmpty,
            let logs = try? database.allEpisodeListenLogs(), logs.isEmpty
        else { return false }
        return true
    }

    /// The episode the server highlights while it does, since a special episode is a good
    /// first one, or else the latest.
    func suggestedEpisode(highlightedEpisodeId: String?) -> PodcastEpisode? {
        if let highlightedEpisodeId, let episode = try? database.podcastEpisode(id: highlightedEpisodeId) {
            return episode
        }
        return (try? database.allPodcastEpisodes())?.max { $0.pubDate < $1.pubDate }
    }

    // MARK: - Vírgulas Card

    /// Not closed, and not yet shown on its share of days. A day it already showed on still
    /// counts as open, so it doesn't vanish halfway through the last one.
    func canShowCard(on date: Date = .now) -> Bool {
        guard !userDefaults.bool(forKey: Keys.dismissed) else { return false }
        if let lastDay = userDefaults.object(forKey: Keys.lastDayShown) as? Date,
           calendar.isDate(lastDay, inSameDayAs: date) {
            return true
        }
        return userDefaults.integer(forKey: Keys.daysShown) < Self.maximumCardDays
    }

    /// Counts each day once.
    func cardWasShown(on date: Date = .now) {
        if let lastDay = userDefaults.object(forKey: Keys.lastDayShown) as? Date,
           calendar.isDate(lastDay, inSameDayAs: date) {
            return
        }
        userDefaults.set(userDefaults.integer(forKey: Keys.daysShown) + 1, forKey: Keys.daysShown)
        userDefaults.set(date, forKey: Keys.lastDayShown)
    }

    func dismissCard() {
        userDefaults.set(true, forKey: Keys.dismissed)
    }

    private enum Keys {
        static let dismissed = "episodeInvitationCardDismissed"
        static let daysShown = "episodeInvitationCardDaysShown"
        static let lastDayShown = "episodeInvitationCardLastDayShown"
    }
}
