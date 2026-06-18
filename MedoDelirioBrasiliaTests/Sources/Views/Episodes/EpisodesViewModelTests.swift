//
//  EpisodesViewModelTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 17/06/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct EpisodesViewModelTests {

    // MARK: - Helpers

    private func makeEpisode(_ id: String, pubDate: Date = Date(timeIntervalSince1970: 0)) -> PodcastEpisode {
        PodcastEpisode(
            id: id,
            title: "Episode \(id)",
            pubDate: pubDate,
            audioURL: URL(string: "https://example.com/\(id).mp3")!,
            description: nil,
            imageURL: nil,
            duration: nil,
            explicit: false
        )
    }

    private func makeSUT(
        database: FakeLocalDatabase = FakeLocalDatabase(),
        service: FakeEpisodesService = FakeEpisodesService(),
        analytics: FakeAnalyticsService = FakeAnalyticsService()
    ) -> EpisodesView.ViewModel {
        EpisodesView.ViewModel(
            episodesService: service,
            database: database,
            analyticsService: analytics
        )
    }

    // MARK: - onViewLoaded (success)

    @Test
    func onViewLoaded_withEmptyCacheAndSuccessfulSync_shouldLoadFetchedEpisodes() async {
        let database = FakeLocalDatabase()
        let service = FakeEpisodesService()
        service.episodesToReturn = [makeEpisode("1"), makeEpisode("2")]
        let sut = makeSUT(database: database, service: service)

        await sut.onViewLoaded()

        #expect(service.syncEpisodesCallCount == 1)
        #expect(sut.state == .loaded([makeEpisode("1"), makeEpisode("2")]))
    }

    @Test
    func onViewLoaded_withExistingCache_shouldLoadRefreshedEpisodesAfterSync() async {
        let database = FakeLocalDatabase()
        let cached = makeEpisode("1")
        database.podcastEpisodes = [cached]
        let service = FakeEpisodesService()
        let fetched = makeEpisode("2")
        service.episodesToReturn = [fetched]
        let sut = makeSUT(database: database, service: service)

        await sut.onViewLoaded()

        #expect(sut.state == .loaded([cached, fetched]))
    }

    // MARK: - onViewLoaded (generic error)

    @Test
    func onViewLoaded_withEmptyCacheAndSyncFailure_shouldEnterErrorState() async {
        let service = FakeEpisodesService()
        service.errorToThrow = EpisodesServiceError.invalidFeedFormat
        let analytics = FakeAnalyticsService()
        let sut = makeSUT(service: service, analytics: analytics)

        await sut.onViewLoaded()

        #expect(sut.state == .error("Não foi possível carregar os episódios."))
        #expect(sut.toast == nil)
        #expect(analytics.didCallSendOriginatingScreen)
    }

    @Test
    func onViewLoaded_withCachedEpisodesAndSyncFailure_shouldKeepCacheAndShowToast() async {
        let database = FakeLocalDatabase()
        let cached = makeEpisode("1")
        database.podcastEpisodes = [cached]
        let service = FakeEpisodesService()
        service.errorToThrow = EpisodesServiceError.invalidHTTPResponse
        let analytics = FakeAnalyticsService()
        let sut = makeSUT(database: database, service: service, analytics: analytics)

        await sut.onViewLoaded()

        #expect(sut.state == .loaded([cached]))
        #expect(sut.toast != nil)
        #expect(analytics.didCallSendOriginatingScreen)
    }

    // MARK: - onViewLoaded (cancellation is not a failure)

    @Test
    func onViewLoaded_withEmptyCacheAndCancellationError_shouldErrorWithoutReportingAnalytics() async {
        let service = FakeEpisodesService()
        service.errorToThrow = CancellationError()
        let analytics = FakeAnalyticsService()
        let sut = makeSUT(service: service, analytics: analytics)

        await sut.onViewLoaded()

        #expect(sut.state == .error("Não foi possível carregar os episódios."))
        #expect(sut.toast == nil)
        #expect(analytics.didCallSendOriginatingScreen == false)
    }

    @Test
    func onViewLoaded_withEmptyCacheAndURLCancellation_shouldErrorWithoutReportingAnalytics() async {
        let service = FakeEpisodesService()
        service.errorToThrow = URLError(.cancelled)
        let analytics = FakeAnalyticsService()
        let sut = makeSUT(service: service, analytics: analytics)

        await sut.onViewLoaded()

        #expect(sut.state == .error("Não foi possível carregar os episódios."))
        #expect(analytics.didCallSendOriginatingScreen == false)
    }

    @Test
    func onViewLoaded_withCachedEpisodesAndCancellation_shouldKeepCacheWithoutToastOrAnalytics() async {
        let database = FakeLocalDatabase()
        let cached = makeEpisode("1")
        database.podcastEpisodes = [cached]
        let service = FakeEpisodesService()
        service.errorToThrow = CancellationError()
        let analytics = FakeAnalyticsService()
        let sut = makeSUT(database: database, service: service, analytics: analytics)

        await sut.onViewLoaded()

        #expect(sut.state == .loaded([cached]))
        #expect(sut.toast == nil)
        #expect(analytics.didCallSendOriginatingScreen == false)
    }

    // MARK: - onTryAgainSelected

    @Test
    func onTryAgainSelected_shouldRetrySyncAndRecover() async {
        let database = FakeLocalDatabase()
        let service = FakeEpisodesService()
        service.episodesToReturn = [makeEpisode("1")]
        let sut = makeSUT(database: database, service: service)

        await sut.onTryAgainSelected()

        #expect(service.syncEpisodesCallCount == 1)
        #expect(sut.state == .loaded([makeEpisode("1")]))
    }

    // MARK: - onPullToRefresh

    @Test
    func onPullToRefresh_withSuccess_shouldRefreshIntoLoadedState() async {
        let database = FakeLocalDatabase()
        let service = FakeEpisodesService()
        service.episodesToReturn = [makeEpisode("1"), makeEpisode("2")]
        let sut = makeSUT(database: database, service: service)

        await sut.onPullToRefresh()

        #expect(service.syncEpisodesCallCount == 1)
        #expect(sut.state == .loaded([makeEpisode("1"), makeEpisode("2")]))
    }

    @Test
    func onPullToRefresh_withCachedEpisodesAndFailure_shouldShowToast() async {
        let database = FakeLocalDatabase()
        database.podcastEpisodes = [makeEpisode("1")]
        let service = FakeEpisodesService()
        service.errorToThrow = EpisodesServiceError.invalidHTTPResponse
        let sut = makeSUT(database: database, service: service)

        // Load the cache first so the view model is in a .loaded state.
        await sut.onViewLoaded()
        sut.toast = nil

        await sut.onPullToRefresh()

        #expect(sut.toast != nil)
    }
}
