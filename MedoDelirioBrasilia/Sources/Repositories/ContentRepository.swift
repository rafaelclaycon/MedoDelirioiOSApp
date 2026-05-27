//
//  ContentRepository.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 14/04/25.
//

import Foundation

protocol ContentRepositoryProtocol {

    func allContent(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent]
    func favorites(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent]
    func songs(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent]

    /// Returns content by a given Author.
    func content(by authorId: String, _ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent]
    /// Returns content for a given UserFolder.
    func content(in folderId: String, _ allowSensitive: Bool, _ sortOrder: FolderSoundSortOption) throws -> [AnyEquatableMedoContent]
    /// Returns content with the given IDs. Includes both Sounds and Songs.
    func content(withIds contentIds: [String]) throws -> [AnyEquatableMedoContent]

    func sounds(matchingTitle title: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent]
    func sounds(matchingDescription description: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent]
    func sounds(fuzzyMatchingTitle title: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>]
    func sounds(fuzzyMatchingDescription description: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>]
    /// Returns a random Sound.
    func randomSound(_ allowSensitive: Bool) -> Sound?

    func favorites() throws -> [Favorite]
    func favoriteExists(_ contentId: String) throws -> Bool
    func insert(favorite: Favorite) throws
    func deleteFavorite(_ contentId: String) throws

    func songs(matchingTitle title: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent]
    func songs(matchingDescription description: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent]
    func songs(fuzzyMatchingTitle title: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>]
    func songs(fuzzyMatchingDescription description: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>]

    func author(withId authorId: String) throws -> Author?

    func clearCache()
}

final class ContentRepository: ContentRepositoryProtocol {

    private let database: LocalDatabaseProtocol

    private var allContent: [AnyEquatableMedoContent]?

    // MARK: - Initializer

    init(
        database: LocalDatabaseProtocol
    ) {
        self.database = database
        self.allContent = nil
    }

    // MARK: - Functions

    func allContent(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return sort(content: content, by: sortOrder)
    }

    func favorites(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        let favorites = try database.favorites().map { $0.contentId }
        var content = allContent.filter { favorites.contains($0.id) }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return sort(content: content, by: sortOrder)
    }

    func songs(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .song }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return sort(content: content, by: sortOrder)
    }

    func content(by authorId: String, _ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.authorId == authorId }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return sort(content: content, by: sortOrder)
    }

    func content(in folderId: String, _ allowSensitive: Bool, _ sortOrder: FolderSoundSortOption) throws -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        let folderContents = try database.contentsInside(userFolder: folderId)
        let contentIds = folderContents.map { $0.contentId }
        var content = allContent.filter { contentIds.contains($0.id) }

        for i in 0..<content.count {
            // DateAdded here is date added to folder not to the app as it means outside folders.
            content[i].dateAdded = folderContents.first(where: { $0.contentId == content[i].id })?.dateAdded
        }

        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return folderSort(content: content, by: sortOrder)
    }

    func content(withIds contentIds: [String]) throws -> [AnyEquatableMedoContent] {
        try database.content(withIds: contentIds)
    }

    func sounds(matchingTitle title: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .sound }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        content = content.filter {
            $0.title.normalizedForSearch().contains(title.normalizedForSearch())
        }
        return sort(content: content, by: .titleAscending)
    }

    func sounds(matchingDescription description: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .sound }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        let normalizedSearch = description.normalizedForSearch()
        content = content.filter {
            $0.description.normalizedForSearch().contains(normalizedSearch) &&
            !$0.title.normalizedForSearch().contains(normalizedSearch)
        }
        return sort(content: content, by: .titleAscending)
    }

    func sounds(fuzzyMatchingTitle title: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .sound }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return content
            .compactMap { item -> ScoredItem<AnyEquatableMedoContent>? in
                let score = FuzzyMatcher.score(query: title, against: item.title)
                guard score >= FuzzyMatcher.minimumScoreThreshold else { return nil }
                return ScoredItem(item: item, score: score)
            }
            .sorted { $0.score > $1.score }
    }

    func sounds(fuzzyMatchingDescription description: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .sound }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return content
            .compactMap { item -> ScoredItem<AnyEquatableMedoContent>? in
                let titleScore = FuzzyMatcher.score(query: description, against: item.title)
                guard titleScore < FuzzyMatcher.minimumScoreThreshold else { return nil }
                let descScore = FuzzyMatcher.score(query: description, against: item.description)
                guard descScore >= FuzzyMatcher.minimumScoreThreshold else { return nil }
                return ScoredItem(item: item, score: descScore)
            }
            .sorted { $0.score > $1.score }
    }

    func randomSound(_ allowSensitive: Bool) -> Sound? {
        do {
            return try LocalDatabase.shared.randomSound(includeOffensive: allowSensitive)
        } catch {
            return nil
        }
    }

    func favorites() throws -> [Favorite] {
        try database.favorites()
    }

    func favoriteExists(_ contentId: String) throws -> Bool {
        try database.isFavorite(contentId: contentId)
    }

    func insert(favorite: Favorite) throws {
        try database.insert(favorite: favorite)
    }

    func deleteFavorite(_ contentId: String) throws {
        try database.deleteFavorite(withId: contentId)
    }

    // MARK: - Song

    func songs(matchingTitle title: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .song }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        content = content.filter {
            $0.title.normalizedForSearch().contains(title.normalizedForSearch())
        }
        return sort(content: content, by: .titleAscending)
    }

    func songs(matchingDescription description: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .song }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        let normalizedSearch = description.normalizedForSearch()
        content = content.filter {
            $0.description.normalizedForSearch().contains(normalizedSearch) &&
            !$0.title.normalizedForSearch().contains(normalizedSearch)
        }
        return sort(content: content, by: .titleAscending)
    }

    func songs(fuzzyMatchingTitle title: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .song }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return content
            .compactMap { item -> ScoredItem<AnyEquatableMedoContent>? in
                let score = FuzzyMatcher.score(query: title, against: item.title)
                guard score >= FuzzyMatcher.minimumScoreThreshold else { return nil }
                return ScoredItem(item: item, score: score)
            }
            .sorted { $0.score > $1.score }
    }

    func songs(fuzzyMatchingDescription description: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        if allContent == nil {
            loadAllContent()
        }
        guard let allContent, allContent.count > 0 else { return [] }
        var content = allContent.filter { $0.type == .song }
        if !allowSensitive {
            content = content.filter { !$0.isOffensive }
        }
        return content
            .compactMap { item -> ScoredItem<AnyEquatableMedoContent>? in
                let titleScore = FuzzyMatcher.score(query: description, against: item.title)
                guard titleScore < FuzzyMatcher.minimumScoreThreshold else { return nil }
                let descScore = FuzzyMatcher.score(query: description, against: item.description)
                guard descScore >= FuzzyMatcher.minimumScoreThreshold else { return nil }
                return ScoredItem(item: item, score: descScore)
            }
            .sorted { $0.score > $1.score }
    }

    // MARK: - Author

    func author(withId authorId: String) throws -> Author? {
        try database.author(withId: authorId)
    }

    // MARK: - Maintenance

    func clearCache() {
        allContent = nil
    }
}

// MARK: - Internal Functions

extension ContentRepository {

    private func loadAllContent() {
        do {
            let sounds: [AnyEquatableMedoContent] = try database.sounds(
                allowSensitive: true
            ).map { AnyEquatableMedoContent($0) }
            let songs: [AnyEquatableMedoContent] = try database.songs(
                allowSensitive: true
            ).map { AnyEquatableMedoContent($0) }

            allContent = sounds + songs

            let cacheEntries = sounds
                .filter { !$0.isOffensive }
                .map { WidgetSoundCacheEntry(id: $0.id, title: $0.title, authorName: $0.subtitle, description: $0.description) }
            WidgetSoundCache.write(cacheEntries)
        } catch {
            debugPrint(error)
        }
    }

    private func sort(content: [AnyEquatableMedoContent], by sortOption: SoundSortOption) -> [AnyEquatableMedoContent] {
        switch sortOption {
        case .titleAscending:
            content.sorted(by: { $0.title.withoutDiacritics() < $1.title.withoutDiacritics() })
        case .authorNameAscending:
            content.sorted(by: { $0.subtitle.withoutDiacritics() < $1.subtitle.withoutDiacritics() })
        case .dateAddedDescending:
            content.sorted(by: { $0.dateAdded ?? Date() > $1.dateAdded ?? Date() })
        case .shortestFirst:
            content.sorted(by: { $0.duration < $1.duration })
        case .longestFirst:
            content.sorted(by: { $0.duration > $1.duration })
        case .longestTitleFirst:
            content.sorted(by: { $0.title.count > $1.title.count })
        case .shortestTitleFirst:
            content.sorted(by: { $0.title.count < $1.title.count })
        }
    }

    private func folderSort(content: [AnyEquatableMedoContent], by sortOption: FolderSoundSortOption) -> [AnyEquatableMedoContent] {
        switch sortOption {
        case .titleAscending:
            content.sorted(by: { $0.title.withoutDiacritics() < $1.title.withoutDiacritics() })
        case .authorNameAscending:
            content.sorted(by: { $0.subtitle.withoutDiacritics() < $1.subtitle.withoutDiacritics() })
        case .dateAddedDescending:
            content.sorted(by: { $0.dateAdded ?? Date() > $1.dateAdded ?? Date() })
        }
    }
}
