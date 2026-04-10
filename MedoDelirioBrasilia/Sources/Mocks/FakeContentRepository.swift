//
//  FakeContentRepository.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/04/25.
//

import Foundation

final class FakeContentRepository: ContentRepositoryProtocol {

    var content: [AnyEquatableMedoContent] = []
    var fakeFavorites: [Favorite] = []
    private var insertedFavorites: [Favorite] = []
    private var deletedFavoriteIds: Set<String> = []

    func allContent(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        content
    }
    
    func favorites(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        []
    }
    
    func songs(_ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        []
    }
    
    func content(by authorId: String, _ allowSensitive: Bool, _ sortOrder: SoundSortOption) throws -> [AnyEquatableMedoContent] {
        []
    }
    
    func content(in folderId: String, _ allowSensitive: Bool, _ sortOrder: FolderSoundSortOption) throws -> [AnyEquatableMedoContent] {
        content
    }

    func content(withIds contentIds: [String]) throws -> [AnyEquatableMedoContent] {
        []
    }

    func sounds(matchingTitle title: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        []
    }

    func sounds(matchingDescription description: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        []
    }

    func sounds(fuzzyMatchingTitle title: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        []
    }

    func sounds(fuzzyMatchingDescription description: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        []
    }

    func randomSound(_ allowSensitive: Bool) -> Sound? {
        nil
    }

    // Favorite

    func favorites() throws -> [Favorite] {
        let existingIds = Set(fakeFavorites.map { $0.contentId })
        let all = fakeFavorites + insertedFavorites.filter { !existingIds.contains($0.contentId) }
        return all.filter { !deletedFavoriteIds.contains($0.contentId) }
    }

    func favoriteExists(_ contentId: String) throws -> Bool {
        let allFavorites = try favorites()
        return allFavorites.contains { $0.contentId == contentId }
    }

    func insert(favorite: Favorite) throws {
        insertedFavorites.append(favorite)
    }

    func deleteFavorite(_ contentId: String) throws {
        deletedFavoriteIds.insert(contentId)
    }

    // Song

    func songs(matchingTitle title: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        []
    }

    func songs(matchingDescription description: String, _ allowSensitive: Bool) -> [AnyEquatableMedoContent] {
        []
    }

    func songs(fuzzyMatchingTitle title: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        []
    }

    func songs(fuzzyMatchingDescription description: String, _ allowSensitive: Bool) -> [ScoredItem<AnyEquatableMedoContent>] {
        []
    }

    // Author

    func author(withId authorId: String) throws -> Author? {
        nil
    }

    func clearCache() {
        //
    }
}
