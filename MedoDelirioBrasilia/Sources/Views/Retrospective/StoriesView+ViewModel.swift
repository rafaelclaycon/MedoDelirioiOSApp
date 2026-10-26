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
        @Published var topSounds: [TopChartItem] = []
        @Published var topAuthor: TopAuthorItem?
        @Published var totalShareCount: Int = 0
        @Published var totalUniqueSoundsShared: Int = 0
        @Published var mostCommonShareDay: String = "-"
        @Published var isLoading: Bool = true
        
        // MARK: - Private Properties
        
        private let database: LocalDatabaseProtocol
        /// The whole year being looked back on, in the person's own time zone.
        private let year: DateInterval
        private var cancellables = Set<AnyCancellable>()
        
        // MARK: - Initializer
        
        init(
            database: LocalDatabaseProtocol = LocalDatabase.shared,
            year: Int = 2026,
            calendar: Calendar = .current
        ) {
            self.database = database
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
            self.year = calendar.dateInterval(of: .year, for: start) ?? DateInterval(start: start, duration: 0)
        }
        
        // MARK: - Public Methods
        
        func loadData() async {
            isLoading = true
            
            // Load top sounds
            do {
                topSounds = try database.topSoundsSharedByTheUser(in: year, limit: 5)
            } catch {
                print("Error loading top sounds: \(error)")
                topSounds = []
            }
            
            // Load unique sounds and top author
            totalUniqueSoundsShared = database.sharedSoundsCount(in: year)
            topAuthor = try? database.topAuthorSharedByTheUser(in: year)
            
            // Load share count and most common share day
            do {
                let dates = try database.shareDates(in: year)
                totalShareCount = dates.count
                mostCommonShareDay = mostCommonDay(from: dates) ?? "-"
            } catch {
                print("Error loading share dates: \(error)")
                totalShareCount = 0
                mostCommonShareDay = "-"
            }
            
            // Build stories array
            buildStories()
            
            isLoading = false
        }
        
        // MARK: - Private Methods
        
        private func buildStories() {
            var storyPages: [StoryPage] = []
            
            // Always include welcome
            storyPages.append(.welcome)
            
            // Add top sounds (up to 3)
            let topSoundsToShow = min(topSounds.count, 3)
            if topSoundsToShow >= 1 {
                storyPages.append(.topSound1)
            }
            if topSoundsToShow >= 2 {
                storyPages.append(.topSound2)
            }
            if topSoundsToShow >= 3 {
                storyPages.append(.topSound3)
            }
            
            // Add stats if user has shared anything
            if totalShareCount > 0 {
                storyPages.append(.stats)
            }
            
            // Always include share at the end
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
            return "\(ranking.joined(separator: ", ")); \(totalShareCount) compart; \(mostCommonShareDay); \(authorInfo)"
        }
    }
}

