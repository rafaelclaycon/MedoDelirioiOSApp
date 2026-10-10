//
//  FakeAPIClient.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 20/06/22.
//

import Foundation

class FakeAPIClient: APIClientProtocol {

    var serverPath: String

    var serverShouldBeUnavailable = false
    var fetchUpdateEventsResult: ContentUpdateResult = .nothingToUpdate

    var updateEvents = [UpdateEvent]()
    var shareCountStatsPosted = [ServerShareCountStat]()
    var failShareCountPostAtIndexes = Set<Int>()
    var shareCountPostCalls = 0
    var postedBundleIdLogs = [ServerShareBundleIdLog]()
    var shouldFailBundleIdPost = false
    var postedPlayLogBatches = [ServerPlayLogBatch]()
    var postedPlayLogBatchURLs = [URL]()
    var failPlayLogBatchPostAtIndexes = Set<Int>()
    private var playLogBatchPostCalls = 0

    var sound: Sound?
    var song: Song?
    var author: Author?
    var musicGenre: MusicGenre?

    init() {
        serverPath = ""
    }

    func get<T>(from url: URL) async throws -> T where T : Decodable, T : Encodable {
        return T.self as! T
    }

    func serverIsAvailable() async -> Bool {
        return !serverShouldBeUnavailable
    }

    func post(shareCountStat: ServerShareCountStat) async throws {
        if failShareCountPostAtIndexes.contains(shareCountPostCalls) {
            shareCountPostCalls += 1
            throw APIClientError.unexpectedStatusCode
        }
        shareCountStatsPosted.append(shareCountStat)
        shareCountPostCalls += 1
    }

    func post(clientDeviceInfo: ClientDeviceInfo) async throws {
        //
    }

    func fetchUpdateEvents(from lastDate: String) async throws -> [MedoDelirio.UpdateEvent] {
        switch fetchUpdateEventsResult {
        default:
            return updateEvents
        }
    }

    func post<T>(to url: URL, body: T) async throws where T : Encodable {
        if let log = body as? ServerShareBundleIdLog {
            if shouldFailBundleIdPost {
                throw APIClientError.unexpectedStatusCode
            }
            postedBundleIdLogs.append(log)
        }
        if let batch = body as? ServerPlayLogBatch {
            defer { playLogBatchPostCalls += 1 }
            if failPlayLogBatchPostAtIndexes.contains(playLogBatchPostCalls) {
                throw APIClientError.unexpectedStatusCode
            }
            postedPlayLogBatches.append(batch)
            postedPlayLogBatchURLs.append(url)
        }
    }

    func getString(from url: URL) async throws -> String? {
        nil
    }

    func displayAskForMoneyView(appVersion: String) async -> Bool {
        false
    }

    func getDonorNames() async -> [Donor]? {
        nil
    }

    func getReactionsStats() async throws -> [TopChartReaction] {
        []
    }

    func getShareCountStats(
        for contentType: TrendsContentType,
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopChartItem] {
        []
    }

    func top3Reactions() async throws -> [Reaction] {
        []
    }

    func moneyInfo() async throws -> [MoneyInfo] {
        []
    }

    func sound(_ id: String) async throws -> Sound {
        guard let sound else { throw APIClientError.resourceNotFound }
        return sound
    }

    func song(_ id: String) async throws -> Song {
        guard let song else { throw APIClientError.resourceNotFound }
        return song
    }

    func author(_ id: String) async throws -> Author {
        author!
    }

    func musicGenre(_ id: String) async throws -> MusicGenre {
        musicGenre!
    }
}
