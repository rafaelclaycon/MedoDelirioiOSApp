//
//  StoriesView+ViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/25.
//

import Foundation
import Combine

extension StoriesView {

    @MainActor
    class ViewModel: ObservableObject {

        // MARK: - Published Properties

        @Published var stories: [Story] = []
        @Published var isLoading: Bool = true

        // Vírgulas
        @Published var topSounds: [TopChartItem] = []
        @Published var topAuthor: TopAuthorItem?
        @Published var totalShareCount: Int = 0
        @Published var totalUniqueSoundsShared: Int = 0
        @Published var mostCommonShareDay: String = "-"
        /// The photo of each top sound's author, by author id.
        @Published var authorPhotos: [String: String] = [:]

        // Episodes
        @Published var secondsListened: Double = 0
        @Published var topEpisode: MonthlyStats.RankedEpisode?
        @Published var listeningDays: Int = 0
        @Published var longestListeningStreak: Int = 0
        @Published var episodesFinished: Int = 0

        /// "2026".
        let yearNumber: Int

        // MARK: - Private Properties

        private let database: LocalDatabaseProtocol
        /// The whole year being looked back on, in the person's own time zone.
        private let year: DateInterval
        private let calendar: Calendar
        private var cancellables = Set<AnyCancellable>()

        // MARK: - Initializer

        init(
            database: LocalDatabaseProtocol = LocalDatabase.shared,
            year: Int = 2026,
            calendar: Calendar = .current
        ) {
            self.database = database
            self.yearNumber = year
            self.calendar = calendar
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
            self.year = calendar.dateInterval(of: .year, for: start) ?? DateInterval(start: start, duration: 0)
        }

        // MARK: - Computed Properties

        var hasEpisodes: Bool { secondsListened >= 60 }

        /// Shares per week over the part of the year that has gone by.
        var sharesPerWeek: Int {
            let end = min(Date.now, year.end)
            let weeks = max(end.timeIntervalSince(year.start) / (7 * 86_400), 1)
            return Int((Double(totalShareCount) / weeks).rounded())
        }

        /// "42 horas", or "3h 20min" under ten hours, where the minutes still matter.
        var formattedListening: (value: String, unit: String) {
            let hours = secondsListened / 3600
            if hours >= 10 {
                return ("\(Int(hours))", "horas")
            }
            return (MonthlyStats.formattedDuration(secondsListened), "")
        }

        // MARK: - Public Methods

        func loadData() async {
            isLoading = true

            do {
                topSounds = try database.topSoundsSharedByTheUser(in: year, limit: 5)
            } catch {
                print("Error loading top sounds: \(error)")
                topSounds = []
            }
            authorPhotos = Dictionary(
                topSounds.compactMap { item in
                    (try? database.author(withId: item.contentAuthorId))?.photo.map { (item.contentAuthorId, $0) }
                },
                uniquingKeysWith: { first, _ in first }
            )

            totalUniqueSoundsShared = database.sharedSoundsCount(in: year)
            topAuthor = try? database.topAuthorSharedByTheUser(in: year)

            do {
                let dates = try database.shareDates(in: year)
                totalShareCount = dates.count
                mostCommonShareDay = mostCommonDay(from: dates) ?? "-"
            } catch {
                print("Error loading share dates: \(error)")
                totalShareCount = 0
                mostCommonShareDay = "-"
            }

            loadEpisodes()
            buildStories()

            isLoading = false
        }

        // MARK: - Private Methods

        private func loadEpisodes() {
            let logs = ((try? database.allEpisodeListenLogs()) ?? [])
                .filter { $0.startedAt >= year.start && $0.startedAt < year.end }
            let episodes = (try? database.allPodcastEpisodes()) ?? []
            let episodesById = Dictionary(episodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            secondsListened = logs.reduce(0) { $0 + $1.durationListened }
            topEpisode = MonthlyStatsProvider.rankedEpisodes(logs, episodes: episodesById, limit: 1).first
            listeningDays = Set(logs.map { calendar.startOfDay(for: $0.startedAt) }).count
            longestListeningStreak = EpisodeListenStats.longestStreak(from: logs.map(\.startedAt))
            episodesFinished = Set(logs.filter(\.didComplete).map(\.episodeId)).count
        }

        /// A countdown for the Vírgulas, so the number one comes last, then the episodes.
        private func buildStories() {
            var storyPages: [StoryPage] = [.intro]

            if totalShareCount > 0 {
                storyPages.append(.shares)
            }
            if topAuthor != nil {
                storyPages.append(.topAuthor)
            }
            let countdown: [StoryPage] = [.topSound1, .topSound2, .topSound3]
            storyPages += countdown.prefix(min(topSounds.count, 3)).reversed()

            if hasEpisodes {
                storyPages.append(.listening)
            }
            if topEpisode != nil, hasEpisodes {
                storyPages.append(.topEpisode)
            }
            if mostCommonShareDay != "-" || longestListeningStreak >= 2 {
                storyPages.append(.habits)
            }

            storyPages.append(.share)
            stories = storyPages.map { $0.story }
        }

        private func mostCommonDay(from dates: [Date]) -> String? {
            guard !dates.isEmpty else { return nil }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "pt-BR")
            dateFormatter.dateFormat = "EEEE"

            // Count occurrences of each day of the week
            var dayCounts: [String: Int] = [:]
            for date in dates {
                let dayName = dateFormatter.string(from: date)
                dayCounts[dayName, default: 0] += 1
            }

            // Find the most common day and capitalize only the first letter
            // Using prefix(1).uppercased() to avoid "Segunda-Feira" from .capitalized
            guard let mostCommon = dayCounts.max(by: { $0.value < $1.value })?.key else {
                return nil
            }
            return mostCommon.prefix(1).uppercased() + mostCommon.dropFirst()
        }

        func topSound(at index: Int) -> TopChartItem? {
            guard index < topSounds.count else { return nil }
            return topSounds[index]
        }

        func analyticsString() -> String {
            let ranking = topSounds.prefix(5).enumerated().map { "\($0.offset + 1) \($0.element.contentName)" }
            let authorInfo = topAuthor.map { "\($0.authorName); \($0.authorPhoto ?? "no-photo")" } ?? "no-author"
            let episodeInfo = topEpisode.map { "\(Int(secondsListened / 60)) min; \($0.title)" } ?? "no-episodes"
            return "\(ranking.joined(separator: ", ")); \(totalShareCount) compart; \(mostCommonShareDay); \(authorInfo); \(episodeInfo)"
        }
    }
}
