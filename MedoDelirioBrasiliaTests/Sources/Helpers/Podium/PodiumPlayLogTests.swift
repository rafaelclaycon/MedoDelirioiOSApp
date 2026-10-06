//
//  PodiumPlayLogTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct PodiumPlayLogTests {

    private let apiClient: FakeAPIClient
    private let database: FakeLocalDatabase
    private let sut: Podium

    init() {
        apiClient = FakeAPIClient()
        apiClient.serverPath = "https://example.com/api/"
        database = FakeLocalDatabase()
        sut = Podium(database: database, apiClient: apiClient)
    }

    private func addPlays(_ count: Int) {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<count {
            database.playLogs.append(
                UserPlayLog(
                    id: "play-\(index)",
                    contentId: "content-\(index % 7)",
                    contentType: ContentType.sound.rawValue,
                    dateTime: start.addingTimeInterval(TimeInterval(index)),
                    isAutoplay: index % 2 == 1
                )
            )
        }
    }

    @Test
    func noPendingPlays_returnsNoLogsToSend_withoutTouchingTheServer() async {
        apiClient.serverShouldBeUnavailable = true

        let result = await sut.sendPlayLogsToServer()

        #expect(result == .noLogsToSend)
        #expect(apiClient.postedPlayLogBatches.isEmpty)
    }

    @Test
    func pendingPlays_areSentToTheBatchRoute_andMarkedAsSent() async {
        addPlays(3)

        let result = await sut.sendPlayLogsToServer()

        #expect(result == .successful)
        #expect(apiClient.postedPlayLogBatchURLs == [URL(string: "https://example.com/api/v4/play-logs")!])
        let plays = apiClient.postedPlayLogBatches.first?.plays ?? []
        #expect(plays.map(\.id) == ["play-0", "play-1", "play-2"])
        #expect(plays.map(\.isAutoplay) == [false, true, false])
        #expect(database.playLogs.allSatisfy { $0.sentToServer })
    }

    @Test
    func manyPendingPlays_areSplitIntoBatches() async {
        let total = Podium.playLogBatchSize * 2 + 10
        addPlays(total)

        let result = await sut.sendPlayLogsToServer()

        #expect(result == .successful)
        #expect(apiClient.postedPlayLogBatches.map(\.plays.count) == [Podium.playLogBatchSize, Podium.playLogBatchSize, 10])
        // Oldest first, and nothing sent twice.
        let sentIds = apiClient.postedPlayLogBatches.flatMap(\.plays).map(\.id)
        #expect(sentIds == (0..<total).map { "play-\($0)" })
        #expect(database.playLogs.allSatisfy { $0.sentToServer })
    }

    @Test
    func failedBatch_stopsTheRun_andKeepsEarlierBatchesMarked() async {
        addPlays(Podium.playLogBatchSize + 5)
        apiClient.failPlayLogBatchPostAtIndexes = [1]

        let result = await sut.sendPlayLogsToServer()

        guard case .failed = result else {
            Issue.record("Expected a failed result, got \(result)")
            return
        }
        #expect(database.playLogs.filter(\.sentToServer).count == Podium.playLogBatchSize)
        #expect(database.playLogs.filter { !$0.sentToServer }.count == 5)
    }

    @Test
    func serverUnavailable_sendsNothing() async {
        addPlays(2)
        apiClient.serverShouldBeUnavailable = true

        let result = await sut.sendPlayLogsToServer()

        guard case .failed = result else {
            Issue.record("Expected a failed result, got \(result)")
            return
        }
        #expect(apiClient.postedPlayLogBatches.isEmpty)
        #expect(database.playLogs.allSatisfy { !$0.sentToServer })
    }

    @Test
    func markingFailure_leavesPlaysPendingForARetry() async {
        addPlays(2)
        database.shouldFailMarkingPlayLogsAsSent = true

        let result = await sut.sendPlayLogsToServer()

        guard case .failed = result else {
            Issue.record("Expected a failed result, got \(result)")
            return
        }
        // Sent once and still pending: the next run re-sends them, and the server drops
        // the IDs it already has.
        #expect(apiClient.postedPlayLogBatches.count == 1)
        #expect(database.playLogs.allSatisfy { !$0.sentToServer })
    }

    @Test
    func aRunNeverSendsMoreThanItsBatchCap() async {
        addPlays(Podium.playLogBatchSize * (Podium.maxPlayLogBatchesPerRun + 1))

        let result = await sut.sendPlayLogsToServer()

        #expect(result == .successful)
        #expect(apiClient.postedPlayLogBatches.count == Podium.maxPlayLogBatchesPerRun)
        #expect(database.playLogs.filter { !$0.sentToServer }.count == Podium.playLogBatchSize)
    }
}
