//
//  APIClient+ShareStats.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/03/25.
//

import Foundation

extension APIClient {

    func getShareCountStats(
        for contentType: TrendsContentType,
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopChartItem] {
        let keyword = contentType == .sounds ? "sound" : "song"
        let url = URL(string: serverPath + "v3/\(keyword)-share-count-stats" + Self.statsPeriodPath(for: timeInterval))!
        return try await self.get(from: url)
    }

    func getEpisodePlayStats(
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopEpisodeItem] {
        let url = URL(string: serverPath + "v4/episode-play-count-stats" + Self.statsPeriodPath(for: timeInterval))!
        return try await self.get(from: url)
    }

    /// The end of a ranking URL, shared by the share and play rankings.
    private static func statsPeriodPath(for timeInterval: TrendsTimeInterval) -> String {
        switch timeInterval {
        case .last24Hours:
            "-from/\(Date.dateAsString(addingDays: -1))"
        case .last3Days:
            "-from/\(Date.dateAsString(addingDays: -3))"
        case .lastWeek:
            "-from/\(Date.dateAsString(addingDays: -7))"
        case .lastMonth:
            "-from/\(Date.dateAsString(addingDays: -30))"
        case .last3Months:
            "-from/\(Date.dateAsString(addingDays: -90))"
        case .year2026:
            "-from-to/2026-01-01/2026-12-31"
        case .year2025:
            "-from-to/2025-01-01/2025-12-31"
        case .year2024:
            "-from-to/2024-01-01/2024-12-31"
        case .year2023:
            "-from-to/2023-01-01/2023-12-31"
        case .year2022:
            "-from-to/2022-01-01/2022-12-31"
        case .allTime:
            "-all-time"
        }
    }

    func top3Reactions() async throws -> [Reaction] {
        let url = URL(string: serverPath + "v4/top-3-reactions")!
        let reactions: [ReactionDTO] = try await self.get(from: url)
        return reactions.map { $0.reaction }
    }

    func getReactionsStats() async throws -> [TopChartReaction] {
        let url = URL(string: serverPath + "v3/reaction-popularity-stats")!
        let serverStats: [TopChartReactionDTO] = try await self.get(from: url)
        return APIClient.groupedStats(from: serverStats)
    }

    public static func groupedStats(from stats: [TopChartReactionDTO]) -> [TopChartReaction] {
        guard !stats.isEmpty else { return [] }

        // Filter out invalid reactions before processing
        let validStats = stats.filter { isValidReaction($0) }
        guard !validStats.isEmpty else { return [] }

        let grouped = Dictionary(grouping: validStats) { $0.reaction.title }

        let merged = grouped.map { (title, group) -> TopChartReaction in
            let first = group.first!

            let descriptions = group.compactMap { $0.description }

            var newDescription = ""
            if descriptions.count == 1 {
                newDescription = descriptions[0]
            } else if descriptions.count == 2 {
                newDescription = "\(descriptions[0]) & \(descriptions[1])"
            } else if descriptions.count > 2 {
                let allButLast = descriptions.dropLast().joined(separator: ", ")
                let last = descriptions.last!
                newDescription = "\(allButLast) & \(last)"
            }

            return TopChartReaction(
                id: UUID().uuidString,
                position: first.position,
                reaction: first.reaction.reaction,
                description: newDescription
            )
        }

        return merged.sorted { $0.position < $1.position }
    }

    /// Validates if a TopChartReactionDTO has all required fields populated
    private static func isValidReaction(_ reactionDTO: TopChartReactionDTO) -> Bool {
        let reaction = reactionDTO.reaction

        // Check if essential fields are not null and not empty
        guard let id = reaction.id, !id.isEmpty,
              let title = reaction.title, !title.isEmpty,
              let image = reaction.image, !image.isEmpty,
              let lastUpdate = reaction.lastUpdate, !lastUpdate.isEmpty else {
            return false
        }

        return true
    }
}
