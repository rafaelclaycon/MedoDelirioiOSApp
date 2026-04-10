//
//  FakeUserFolderRepository.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 16/04/25.
//

import Foundation

final class FakeUserFolderRepository: UserFolderRepositoryProtocol {

    var didCallAllFolders: Bool = false
    var didCallAdd: Bool = false
    var didCallInsert: Bool = false
    var didCallContentExistsInside: Bool = false
    var didCallUpdate: Bool = false
    var didCallDeleteUserContent: Bool = false
    var didCallAddHashToExistingFolder: Bool = false

    var contents: [String] = []

    func allFolders() throws -> [UserFolder] {
        didCallAllFolders = true
        return []
    }

    func folders(matchingName name: String) -> [UserFolder]? {
        nil
    }

    func folders(fuzzyMatchingName name: String) -> [ScoredItem<UserFolder>]? {
        nil
    }

    func add(_ userFolder: UserFolder) throws {
        didCallAdd = true
    }

    func insert(contentId: String, intoUserFolder userFolderId: String) throws {
        didCallInsert = true
        contents.append(contentId)
    }

    func contentExistsInsideUserFolder(withId folderId: String, contentId: String) throws -> Bool {
        didCallContentExistsInside = true
        return contents.contains(contentId)
    }

    func update(_ userFolder: UserFolder) throws {
        didCallUpdate = true
    }

    func deleteUserContentFromFolder(withId folderId: String, contentId: String) throws {
        didCallDeleteUserContent = true
    }

    func addHashToExistingFolders() throws {
        didCallAddHashToExistingFolder = true
    }

    func delete(_ folderId: String) throws {
        //
    }
}
