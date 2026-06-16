//
//  AuthorsGrid+ViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/05/22.
//

import SwiftUI

extension AuthorsGrid {

    @Observable final class ViewModel {

        var state: LoadingState<[Author]> = .loading

        var sortOption: Int
        var columns: [GridItem] = []

        var currentActivity: NSUserActivity? = nil

        private let authorService: AuthorServiceProtocol
        private let userSettings: UserSettingsProtocol

        // MARK: - Initializer

        init(
            authorService: AuthorServiceProtocol,
            userSettings: UserSettingsProtocol,
            sortOption: Int
        ) {
            self.authorService = authorService
            self.userSettings = userSettings
            self.sortOption = sortOption
        }
    }
}

// MARK: - User Actions

extension AuthorsGrid.ViewModel {

    public func onViewAppeared(viewWidth: CGFloat) {
        loadContent()

        updateColumns(newWidth: viewWidth)

        donateActivity()
    }

    public func onContainerWidthChanged(newWidth: CGFloat) {
        updateColumns(newWidth: newWidth)
    }

    public func onAuthorSortingChanged() {
        loadContent()
        userSettings.authorSortOption(sortOption)
    }

    public func onAuthorSortingChangedExternally(_ newSortOption: Int) {
        sortOption = newSortOption
    }
}

// MARK: - Private Functions

extension AuthorsGrid.ViewModel {

    func loadContent() {
        state = .loading

        do {
            let sort = AuthorSortOption(rawValue: sortOption) ?? AuthorSortOption.nameAscending
            state = .loaded(try authorService.allAuthors(sort))
        } catch {
            state = .error(error.localizedDescription)
            debugPrint(error)
        }
    }

    private func updateColumns(newWidth: CGFloat) {
        columns = GridHelper.authorColumns(
            gridWidth: newWidth,
            spacing: UIDevice.deviceType == .iPhone ? .spacing(.small) : .spacing(.large)
        )
    }

    func donateActivity() {
        currentActivity = UserActivityWaiter.getDonatableActivity(
            withType: Shared.ActivityTypes.viewAuthors,
            andTitle: "Ver autores",
            persistentIdentifier: Shared.ActivityTypes.viewAuthors
        )
        currentActivity?.becomeCurrent()
    }
}
