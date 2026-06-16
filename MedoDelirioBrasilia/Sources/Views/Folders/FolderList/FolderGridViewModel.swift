//
//  FolderGridViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI

@Observable
class FolderGridViewModel {

    var state: LoadingState<[UserFolder]> = .loading

    var displayJoinFolderResearchBanner: Bool = false

    var currentActivity: NSUserActivity? = nil

    private let userFolderRepository: UserFolderRepositoryProtocol
    private let userSettings: UserSettingsProtocol
    private let appMemory: AppPersistentMemoryProtocol

    init(
        userFolderRepository: UserFolderRepositoryProtocol,
        userSettings: UserSettingsProtocol,
        appMemory: AppPersistentMemoryProtocol
    ) {
        self.userFolderRepository = userFolderRepository
        self.userSettings = userSettings
        self.appMemory = appMemory
    }
}

// MARK: - User Actions

extension FolderGridViewModel {

    public func onViewAppeared() async {
        await loadContent()
        showFolderResearchBanner()
        donateActivity()
    }

    public func onReloadRequested() async {
        await loadContent()
    }
}

// MARK: - Internal Functions

extension FolderGridViewModel {

    private func loadContent() async {
        state = .loading
        do {
            state = .loaded(try await userFolderRepository.allFolders())
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func showFolderResearchBanner() {
        if userSettings.getHasJoinedFolderResearch() {
            displayJoinFolderResearchBanner = false
        } else if let hasDismissed = appMemory.getHasDismissedJoinFolderResearchBanner() {
            if hasDismissed {
                displayJoinFolderResearchBanner = false
            } else {
                displayJoinFolderResearchBanner = !appMemory.getHasSentFolderResearchInfo()
            }
            displayJoinFolderResearchBanner = !hasDismissed
        } else {
            displayJoinFolderResearchBanner = true
        }
    }

    private func donateActivity() {
        currentActivity = UserActivityWaiter.getDonatableActivity(
            withType: Shared.ActivityTypes.viewCollections,
            andTitle: "Ver e criar pastas de sons",
            persistentIdentifier: Shared.ActivityTypes.viewCollections
        )
        currentActivity?.becomeCurrent()
    }
}
