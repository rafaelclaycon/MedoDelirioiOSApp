//
//  MonthlyHighlightBuilderTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 26/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct MonthlyHighlightBuilderTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// October 2026: starts on a Thursday, so its first week is 1 to 4.
    private var october: DateInterval { StatsMonth(year: 2026, month: 10).interval(in: calendar) }

    private func makeSUT(episodes: [PodcastEpisode] = []) -> MonthlyHighlightBuilder {
        MonthlyHighlightBuilder(calendar: calendar, episodes: Dictionary(uniqueKeysWithValues: episodes.map { ($0.id, $0) }))
    }

    private func share(_ sound: String, by author: String = "Autor", at date: Date) -> PersonalSoundEvent {
        PersonalSoundEvent(contentId: sound, contentName: sound, authorId: author, authorName: author, authorPhoto: "https://example.com/\(author).jpg", date: date)
    }

    private func listen(_ episodeId: String, at start: Date, seconds: Double, completed: Bool = false) -> EpisodeListenLog {
        EpisodeListenLog(episodeId: episodeId, startedAt: start, endedAt: start.addingTimeInterval(seconds), durationListened: seconds, didComplete: completed)
    }

    private func episode(_ id: String, title: String) -> PodcastEpisode {
        PodcastEpisode(
            id: id, title: title, pubDate: Date(timeIntervalSince1970: 0),
            audioURL: URL(string: "https://example.com/\(id).mp3")!, description: nil,
            imageURL: URL(string: "https://example.com/\(id).jpg"), duration: nil, explicit: false
        )
    }

    // MARK: - Weeks

    @Test
    func weeks_shouldStartOnMondayAndBeCutAtTheMonthsEdges() {
        let weeks = makeSUT().weeks(in: october)

        #expect(weeks.first?.start == date(2026, 10, 1, 0))
        #expect(weeks.first?.end == date(2026, 10, 5, 0))
        #expect(weeks[1].start == date(2026, 10, 5, 0))
        #expect(weeks.last?.end == date(2026, 11, 1, 0))
        #expect(weeks.count == 5)
    }

    @Test
    func dateLabel_shouldReadLikeACalendar() {
        let sut = makeSUT()
        let weeks = sut.weeks(in: october)

        #expect(sut.dateLabel(for: weeks[0]) == "1 a 4 de out. de 2026")
        #expect(sut.dateLabel(for: weeks[2]) == "12 a 18 de out. de 2026")
    }

    // MARK: - Rules

    @Test
    func authorShare_whenOneAuthorHasAtLeast30Percent_shouldSayHowMuch() throws {
        let shares = (0..<4).map { share("A\($0)", by: "Ana", at: date(2026, 10, 12 + $0)) }
            + (0..<6).map { share("B\($0)", by: "Bia\($0)", at: date(2026, 10, 12)) }

        let highlight = try #require(makeSUT().highlights(in: october, shares: shares, plays: [], listenLogs: []).first)

        #expect(highlight.kind == .authorShare)
        #expect(highlight.headline == "40% dos seus compartilhamentos")
        #expect(highlight.detail == "Nesta semana, 4 das Vírgulas que você compartilhou foram de Ana.")
        #expect(highlight.emphasized == ["Ana"])
        #expect(highlight.artwork == .author(photo: "https://example.com/Ana.jpg"))
        #expect(highlight.dateLabel == "12 a 18 de out. de 2026")
    }

    @Test
    func authorShare_withFewerThanFiveShares_shouldNotShow() {
        let shares = (0..<4).map { share("A", by: "Ana", at: date(2026, 10, 12, 10 + $0)) }

        let kinds = makeSUT().highlights(in: october, shares: shares, plays: [], listenLogs: []).map(\.kind)

        #expect(!kinds.contains(.authorShare))
        #expect(kinds.contains(.soundOfTheWeek))
    }

    @Test
    func listeningStreak_shouldNeedThreeDaysInARow() {
        let logs = [
            listen("ep-1", at: date(2026, 10, 12), seconds: 300),
            listen("ep-1", at: date(2026, 10, 13), seconds: 300),
            listen("ep-1", at: date(2026, 10, 14), seconds: 300)
        ]
        let highlights = makeSUT(episodes: [episode("ep-1", title: "Primeiro")])
            .highlights(in: october, shares: [], plays: [], listenLogs: logs)

        let streak = highlights.first { $0.kind == .listeningStreak }
        #expect(streak?.headline == "Você teve uma sequência de 3 dias")
        #expect(streak?.detail == "Você ouviu o podcast dia após dia, com Primeiro à frente.")
        #expect(streak?.artwork == .episode(imageURL: URL(string: "https://example.com/ep-1.jpg")))

        let twoDays = makeSUT().highlights(in: october, shares: [], plays: [], listenLogs: Array(logs.prefix(2)))
        #expect(!twoDays.contains { $0.kind == .listeningStreak })
    }

    @Test
    func episodeOfTheWeek_shouldSayItsShareOfTheListening() {
        let logs = [
            listen("ep-1", at: date(2026, 10, 12), seconds: 3_000),
            listen("ep-2", at: date(2026, 10, 15), seconds: 2_000)
        ]

        let highlight = makeSUT(episodes: [episode("ep-1", title: "Primeiro")])
            .highlights(in: october, shares: [], plays: [], listenLogs: logs)
            .first { $0.kind == .episodeOfTheWeek }

        #expect(highlight?.headline == "60% do seu tempo de episódios")
        #expect(highlight?.detail == "Nesta semana você passou 50 min ouvindo Primeiro.")
    }

    @Test
    func soundOfTheWeek_withoutShares_shouldUsePlays() {
        let plays = (0..<5).map { share("Uma Vírgula", by: "Ana", at: date(2026, 10, 12, 10 + $0)) }

        let highlight = makeSUT().highlights(in: october, shares: [], plays: plays, listenLogs: [])
            .first { $0.kind == .soundOfTheWeek }

        #expect(highlight?.detail == "Você tocou Uma Vírgula, de Ana, 5 vezes.")
        #expect(highlight?.emphasized == ["Uma Vírgula", "Ana"])
    }

    @Test
    func finishedEpisodes_shouldListTwoAndCountTheRest() {
        let logs = ["ep-1", "ep-2", "ep-3"].map { listen($0, at: date(2026, 10, 12), seconds: 60, completed: true) }
        let episodes = [episode("ep-1", title: "Um"), episode("ep-2", title: "Dois"), episode("ep-3", title: "Três")]

        let highlight = makeSUT(episodes: episodes).highlights(in: october, shares: [], plays: [], listenLogs: logs)
            .first { $0.kind == .finishedEpisodes }

        #expect(highlight?.headline == "3 episódios até o fim")
        #expect(highlight?.detail == "Nesta semana você ouviu Um, Dois e mais 1 do começo ao fim.")
    }

    @Test
    func nightOwl_whenMostOfTheWeekIsAfter22h_shouldShow() {
        let shares = (0..<4).map { share("S\($0)", by: "A\($0)", at: date(2026, 10, 12 + $0, 23)) }
            + [share("X", by: "Z", at: date(2026, 10, 16, 15))]

        let highlight = makeSUT().highlights(in: october, shares: shares, plays: [], listenLogs: [])
            .first { $0.kind == .nightOwl }

        #expect(highlight?.detail == "80% do que você fez no app nesta semana foi depois das 22h.")
    }

    // MARK: - The Feed

    @Test
    func highlights_shouldPutTheNewestWeekFirst_andKeepAtMostThreePerWeek() {
        let earlyShares = (0..<6).map { _ in share("A", by: "Ana", at: date(2026, 10, 2, 23)) }
        let lateShares = (0..<6).map { share("B", by: "Bia", at: date(2026, 10, 20 + ($0 % 3), 23)) }

        let highlights = makeSUT().highlights(in: october, shares: earlyShares + lateShares, plays: [], listenLogs: [])

        #expect(highlights.first?.dateLabel == "19 a 25 de out. de 2026")
        #expect(highlights.last?.dateLabel == "1 a 4 de out. de 2026")
        let perWeek = Dictionary(grouping: highlights, by: \.dateLabel).mapValues(\.count)
        #expect(perWeek.values.allSatisfy { $0 <= MonthlyHighlightBuilder.maxPerWeek })
    }

    @Test
    func highlights_inAQuietWeek_shouldBeEmpty() {
        let highlights = makeSUT().highlights(in: october, shares: [share("A", at: date(2026, 10, 12))], plays: [], listenLogs: [])

        #expect(highlights.isEmpty)
    }
}
