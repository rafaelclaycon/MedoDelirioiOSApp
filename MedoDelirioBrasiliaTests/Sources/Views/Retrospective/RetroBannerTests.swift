//
//  RetroBannerTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 05/11/26.
//

import Testing
import Foundation
@testable import MedoDelirio

/// When the Retrospectiva banner may show: what the server says for this version, and whether
/// the year has anything in it.
@MainActor
struct RetroBannerTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func sound(_ id: String) -> TopChartItem {
        TopChartItem(id: id, rankNumber: "", contentId: id, contentName: id, contentAuthorId: "a", contentAuthorName: "A", shareCount: 1)
    }

    private func listen(on date: Date, seconds: Double) -> EpisodeListenLog {
        EpisodeListenLog(episodeId: "ep", startedAt: date, endedAt: date.addingTimeInterval(seconds), durationListened: seconds, didComplete: false)
    }

    // MARK: - Something to show

    @Test
    func hasSomethingToShow_withNothingThisYear_isFalse() {
        let database = FakeLocalDatabase()
        database.topSharedSounds = [sound("s1")]
        database.shareDates = [date(2025, 12, 31)]
        database.episodeListenLogs = [listen(on: date(2025, 6, 1), seconds: 3600)]

        #expect(!StoriesView.ViewModel.hasSomethingToShow(year: 2026, database: database, calendar: calendar))
    }

    @Test
    func hasSomethingToShow_withAShareThisYear_isTrue() {
        let database = FakeLocalDatabase()
        database.topSharedSounds = [sound("s1")]
        database.shareDates = [date(2026, 3, 10)]

        #expect(StoriesView.ViewModel.hasSomethingToShow(year: 2026, database: database, calendar: calendar))
    }

    @Test
    func hasSomethingToShow_withAMinuteOfEpisodes_isTrue() {
        let database = FakeLocalDatabase()
        database.episodeListenLogs = [
            listen(on: date(2026, 5, 1), seconds: 30),
            listen(on: date(2026, 5, 2), seconds: 30)
        ]

        #expect(StoriesView.ViewModel.hasSomethingToShow(year: 2026, database: database, calendar: calendar))
    }

    @Test
    func hasSomethingToShow_withLessThanAMinuteOfEpisodes_isFalse() {
        let database = FakeLocalDatabase()
        database.episodeListenLogs = [listen(on: date(2026, 5, 1), seconds: 59)]

        #expect(!StoriesView.ViewModel.hasSomethingToShow(year: 2026, database: database, calendar: calendar))
    }

    // MARK: - Server

    private let url = "v4/retro-banner?appVersion=13.9"

    private func makeRepository(_ apiClient: FakeAPIClient) -> BannerRepository {
        BannerRepository(apiClient: apiClient, currentAppVersion: "13.9")
    }

    @Test(arguments: [true, false])
    func showRetroBanner_asksWithTheAppVersion_andPassesTheAnswerOn(show: Bool) async {
        let apiClient = FakeAPIClient()
        apiClient.getResponses[url] = Data(#"{"show": \#(show)}"#.utf8)

        #expect(await makeRepository(apiClient).showRetroBanner() == show)
    }

    @Test
    func showRetroBanner_whenTheRequestFails_isNil() async {
        let apiClient = FakeAPIClient()
        apiClient.getErrors[url] = APIClientError.unexpectedStatusCode

        #expect(await makeRepository(apiClient).showRetroBanner() == nil)
    }
}
