//
//  FakeEpisodesService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 17/06/26.
//

import Foundation

final class FakeEpisodesService: EpisodesServiceProtocol {

    /// Episodes the fake writes into the database on `syncEpisodes` and returns from `fetchEpisodes`.
    var episodesToReturn: [PodcastEpisode] = []

    /// When set, both methods throw this instead of succeeding.
    var errorToThrow: Error?

    private(set) var fetchEpisodesCallCount = 0
    private(set) var syncEpisodesCallCount = 0

    func fetchEpisodes(from url: URL) async throws -> [PodcastEpisode] {
        fetchEpisodesCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return episodesToReturn
    }

    func syncEpisodes(database: LocalDatabaseProtocol) async throws {
        syncEpisodesCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        try database.upsertPodcastEpisodes(episodesToReturn)
    }
}
