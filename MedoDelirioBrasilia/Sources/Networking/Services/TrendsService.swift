//
//  TrendsService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 06/05/25.
//

import Foundation

@MainActor
protocol TrendsServiceProtocol {

    // Receiving

    func shareCountStats(
        for contentType: TrendsContentType,
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopChartItem]

    /// Returns top 3 most shared Content in the last week.
    func top3Content() async throws -> [AnyEquatableMedoContent]
    /// Returns top 3 most opened Reactions in the current day.
    func top3Reactions() async throws -> [Reaction]

    func reactionsStats() async throws -> [TopChartReaction]

    func top10SoundsSharedByTheUser() -> [TopChartItem]?

    // Sending

    func sendUserPersonalTrendsToServerIfEnabled() async
}

@MainActor
final class TrendsService: TrendsServiceProtocol {

    public nonisolated static let defaultSoundsTimeInterval: TrendsTimeInterval = .last24Hours
    public nonisolated static let defaultSongsTimeInterval: TrendsTimeInterval = .lastWeek

    /// Shared singleton instance with default dependencies
    public static let shared = TrendsService(
        database: LocalDatabase.shared,
        apiClient: APIClient.shared,
        contentRepository: ContentRepository(database: LocalDatabase.shared)
    )

    private let apiClient: APIClientProtocol
    private let contentRepository: ContentRepositoryProtocol

    private var defaultSoundStats: [TopChartItem]
    private var defaultSongStats: [TopChartItem]
    private var todaysTop3Reactions: [Reaction]
    private var reactionStats: [TopChartReaction]

    private var soundsLastUpdate: Date = Date(timeIntervalSince1970: 0)
    private var songsLastUpdate: Date = Date(timeIntervalSince1970: 0)
    private var top3ReactionsLastUpdate: Date = Date(timeIntervalSince1970: 0)
    private var reactionsLastUpdate: Date = Date(timeIntervalSince1970: 0)

    private static let cacheExpirationMinutes = 60

    // MARK: - Initializer

    init(
        database: LocalDatabaseProtocol,
        apiClient: APIClientProtocol,
        contentRepository: ContentRepositoryProtocol
    ) {
        // Note: database parameter kept for API compatibility but not currently used
        self.apiClient = apiClient
        self.contentRepository = contentRepository
        self.defaultSoundStats = []
        self.defaultSongStats = []
        self.todaysTop3Reactions = []
        self.reactionStats = []

        Task {
            await loadSoundStats(timeInterval: TrendsService.defaultSoundsTimeInterval)
            await loadSongStats(timeInterval: TrendsService.defaultSongsTimeInterval)
            await loadReactions()
            await loadTop3Reactions()
        }
    }

    // MARK: - Receiving Functions

    func shareCountStats(
        for contentType: TrendsContentType,
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopChartItem] {
        switch contentType {
        case .sounds:
            switch timeInterval {
            case .last24Hours:
                if soundsLastUpdate.minutesPassed(Self.cacheExpirationMinutes) {
                    await loadSoundStats(timeInterval: timeInterval)
                }
                return defaultSoundStats

            default:
                return try await apiClient.getShareCountStats(
                    for: .sounds,
                    in: timeInterval
                )
            }

        case .songs:
            switch timeInterval {
            case .lastWeek:
                if songsLastUpdate.minutesPassed(Self.cacheExpirationMinutes) {
                    await loadSongStats(timeInterval: timeInterval)
                }
                return defaultSongStats

            default:
                return try await apiClient.getShareCountStats(
                    for: .songs,
                    in: timeInterval
                )
            }
        }
    }

    func top3Content() async throws -> [AnyEquatableMedoContent] {
        if soundsLastUpdate.minutesPassed(Self.cacheExpirationMinutes) {
            await loadSoundStats(timeInterval: .lastWeek)
        }
        return try contentRepository.content(withIds: defaultSoundStats.prefix(3).map { $0.contentId }) // TODO: Include songs here
    }

    func top3Reactions() async throws -> [Reaction] {
        if top3ReactionsLastUpdate.minutesPassed(Self.cacheExpirationMinutes) {
            await loadTop3Reactions()
        }
        return todaysTop3Reactions
    }

    func reactionsStats() async throws -> [TopChartReaction] {
        if reactionsLastUpdate.minutesPassed(Self.cacheExpirationMinutes) {
            await loadReactions()
        }
        return reactionStats
    }

    func top10SoundsSharedByTheUser() -> [TopChartItem]? {
        return nil
    }

    // MARK: - Sending Functions

    func sendUserPersonalTrendsToServerIfEnabled() async {
        //
    }
}

// MARK: - Internal Functions

extension TrendsService {

    private func loadSoundStats(
        timeInterval: TrendsTimeInterval
    ) async {
        do {
            defaultSoundStats = try await apiClient.getShareCountStats(
                for: .sounds,
                in: timeInterval
            )
            soundsLastUpdate = .now
        } catch {
            debugPrint(error)
        }
    }

    private func loadSongStats(
        timeInterval: TrendsTimeInterval
    ) async {
        do {
            defaultSongStats = try await apiClient.getShareCountStats(
                for: .songs,
                in: timeInterval
            )
            songsLastUpdate = .now
        } catch {
            debugPrint(error)
        }
    }

    private func loadTop3Reactions() async {
        do {
            todaysTop3Reactions = try await apiClient.top3Reactions()
            top3ReactionsLastUpdate = .now
        } catch {
            debugPrint(error)
        }
    }

    private func loadReactions() async {
        do {
            reactionStats = try await apiClient.getReactionsStats()
            reactionsLastUpdate = .now
        } catch {
            debugPrint(error)
        }
    }
}
