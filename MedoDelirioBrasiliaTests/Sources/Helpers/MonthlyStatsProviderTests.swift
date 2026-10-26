//
//  MonthlyStatsProviderTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 25/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct MonthlyStatsProviderTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    private let database = FakeLocalDatabase()

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private var now: Date { date(2026, 10, 25) }

    private func makeSUT() -> MonthlyStatsProvider {
        MonthlyStatsProvider(database: database, calendar: calendar)
    }

    private func event(_ sound: String, by author: String = "Autor", at date: Date) -> PersonalSoundEvent {
        PersonalSoundEvent(contentId: sound, contentName: sound, authorId: author, authorName: author, authorPhoto: nil, date: date)
    }

    private func listen(_ episodeId: String, at start: Date, seconds: Double, completed: Bool = false) -> EpisodeListenLog {
        EpisodeListenLog(
            episodeId: episodeId,
            startedAt: start,
            endedAt: start.addingTimeInterval(seconds),
            durationListened: seconds,
            didComplete: completed
        )
    }

    private func episode(_ id: String, title: String) -> PodcastEpisode {
        PodcastEpisode(
            id: id,
            title: title,
            pubDate: Date(timeIntervalSince1970: 0),
            audioURL: URL(string: "https://example.com/\(id).mp3")!,
            description: nil,
            imageURL: URL(string: "https://example.com/\(id).jpg"),
            duration: nil,
            explicit: false
        )
    }

    // MARK: - StatsMonth

    @Test
    func statsMonth_interval_shouldCoverTheWholeMonthInLocalTime() {
        let interval = StatsMonth(year: 2026, month: 9).interval(in: calendar)

        #expect(interval.start == date(2026, 9, 1, 0))
        #expect(interval.end == date(2026, 10, 1, 0))
    }

    @Test
    func statsMonth_adding_shouldCrossYears() {
        #expect(StatsMonth(year: 2026, month: 12).adding(months: 1) == StatsMonth(year: 2027, month: 1))
        #expect(StatsMonth(year: 2026, month: 1).adding(months: -1) == StatsMonth(year: 2025, month: 12))
    }

    @Test
    func statsMonth_names_shouldBePortuguese() {
        #expect(StatsMonth(year: 2026, month: 9).name == "Setembro")
        #expect(StatsMonth(year: 2026, month: 3).name == "Março")
        #expect(StatsMonth(year: 2026, month: 10).shortName == "out.")
    }

    // MARK: - Available Months

    @Test
    func availableMonths_shouldListOnlyMonthsWithDataSince2026_oldestFirst() {
        database.shareEvents = [
            event("A", at: date(2025, 12, 20)),
            event("A", at: date(2026, 3, 10)),
            event("B", at: date(2026, 9, 5))
        ]
        database.playEvents = [event("C", at: date(2026, 10, 2))]

        let months = makeSUT().availableMonths(now: now)

        #expect(months.map(\.month) == [
            StatsMonth(year: 2026, month: 3),
            StatsMonth(year: 2026, month: 9),
            StatsMonth(year: 2026, month: 10)
        ])
        #expect(months.map(\.isInProgress) == [false, false, true])
    }

    @Test
    func availableMonths_shouldCountEpisodeOnlyMonths() {
        database.episodeListenLogs = [listen("ep-1", at: date(2026, 4, 3), seconds: 600)]

        let months = makeSUT().availableMonths(now: now)

        #expect(months.map(\.month) == [StatsMonth(year: 2026, month: 4)])
    }

    @Test
    func availableMonths_whenNothingWasDone_shouldBeEmpty() {
        #expect(makeSUT().availableMonths(now: now).isEmpty)
    }

    // MARK: - Featured Month

    @Test
    func featured_shouldPreferTheLastMonthThatIsOver() {
        database.shareEvents = [
            event("A", at: date(2026, 8, 1)),
            event("A", at: date(2026, 9, 1)),
            event("A", at: date(2026, 10, 1))
        ]

        let featured = MonthlyStatsProvider.featured(in: makeSUT().availableMonths(now: now))

        #expect(featured?.month == StatsMonth(year: 2026, month: 9))
    }

    @Test
    func featured_whenOnlyTheCurrentMonthHasData_shouldUseIt() {
        database.shareEvents = [event("A", at: date(2026, 10, 1))]

        let featured = MonthlyStatsProvider.featured(in: makeSUT().availableMonths(now: now))

        #expect(featured?.month == StatsMonth(year: 2026, month: 10))
        #expect(featured?.title == "Outubro (até agora)")
    }

    // MARK: - A Month's Numbers

    @Test
    func stats_shouldSplitSharesAtLocalMidnight() {
        database.shareEvents = [
            event("A", at: date(2026, 9, 30, 23, 30)),
            event("A", at: date(2026, 10, 1, 0, 10))
        ]

        let sut = makeSUT()

        #expect(sut.stats(for: StatsMonth(year: 2026, month: 9), now: now).shareCount == 1)
        #expect(sut.stats(for: StatsMonth(year: 2026, month: 10), now: now).shareCount == 1)
    }

    @Test
    func stats_shouldRankSoundsByCount_tiesGoingToTheMostRecent() {
        database.shareEvents = [
            event("A", at: date(2026, 9, 2)),
            event("B", at: date(2026, 9, 3)),
            event("B", at: date(2026, 9, 4)),
            event("C", at: date(2026, 9, 5)),
            event("A", at: date(2026, 9, 6))
        ]

        let stats = makeSUT().stats(for: StatsMonth(year: 2026, month: 9), now: now)

        #expect(stats.topSharedSounds.map(\.contentName) == ["A", "B", "C"])
        #expect(stats.topSharedSounds.map(\.rankNumber) == ["1", "2", "3"])
        #expect(stats.topSharedSounds.map(\.shareCount) == [2, 2, 1])
    }

    @Test
    func stats_shouldRankAuthorsBySharesThenPlays() {
        database.shareEvents = [
            event("A", by: "Ana", at: date(2026, 9, 2)),
            event("B", by: "Bia", at: date(2026, 9, 3)),
            event("C", by: "Bia", at: date(2026, 9, 4))
        ]
        database.playEvents = [
            event("D", by: "Caio", at: date(2026, 9, 5)),
            event("A", by: "Ana", at: date(2026, 9, 5))
        ]

        let stats = makeSUT().stats(for: StatsMonth(year: 2026, month: 9), now: now)

        #expect(stats.topAuthors.map(\.name) == ["Bia", "Ana", "Caio"])
        #expect(stats.topAuthors.map(\.shareCount) == [2, 1, 0])
        #expect(stats.topAuthors.map(\.playCount) == [0, 1, 1])
    }

    @Test
    func stats_shouldAddUpTheMonthsEpisodes() {
        database.podcastEpisodes = [episode("ep-1", title: "Primeiro"), episode("ep-2", title: "Segundo")]
        database.episodeListenLogs = [
            listen("ep-1", at: date(2026, 9, 2), seconds: 1200),
            listen("ep-2", at: date(2026, 9, 3), seconds: 3000, completed: true),
            listen("ep-2", at: date(2026, 9, 4), seconds: 600, completed: true),
            // Another month.
            listen("ep-1", at: date(2026, 8, 31), seconds: 9000, completed: true)
        ]

        let stats = makeSUT().stats(for: StatsMonth(year: 2026, month: 9), now: now)

        #expect(stats.secondsListened == 4800)
        #expect(stats.minutesListened == 80)
        #expect(stats.topEpisodes.map(\.title) == ["Segundo", "Primeiro"])
        #expect(stats.topEpisode?.imageURL == URL(string: "https://example.com/ep-2.jpg"))
        #expect(stats.episodesFinished == 1)
    }

    @Test
    func stats_activeDays_shouldCountEachDayOnceAcrossSharesPlaysAndListens() {
        database.shareEvents = [event("A", at: date(2026, 9, 2, 9)), event("A", at: date(2026, 9, 2, 20))]
        database.playEvents = [event("A", at: date(2026, 9, 2, 21)), event("A", at: date(2026, 9, 3))]
        database.episodeListenLogs = [listen("ep-1", at: date(2026, 9, 4), seconds: 60)]

        let stats = makeSUT().stats(for: StatsMonth(year: 2026, month: 9), now: now)

        #expect(stats.activeDays == 3)
    }

    // MARK: - Formatting

    @Test
    func formattedDuration_shouldReadNaturally() {
        #expect(MonthlyStats.formattedDuration(12_000) == "3h 20min")
        #expect(MonthlyStats.formattedDuration(3_600) == "1h")
        #expect(MonthlyStats.formattedDuration(2_700) == "45 min")
        #expect(MonthlyStats.formattedDuration(20) == "1 min")
    }

    @Test
    func summary_shouldJoinSharesAndListening() {
        database.shareEvents = (1...47).map { event("A", at: date(2026, 9, 5).addingTimeInterval(Double($0))) }
        database.episodeListenLogs = [listen("ep-1", at: date(2026, 9, 6), seconds: 12_000)]

        let stats = makeSUT().stats(for: StatsMonth(year: 2026, month: 9), now: now)

        #expect(stats.summary == "47 compartilhamentos e 3h 20min de episódios")
    }

    @Test
    func summary_withOnlyOnePlay_shouldUseTheSingular() {
        database.playEvents = [event("A", at: date(2026, 9, 5))]

        let stats = makeSUT().stats(for: StatsMonth(year: 2026, month: 9), now: now)

        #expect(stats.summary == "1 Vírgula tocada")
    }
}
