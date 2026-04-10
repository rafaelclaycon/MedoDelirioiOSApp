//
//  UserFolderRepository.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/11/24.
//

import Foundation

protocol UserFolderRepositoryProtocol {

    func allFolders() async throws -> [UserFolder]
    func folders(matchingName name: String) -> [UserFolder]?
    func folders(fuzzyMatchingName name: String) -> [ScoredItem<UserFolder>]?

    func add(_ userFolder: UserFolder) throws
    func insert(contentId: String, intoUserFolder userFolderId: String) throws
    func contentExistsInsideUserFolder(withId folderId: String, contentId: String) throws -> Bool

    func update(_ userFolder: UserFolder) throws

    func delete(_ folderId: String) throws
    func deleteUserContentFromFolder(withId folderId: String, contentId: String) throws

    /// Should only be used once.
    func addHashToExistingFolders() throws
}

final class UserFolderRepository: UserFolderRepositoryProtocol {

    private let database: LocalDatabaseProtocol

    private var allFolders: [UserFolder]?

    // MARK: - Initializer

    init(
        database: LocalDatabaseProtocol
    ) {
        self.database = database
        self.allFolders = []
        loadAllFolders()
    }

    func allFolders() async throws -> [UserFolder] {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                continuation.resume(returning: try database.allFolders())
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func folders(matchingName name: String) -> [UserFolder]? {
        guard let allFolders else { return nil }
        let normalizedSearch = name.normalizedForSearch()
        return allFolders.filter { folder in
            folder.name.normalizedForSearch().contains(normalizedSearch)
        }
    }

    func folders(fuzzyMatchingName name: String) -> [ScoredItem<UserFolder>]? {
        guard let allFolders else { return nil }
        let scored = allFolders
            .compactMap { folder -> ScoredItem<UserFolder>? in
                let score = FuzzyMatcher.score(query: name, against: folder.name)
                guard score >= FuzzyMatcher.minimumScoreThreshold else { return nil }
                return ScoredItem(item: folder, score: score)
            }
            .sorted { $0.score > $1.score }
        return scored.isEmpty ? nil : scored
    }

    func add(_ userFolder: UserFolder) throws {
        var newFolder = userFolder
        newFolder.changeHash = FolderResearchProvider.hash(userFolder.folderHash([]))
        try database.insert(newFolder)
        loadAllFolders()
    }

    func insert(contentId: String, intoUserFolder userFolderId: String) throws {
        try database.insert(contentId: contentId, intoUserFolder: userFolderId)
    }

    func contentExistsInsideUserFolder(withId folderId: String, contentId: String) throws -> Bool {
        try database.contentExistsInsideUserFolder(withId: folderId, contentId: contentId)
    }

    func update(_ userFolder: UserFolder) throws {
        var folder = userFolder
        let contents = try database.contentsInside(userFolder: folder.id)
        folder.changeHash = folder.folderHash(contents.map { $0.contentId })
        try database.update(folder)
        loadAllFolders()
    }

    func delete(_ folderId: String) throws {
        try database.deleteUserFolder(withId: folderId)
        loadAllFolders()
    }

    func deleteUserContentFromFolder(withId folderId: String, contentId: String) throws {
        try database.deleteUserContentFromFolder(withId: folderId, contentId: contentId)
    }

    func addHashToExistingFolders() throws {
        let folders = try database.allFolders()
        try folders.forEach { try update($0) }
    }
}

// MARK: - Internal Functions

extension UserFolderRepository {

    private func loadAllFolders() {
        do {
            allFolders = try database.allFolders()
        } catch {
            debugPrint(error)
        }
    }
}
