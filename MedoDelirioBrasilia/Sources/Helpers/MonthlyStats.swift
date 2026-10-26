//
//  MonthlyStats.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/10/26.
//

import Foundation

/// A calendar month in the person's own time zone, the unit of Seu Mês.
struct StatsMonth: Hashable, Identifiable, Comparable {

    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(containing date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 1)
    }

    /// From the first instant of the month to the first of the next one, which is left out.
    func interval(in calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
        return calendar.dateInterval(of: .month, for: start) ?? DateInterval(start: start, duration: 0)
    }

    func adding(months: Int) -> StatsMonth {
        let index = year * 12 + (month - 1) + months
        return StatsMonth(year: index / 12, month: index % 12 + 1)
    }

    /// "Setembro".
    var name: String {
        let symbol = Self.formatter.standaloneMonthSymbols[month - 1]
        return symbol.prefix(1).uppercased() + symbol.dropFirst()
    }

    /// "set.", for date ranges.
    var shortName: String {
        Self.formatter.shortMonthSymbols[month - 1]
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    static func < (lhs: StatsMonth, rhs: StatsMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// What someone did in the app in one month: the Vírgulas they shared and played, the
/// authors behind them, the episodes they listened to and the highlights of each week.
/// Built by `MonthlyStatsProvider`.
struct MonthlyStats: Identifiable {

    struct RankedAuthor: Identifiable {
        let id: String
        let name: String
        let photo: String?
        let shareCount: Int
        let playCount: Int
    }

    struct RankedEpisode: Identifiable {
        let id: String
        let title: String
        let imageURL: URL?
        let secondsListened: Double
    }

    let month: StatsMonth
    /// The month isn't over yet, so the numbers can still grow.
    let isInProgress: Bool

    let shareCount: Int
    let playCount: Int
    let secondsListened: Double
    let episodesFinished: Int
    /// Days with at least one share, tapped play or episode listen.
    let activeDays: Int

    /// Up to ten each, ranked from "1". Plays are counted in `shareCount`, as in the
    /// audience's play ranking.
    let topSharedSounds: [TopChartItem]
    let topPlayedSounds: [TopChartItem]
    /// Up to ten, by shares, then plays.
    let topAuthors: [RankedAuthor]
    /// Up to ten, by time listened.
    let topEpisodes: [RankedEpisode]

    /// Newest week first, like a feed.
    let highlights: [MonthlyHighlight]

    var id: StatsMonth { month }

    var topAuthor: RankedAuthor? { topAuthors.first }
    var topEpisode: RankedEpisode? { topEpisodes.first }

    var hasVirgulas: Bool { shareCount > 0 || playCount > 0 }
    var hasEpisodes: Bool { secondsListened > 0 }
    var hasData: Bool { hasVirgulas || hasEpisodes }

    /// "Setembro", or "Outubro (até agora)" while it lasts.
    var title: String {
        isInProgress ? "\(month.name) (até agora)" : month.name
    }

    var formattedListeningTime: String {
        Self.formattedDuration(secondsListened)
    }

    /// Whole minutes, the way the summary's big number reads them.
    var minutesListened: Int {
        max(Int(secondsListened) / 60, hasEpisodes ? 1 : 0)
    }

    /// One line for the card that leads here, e.g. "47 compartilhamentos e 3h 20min de
    /// episódios".
    var summary: String {
        var parts: [String] = []
        if shareCount > 0 {
            parts.append(Self.counted(shareCount, "compartilhamento", "compartilhamentos"))
        } else if playCount > 0 {
            parts.append(Self.counted(playCount, "Vírgula tocada", "Vírgulas tocadas"))
        }
        if hasEpisodes {
            parts.append("\(formattedListeningTime) de episódios")
        }
        return parts.joined(separator: " e ")
    }

    // MARK: - Formatting

    /// "3h 20min", or "45 min" under an hour. Under a minute still reads "1 min", since
    /// there was some listening.
    static func formattedDuration(_ seconds: Double) -> String {
        let totalMinutes = max(Int(seconds) / 60, seconds > 0 ? 1 : 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
        return "\(minutes) min"
    }

    /// "1 compartilhamento", "1.234 compartilhamentos".
    static func counted(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(formattedNumber(count)) \(count == 1 ? singular : plural)"
    }

    static func formattedNumber(_ number: Int) -> String {
        number.formatted(.number.locale(Locale(identifier: "pt_BR")))
    }
}

/// Builds Seu Mês from what the app keeps on the device: share logs, play logs and
/// episode listen logs. Nothing comes from the server.
struct MonthlyStatsProvider {

    /// Seu Mês counts from here. Shares go further back, but episode listens only started
    /// in February 2026 and plays in October.
    static let firstMonth = StatsMonth(year: 2026, month: 1)

    private let database: LocalDatabaseProtocol
    private let calendar: Calendar

    init(database: LocalDatabaseProtocol = LocalDatabase.shared, calendar: Calendar = .current) {
        self.database = database
        self.calendar = calendar
    }

    /// From `firstMonth` through the month `now` is in, oldest first, leaving out the ones
    /// with nothing in them.
    func availableMonths(now: Date = .now) -> [MonthlyStats] {
        let currentMonth = StatsMonth(containing: now, calendar: calendar)
        guard Self.firstMonth <= currentMonth else { return [] }

        let listenLogs = (try? database.allEpisodeListenLogs()) ?? []
        let episodes = episodesById()

        var months: [MonthlyStats] = []
        var month = Self.firstMonth
        while month <= currentMonth {
            let stats = stats(for: month, currentMonth: currentMonth, listenLogs: listenLogs, episodes: episodes)
            if stats.hasData {
                months.append(stats)
            }
            month = month.adding(months: 1)
        }
        return months
    }

    func stats(for month: StatsMonth, now: Date = .now) -> MonthlyStats {
        stats(
            for: month,
            currentMonth: StatsMonth(containing: now, calendar: calendar),
            listenLogs: (try? database.allEpisodeListenLogs()) ?? [],
            episodes: episodesById()
        )
    }

    /// The month the card in Suas Tendências leads to: the last one that's over, like a
    /// recap, or the current one when the last one has nothing.
    static func featured(in months: [MonthlyStats]) -> MonthlyStats? {
        months.last(where: { !$0.isInProgress }) ?? months.last
    }

    // MARK: - Private

    private func stats(
        for month: StatsMonth,
        currentMonth: StatsMonth,
        listenLogs: [EpisodeListenLog],
        episodes: [String: PodcastEpisode]
    ) -> MonthlyStats {
        let interval = month.interval(in: calendar)

        let shares = (try? database.soundShareEvents(in: interval)) ?? []
        let plays = (try? database.soundPlayEvents(in: interval)) ?? []
        let logs = listenLogs.filter { $0.startedAt >= interval.start && $0.startedAt < interval.end }

        let activeDays = Set(
            (shares.map(\.date) + plays.map(\.date) + logs.map(\.startedAt)).map { calendar.startOfDay(for: $0) }
        ).count

        return MonthlyStats(
            month: month,
            isInProgress: month == currentMonth,
            shareCount: shares.count,
            playCount: plays.count,
            secondsListened: logs.reduce(0) { $0 + $1.durationListened },
            episodesFinished: Set(logs.filter(\.didComplete).map(\.episodeId)).count,
            activeDays: activeDays,
            topSharedSounds: Self.rankedSounds(shares, limit: 10),
            topPlayedSounds: Self.rankedSounds(plays, limit: 10),
            topAuthors: Self.rankedAuthors(shares: shares, plays: plays, limit: 10),
            topEpisodes: Self.rankedEpisodes(logs, episodes: episodes, limit: 10),
            highlights: MonthlyHighlightBuilder(calendar: calendar, episodes: episodes)
                .highlights(in: interval, shares: shares, plays: plays, listenLogs: logs)
        )
    }

    private func episodesById() -> [String: PodcastEpisode] {
        let episodes = (try? database.allPodcastEpisodes()) ?? []
        return Dictionary(episodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Rankings

    /// Ties go to the one done most recently, then by name, so the order doesn't shuffle.
    static func rankedSounds(_ events: [PersonalSoundEvent], limit: Int) -> [TopChartItem] {
        Dictionary(grouping: events, by: \.contentId)
            .values
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                let lhsLast = lhs.map(\.date).max() ?? .distantPast
                let rhsLast = rhs.map(\.date).max() ?? .distantPast
                if lhsLast != rhsLast { return lhsLast > rhsLast }
                return lhs[0].contentName < rhs[0].contentName
            }
            .prefix(limit)
            .enumerated()
            .map { index, group in
                TopChartItem(
                    id: "\(group[0].contentId)-\(index)",
                    rankNumber: "\(index + 1)",
                    contentId: group[0].contentId,
                    contentName: group[0].contentName,
                    contentAuthorId: group[0].authorId,
                    contentAuthorName: group[0].authorName,
                    shareCount: group.count
                )
            }
    }

    static func rankedAuthors(shares: [PersonalSoundEvent], plays: [PersonalSoundEvent], limit: Int) -> [MonthlyStats.RankedAuthor] {
        let sharesByAuthor = Dictionary(grouping: shares, by: \.authorId)
        let playsByAuthor = Dictionary(grouping: plays, by: \.authorId)
        return Set(sharesByAuthor.keys).union(playsByAuthor.keys)
            .compactMap { authorId -> MonthlyStats.RankedAuthor? in
                guard let event = sharesByAuthor[authorId]?.first ?? playsByAuthor[authorId]?.first else { return nil }
                return MonthlyStats.RankedAuthor(
                    id: authorId,
                    name: event.authorName,
                    photo: event.authorPhoto,
                    shareCount: sharesByAuthor[authorId]?.count ?? 0,
                    playCount: playsByAuthor[authorId]?.count ?? 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.shareCount != rhs.shareCount { return lhs.shareCount > rhs.shareCount }
                if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
                return lhs.name < rhs.name
            }
            .prefix(limit)
            .map { $0 }
    }

    static func rankedEpisodes(_ logs: [EpisodeListenLog], episodes: [String: PodcastEpisode], limit: Int) -> [MonthlyStats.RankedEpisode] {
        EpisodeListenStats.mostListenedEpisodes(from: logs, limit: limit).map {
            MonthlyStats.RankedEpisode(
                id: $0.episodeId,
                title: episodes[$0.episodeId]?.title ?? "Episódio desconhecido",
                imageURL: episodes[$0.episodeId]?.imageURL,
                secondsListened: $0.totalSeconds
            )
        }
    }
}
