//
//  MonthlyHighlights.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/10/26.
//

import Foundation

/// One card in Seu Mês's feed: something that stood out in a week, like a streak, an
/// author who took over the shares or the episode that kept someone company.
struct MonthlyHighlight: Identifiable, Hashable {

    enum Kind: String {
        case authorShare, listeningStreak, episodeOfTheWeek, soundOfTheWeek, shareStreak, finishedEpisodes, nightOwl
    }

    enum Artwork: Hashable {
        /// Round, like an artist.
        case author(photo: String?)
        /// Square, like a song: the author's photo stands in, since Vírgulas have no art.
        case sound(authorPhoto: String?)
        case episode(imageURL: URL?)
        /// Up to four, in a grid.
        case episodes(imageURLs: [URL?])
        case symbol(String)
    }

    let kind: Kind
    /// The week it's about, cut to the month.
    let week: DateInterval
    let headline: String
    /// One sentence. The parts in `emphasized` are names, shown in color.
    let detail: String
    let emphasized: [String]
    let artwork: Artwork
    /// "12 a 18 de out. de 2026".
    let dateLabel: String

    var id: String { "\(Int(week.start.timeIntervalSince1970))-\(kind.rawValue)" }
}

/// Finds a month's highlights, week by week. Weeks start on Monday, as on the calendar
/// Spotify's capsule uses, and are cut at the month's edges.
struct MonthlyHighlightBuilder {

    /// More than this per week and the feed reads like a report.
    static let maxPerWeek = 3

    private let calendar: Calendar
    private let episodes: [String: PodcastEpisode]

    init(calendar: Calendar, episodes: [String: PodcastEpisode]) {
        var calendar = calendar
        calendar.firstWeekday = 2
        self.calendar = calendar
        self.episodes = episodes
    }

    func highlights(
        in month: DateInterval,
        shares: [PersonalSoundEvent],
        plays: [PersonalSoundEvent],
        listenLogs: [EpisodeListenLog]
    ) -> [MonthlyHighlight] {
        weeks(in: month).reversed().flatMap { week in
            weekHighlights(
                in: week,
                shares: shares.filter { week.containsHalfOpen($0.date) },
                plays: plays.filter { week.containsHalfOpen($0.date) },
                listenLogs: listenLogs.filter { week.containsHalfOpen($0.startedAt) }
            )
        }
    }

    func weeks(in month: DateInterval) -> [DateInterval] {
        var weeks: [DateInterval] = []
        var cursor = month.start
        while cursor < month.end {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
            let start = max(week.start, month.start)
            let end = min(week.end, month.end)
            weeks.append(DateInterval(start: start, end: end))
            cursor = week.end
        }
        return weeks
    }

    // MARK: - A Week

    /// In order of how much they say about the person, up to `maxPerWeek`.
    private func weekHighlights(
        in week: DateInterval,
        shares: [PersonalSoundEvent],
        plays: [PersonalSoundEvent],
        listenLogs: [EpisodeListenLog]
    ) -> [MonthlyHighlight] {
        let label = dateLabel(for: week)
        let candidates: [MonthlyHighlight?] = [
            authorShare(shares),
            listeningStreak(listenLogs),
            episodeOfTheWeek(listenLogs),
            soundOfTheWeek(shares: shares, plays: plays),
            shareStreak(shares),
            finishedEpisodes(listenLogs),
            nightOwl(dates: shares.map(\.date) + plays.map(\.date) + listenLogs.map(\.startedAt))
        ].map { $0?(week, label) }
        return Array(candidates.compactMap { $0 }.prefix(Self.maxPerWeek))
    }

    /// A highlight waiting for its week and label, which every rule shares.
    private typealias Draft = (DateInterval, String) -> MonthlyHighlight

    private func draft(_ kind: MonthlyHighlight.Kind, _ headline: String, _ detail: String, emphasized: [String], artwork: MonthlyHighlight.Artwork) -> Draft {
        { week, label in
            MonthlyHighlight(kind: kind, week: week, headline: headline, detail: detail, emphasized: emphasized, artwork: artwork, dateLabel: label)
        }
    }

    /// One author behind a good part of a week's shares.
    private func authorShare(_ shares: [PersonalSoundEvent]) -> Draft? {
        guard shares.count >= 5,
              let top = Self.biggestGroup(shares, by: \.authorId) else { return nil }
        let percent = Int((Double(top.count) / Double(shares.count) * 100).rounded())
        guard percent >= 30 else { return nil }
        let author = top[0].authorName
        return draft(
            .authorShare,
            "\(percent)% dos seus compartilhamentos",
            "Nesta semana, \(top.count) das Vírgulas que você compartilhou foram de \(author).",
            emphasized: [author],
            artwork: .author(photo: top[0].authorPhoto)
        )
    }

    private func listeningStreak(_ logs: [EpisodeListenLog]) -> Draft? {
        let streak = EpisodeListenStats.longestStreak(from: logs.map(\.startedAt))
        guard streak >= 3 else { return nil }
        let top = topEpisode(logs)
        return draft(
            .listeningStreak,
            "Você teve uma sequência de \(streak) dias",
            top.map { "Você ouviu o podcast dia após dia, com \($0.title) à frente." } ?? "Você ouviu o podcast dia após dia.",
            emphasized: top.map { [$0.title] } ?? [],
            artwork: .episode(imageURL: top?.imageURL)
        )
    }

    /// At least ten minutes with one episode. With others in the week, says how much of
    /// the listening it took.
    private func episodeOfTheWeek(_ logs: [EpisodeListenLog]) -> Draft? {
        guard let top = EpisodeListenStats.mostListenedEpisodes(from: logs, limit: 1).first,
              top.totalSeconds >= 600 else { return nil }
        let episode = episodes[top.episodeId]
        let title = episode?.title ?? "Episódio desconhecido"
        let total = logs.reduce(0) { $0 + $1.durationListened }
        let percent = Int((top.totalSeconds / total * 100).rounded())
        return draft(
            .episodeOfTheWeek,
            percent < 100 ? "\(percent)% do seu tempo de episódios" : "Seu episódio da semana",
            "Nesta semana você passou \(MonthlyStats.formattedDuration(top.totalSeconds)) ouvindo \(title).",
            emphasized: [title],
            artwork: .episode(imageURL: episode?.imageURL)
        )
    }

    /// The Vírgula shared at least three times, or played at least five in a week
    /// without shares.
    private func soundOfTheWeek(shares: [PersonalSoundEvent], plays: [PersonalSoundEvent]) -> Draft? {
        let (events, minimum, verb) = shares.isEmpty ? (plays, 5, "tocou") : (shares, 3, "compartilhou")
        guard let top = Self.biggestGroup(events, by: \.contentId),
              top.count >= minimum else { return nil }
        let sound = top[0]
        return draft(
            .soundOfTheWeek,
            "Sua Vírgula da semana",
            "Você \(verb) \(sound.contentName), de \(sound.authorName), \(top.count) vezes.",
            emphasized: [sound.contentName, sound.authorName],
            artwork: .sound(authorPhoto: sound.authorPhoto)
        )
    }

    private func shareStreak(_ shares: [PersonalSoundEvent]) -> Draft? {
        let streak = EpisodeListenStats.longestStreak(from: shares.map(\.date))
        guard streak >= 3 else { return nil }
        let topAuthor = Self.biggestGroup(shares, by: \.authorId)?.first
        return draft(
            .shareStreak,
            "\(streak) dias seguidos de Vírgulas",
            "Você compartilhou Vírgulas dia após dia.",
            emphasized: [],
            artwork: .author(photo: topAuthor?.authorPhoto)
        )
    }

    private func finishedEpisodes(_ logs: [EpisodeListenLog]) -> Draft? {
        var finishedIds: [String] = []
        for log in logs where log.didComplete && !finishedIds.contains(log.episodeId) {
            finishedIds.append(log.episodeId)
        }
        guard finishedIds.count >= 2 else { return nil }
        let titles = finishedIds.map { episodes[$0]?.title ?? "Episódio desconhecido" }
        let shown = Array(titles.prefix(2))
        let list = titles.count > 2
            ? "\(shown.joined(separator: ", ")) e mais \(titles.count - 2)"
            : shown.joined(separator: " e ")
        return draft(
            .finishedEpisodes,
            "\(finishedIds.count) episódios até o fim",
            "Nesta semana você ouviu \(list) do começo ao fim.",
            emphasized: shown,
            artwork: .episodes(imageURLs: finishedIds.prefix(4).map { episodes[$0]?.imageURL })
        )
    }

    /// Most of a week's activity between 22h and 5h.
    private func nightOwl(dates: [Date]) -> Draft? {
        guard dates.count >= 5 else { return nil }
        let late = dates.filter {
            let hour = calendar.component(.hour, from: $0)
            return hour >= 22 || hour < 5
        }
        let percent = Int((Double(late.count) / Double(dates.count) * 100).rounded())
        guard percent >= 50 else { return nil }
        return draft(
            .nightOwl,
            "Coruja da semana",
            "\(percent)% do que você fez no app nesta semana foi depois das 22h.",
            emphasized: [],
            artwork: .symbol("moon.stars.fill")
        )
    }

    // MARK: - Helpers

    /// The events that share the most common key. A tie goes to the most recent, so the
    /// same data always tells the same story.
    static func biggestGroup(_ events: [PersonalSoundEvent], by key: (PersonalSoundEvent) -> String) -> [PersonalSoundEvent]? {
        Dictionary(grouping: events, by: key).values.max { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            return (lhs.map(\.date).max() ?? .distantPast) < (rhs.map(\.date).max() ?? .distantPast)
        }
    }

    private func topEpisode(_ logs: [EpisodeListenLog]) -> PodcastEpisode? {
        EpisodeListenStats.mostListenedEpisodes(from: logs, limit: 1).first.flatMap { episodes[$0.episodeId] }
    }

    /// "12 a 18 de out. de 2026", or "1 de out. de 2026" for a single day.
    func dateLabel(for week: DateInterval) -> String {
        let first = calendar.dateComponents([.day, .month, .year], from: week.start)
        let last = calendar.dateComponents([.day], from: week.end.addingTimeInterval(-1))
        let month = StatsMonth(year: first.year ?? 0, month: first.month ?? 1)
        let days = first.day == last.day ? "\(first.day ?? 1)" : "\(first.day ?? 1) a \(last.day ?? 1)"
        return "\(days) de \(month.shortName) de \(month.year)"
    }
}

private extension DateInterval {

    /// `contains` takes the end in too, which would count a Sunday-midnight share twice.
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
