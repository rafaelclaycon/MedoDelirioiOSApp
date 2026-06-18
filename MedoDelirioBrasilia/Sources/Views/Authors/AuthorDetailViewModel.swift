//
//  AuthorsDetailViewViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 19/05/22.
//

import SwiftUI

@Observable
public class AuthorDetailViewModel {

    var state: LoadingState<[AnyEquatableMedoContent]> = .loading

    public let author: Author

    var soundSortOption: Int = 1
    var selectedSound: Sound? = nil
    var selectedSounds: [Sound]? = nil

    public var currentContentListMode: Binding<ContentGridMode>
    public var toast: Binding<Toast?>
    public var floatingOptions: Binding<FloatingContentOptions?>
    public var isLoadingEmail: Bool = false

    private let contentRepository: ContentRepositoryProtocol
    private let userSettings: UserSettingsProtocol

    // Alerts
    var alertTitle: String = ""
    var alertMessage: String = ""
    var showAlert: Bool = false
    var alertType: AuthorDetailAlertType = .ok

    // MARK: - Computed Properties

    var soundCount: Int {
        guard case .loaded(let content) = state else { return 0 }
        return content.count
    }

    var soundCountText: String {
        soundCount == 1 ? "1 SOM" : "\(soundCount) SONS"
    }

    // MARK: - Initializer

    init(
        author: Author,
        currentContentListMode: Binding<ContentGridMode>,
        toast: Binding<Toast?>,
        floatingOptions: Binding<FloatingContentOptions?>,
        contentRepository: ContentRepositoryProtocol,
        userSettings: UserSettingsProtocol = UserSettings()
    ) {
        self.author = author
        self.currentContentListMode = currentContentListMode
        self.toast = toast
        self.floatingOptions = floatingOptions
        self.contentRepository = contentRepository
        self.userSettings = userSettings
    }
}


// MARK: - User Actions

public extension AuthorDetailViewModel {

    func onViewLoaded() {
        loadContent()
    }

    func onSortOptionChanged() {
        loadContent()
    }

    func onAskForNewSoundSelected() {
        showAskForNewSoundAlert()
    }

    func onAskForNewSoundConfirmation() async {
        isLoadingEmail = true
        await Mailman.openDefaultEmailApp(
            subject: String(format: Shared.Email.AskForNewSound.subject, author.name),
            body: Shared.Email.AskForNewSound.body
        )
        isLoadingEmail = false
    }

    func onReportAuthorDetailIssueSelected() async {
        isLoadingEmail = true
        await Mailman.openDefaultEmailApp(
            subject: String(format: Shared.Email.AuthorDetailIssue.subject, author.name),
            body: Shared.Email.AuthorDetailIssue.body
        )
        isLoadingEmail = false
    }
}

// MARK: - Internal Functions

private extension AuthorDetailViewModel {

    func loadContent() {
        state = .loading
        do {
            let allowSensitive = userSettings.getShowExplicitContent()
            let sort = SoundSortOption(rawValue: soundSortOption) ?? .dateAddedDescending
            state = .loaded(try contentRepository.content(by: author.id, allowSensitive, sort))
        } catch {
            state = .error(error.localizedDescription)
            debugPrint(error)
        }
    }

    func showAskForNewSoundAlert() {
        HapticFeedback.warning()
        alertType = .askForNewSound
        alertTitle = Shared.AuthorDetail.AskForNewSoundAlert.title
        alertMessage = Shared.AuthorDetail.AskForNewSoundAlert.message
        showAlert = true
    }
}
