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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        let symbol = formatter.standaloneMonthSymbols[month - 1]
        return symbol.prefix(1).uppercased() + symbol.dropFirst()
    }

    static func < (lhs: StatsMonth, rhs: StatsMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// What someone did in the app in one month: the Vírgulas they shared and played and the
/// episodes they listened to. Built by `MonthlyStatsProvider`.
struct MonthlyStats: Identifiable {

    struct TopEpisode {
        let title: String
        let secondsListened: Double
    }

    let month: StatsMonth
    /// The month isn't over yet, so the numbers can still grow.
    let isInProgress: Bool

    let shareCount: Int
    let uniqueSoundsShared: Int
    /// Up to three, ranked.
    let topSharedSounds: [TopChartItem]
    let topAuthor: TopAuthorItem?

    let playCount: Int
    /// Up to three, ranked. The count is in `shareCount`, as in the audience's play ranking.
    let topPlayedSounds: [TopChartItem]

    let secondsListened: Double
    let topEpisode: TopEpisode?
    let episodesFinished: Int

    /// Days with at least one share, tapped play or episode listen.
    let activeDays: Int

    var id: StatsMonth { month }

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
    /// the month did have some listening.
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
        let episodeTitles = episodeTitles()

        var months: [MonthlyStats] = []
        var month = Self.firstMonth
        while month <= currentMonth {
            let stats = stats(for: month, currentMonth: currentMonth, listenLogs: listenLogs, episodeTitles: episodeTitles)
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
            episodeTitles: episodeTitles()
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
        episodeTitles: [String: String]
    ) -> MonthlyStats {
        let interval = month.interval(in: calendar)

        let shareDates = (try? database.shareDates(in: interval)) ?? []
        let playDates = (try? database.playDates(in: interval)) ?? []
        let monthLogs = listenLogs.filter { $0.startedAt >= interval.start && $0.startedAt < interval.end }

        let topEpisode = EpisodeListenStats.mostListenedEpisodes(from: monthLogs, limit: 1).first.map {
            MonthlyStats.TopEpisode(
                title: episodeTitles[$0.episodeId] ?? "Episódio desconhecido",
                secondsListened: $0.totalSeconds
            )
        }

        let activeDays = Set(
            (shareDates + playDates + monthLogs.map(\.startedAt)).map { calendar.startOfDay(for: $0) }
        ).count

        return MonthlyStats(
            month: month,
            isInProgress: month == currentMonth,
            shareCount: shareDates.count,
            uniqueSoundsShared: shareDates.isEmpty ? 0 : database.sharedSoundsCount(in: interval),
            topSharedSounds: shareDates.isEmpty ? [] : ranked((try? database.topSoundsSharedByTheUser(in: interval, limit: 3)) ?? []),
            topAuthor: shareDates.isEmpty ? nil : try? database.topAuthorSharedByTheUser(in: interval),
            playCount: playDates.count,
            topPlayedSounds: playDates.isEmpty ? [] : ranked((try? database.topSoundsPlayedByTheUser(in: interval, limit: 3)) ?? []),
            secondsListened: EpisodeListenStats.totalHoursListened(from: monthLogs) * 3600,
            topEpisode: topEpisode,
            episodesFinished: Set(monthLogs.filter(\.didComplete).map(\.episodeId)).count,
            activeDays: activeDays
        )
    }

    private func episodeTitles() -> [String: String] {
        let episodes = (try? database.allPodcastEpisodes()) ?? []
        return Dictionary(episodes.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
    }

    /// Gives each row the id and rank number `TopChartRow` expects.
    private func ranked(_ items: [TopChartItem]) -> [TopChartItem] {
        items.enumerated().map { index, item in
            var item = item
            item.id = "\(item.contentId)-\(index)"
            item.rankNumber = "\(index + 1)"
            return item
        }
    }
}
