//
//  AddToFolderViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI

@Observable
class AddToFolderViewModel {

    private let userFolderRepository: UserFolderRepositoryProtocol

    init(
        userFolderRepository: UserFolderRepositoryProtocol
    ) {
        self.userFolderRepository = userFolderRepository
    }

    var folders = [UserFolder]()
    var hasFoldersToDisplay: Bool = false

    var soundsThatCanBeAdded: [AnyEquatableMedoContent]? = nil

    var folderForSomeSoundsAlreadyInFolder: UserFolder? = nil

    // Alerts
    var alertTitle: String = ""
    var alertMessage: String = ""
    var alertType: AddToFolderAlertType = .ok
    var showAlert: Bool = false
}

// MARK: - User Actions

extension AddToFolderViewModel {

    public func onViewAppeared() async {
        loadFolderList(withFolders: try? await userFolderRepository.allFolders())
    }

    public func onExistingFolderSelected(
        folder: UserFolder,
        selectedContent: [AnyEquatableMedoContent]
    ) -> AddToFolderDetails? {
        do {
            soundsThatCanBeAdded = canBeAddedToFolder(content: selectedContent, folderId: folder.id)

            let soundsAlreadyInFolder = selectedContent.count - (soundsThatCanBeAdded?.count ?? 0)

            if selectedContent.count == soundsThatCanBeAdded?.count {
                try selectedContent.forEach { item in
                    try userFolderRepository.insert(contentId: item.id, intoUserFolder: folder.id)
                }
                try userFolderRepository.update(folder)

                return AddToFolderDetails(
                    hadSuccess: true,
                    folderName: "\(folder.symbol) \(folder.name)",
                    pluralization: selectedContent.count > 1 ? .plural : .singular
                )
            } else if soundsAlreadyInFolder == 1, selectedContent.count == 1 {
                showSingleSoundAlredyInFolderAlert(folderName: folder.name)
            } else if soundsAlreadyInFolder == selectedContent.count {
                showAllSoundsAlredyInFolderAlert(folderName: folder.name)
            } else {
                folderForSomeSoundsAlreadyInFolder = folder
                showSomeSoundsAlreadyInFolderAlert(soundCountAlreadyInFolder: soundsAlreadyInFolder, folderName: folder.name)
            }
        } catch {
            showIssueSavingAlert(error.localizedDescription)
        }
        return nil
    }

    public func onAddOnlyNonExistingSelected() -> AddToFolderDetails? {
        do {
            try soundsThatCanBeAdded?.forEach { sound in
                try userFolderRepository.insert(contentId: sound.id, intoUserFolder: folderForSomeSoundsAlreadyInFolder?.id ?? "")
            }

            var folderName = ""
            if let folder = folderForSomeSoundsAlreadyInFolder {
                try userFolderRepository.update(folder)
                folderName = "\(folder.symbol) \(folder.name)"
            }

            return AddToFolderDetails(
                hadSuccess: true,
                folderName: folderName,
                pluralization: soundsThatCanBeAdded?.count ?? 0 > 1 ? .plural : .singular
            )
        } catch {
            showIssueSavingAlert(error.localizedDescription)
        }
        return nil
    }

    public func onNewFolderCreationSheetDismissed() async {
        loadFolderList(withFolders: try? await userFolderRepository.allFolders())
    }
}

// MARK: - Internal Functions

extension AddToFolderViewModel {

    private func loadFolderList(withFolders outsideFolders: [UserFolder]?) {
        guard let actualFolders = outsideFolders, actualFolders.count > 0 else {
            return
        }
        self.folders = actualFolders
        self.hasFoldersToDisplay = true
    }

    private func canBeAddedToFolder(content: [AnyEquatableMedoContent], folderId: String) -> [AnyEquatableMedoContent] {
        var allowedList = [AnyEquatableMedoContent]()
        content.forEach { item in
            if soundIsNotYetOnFolder(folderId: folderId, contentId: item.id) {
                allowedList.append(item)
            }
        }
        return allowedList
    }

    private func soundIsNotYetOnFolder(folderId: String, contentId: String) -> Bool {
        var contentExistsInsideUserFolder = true
        do {
            contentExistsInsideUserFolder = try self.userFolderRepository.contentExistsInsideUserFolder(withId: folderId, contentId: contentId)
        } catch {
            return true
        }
        return contentExistsInsideUserFolder == false
    }

    // MARK: - Alerts

    private func showSingleSoundAlredyInFolderAlert(folderName: String) {
        alertTitle = "Já Adicionado"
        alertMessage = "Esse conteúdo já está na pasta \"\(folderName)\"."
        alertType = .ok
        showAlert = true
    }

    private func showSomeSoundsAlreadyInFolderAlert(soundCountAlreadyInFolder: Int, folderName: String) {
        if soundCountAlreadyInFolder == 1 {
            alertTitle = "1 Conteúdo Já Adicionado"
        } else {
            alertTitle = "\(soundCountAlreadyInFolder) Conteúdos Já Adicionados"
        }
        alertMessage = "Deseja adicionar o restante à pasta \"\(folderName)\"?"
        alertType = .addOnlyNonOverlapping
        showAlert = true
    }

    private func showAllSoundsAlredyInFolderAlert(folderName: String) {
        alertTitle = "Já Adicionados"
        alertMessage = "Todos os conteúdos selecionados já estão na pasta \"\(folderName)\"."
        alertType = .ok
        showAlert = true
    }

    private func showIssueSavingAlert(_ message: String) {
        alertTitle = "Erro Adicionando Conteúdos à Pasta"
        alertMessage = message
        alertType = .ok
        showAlert = true
    }
}
