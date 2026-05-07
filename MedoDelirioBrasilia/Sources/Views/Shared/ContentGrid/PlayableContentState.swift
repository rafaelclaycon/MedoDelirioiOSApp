//
//  PlayableContentState.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 04/01/26.
//

import SwiftUI

/// Shared observable state for playback, favorites, and content interaction.
/// This class encapsulates logic that is common between ContentGrid and SearchResults.
@MainActor
@Observable
final class PlayableContentState {

    // MARK: - Observable State

    var nowPlayingKeeper = Set<String>()
    var favoritesKeeper = Set<String>()

    var selectedContent: AnyEquatableMedoContent? = nil
    var selectedContentMultiple: [AnyEquatableMedoContent]? = nil

    var authorToOpen: Author? = nil

    // Share as Video
    var shareAsVideoResult = ShareAsVideoResult(videoFilepath: "", contentId: "", exportMethod: .shareSheet)

    // Sharing
    var iPadShareSheet: ActivityViewController? = nil
    var isShowingShareSheet: Bool = false

    // Alerts
    var alertState: PlayableContentAlert? = nil
    var alertTitle: String = ""
    var alertMessage: String = ""

    // Sheets
    var activeSheet: PlayableContentSheet? = nil

    // MARK: - Dependencies

    private let contentRepository: ContentRepositoryProtocol
    private let contentFileManager: ContentFileManagerProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let currentScreen: ContentGridScreen

    public var toast: Binding<Toast?>

    // MARK: - Initializer

    init(
        contentRepository: ContentRepositoryProtocol,
        contentFileManager: ContentFileManagerProtocol,
        analyticsService: AnalyticsServiceProtocol,
        screen: ContentGridScreen,
        toast: Binding<Toast?>
    ) {
        self.contentRepository = contentRepository
        self.contentFileManager = contentFileManager
        self.analyticsService = analyticsService
        self.currentScreen = screen
        self.toast = toast

        loadFavorites()
    }
}

// MARK: - Public Actions

extension PlayableContentState {

    public func onViewAppeared() {
        loadFavorites()
    }

    public func play(
        _ content: AnyEquatableMedoContent,
        onPlaybackStopped: @escaping () -> Void = {}
    ) {
        do {
            let url = try content.fileURL()

            nowPlayingKeeper.removeAll()
            nowPlayingKeeper.insert(content.id)

            AudioPlayer.shared = AudioPlayer(
                url: url,
                update: { [weak self] state in
                    self?.onAudioPlayerUpdate(playerState: state, onPlaybackStopped: onPlaybackStopped)
                }
            )

            AudioPlayer.shared?.togglePlay()
        } catch {
            if content.isFromServer ?? false {
                showServerContentNotAvailableAlert(content)
            }
        }
    }

    public func stopPlayback() {
        if nowPlayingKeeper.count > 0 {
            AudioPlayer.shared?.togglePlay()
            nowPlayingKeeper.removeAll()
        }
    }

    public func toggleFavorite(_ contentId: String, refreshAction: (() -> Void)? = nil) {
        if favoritesKeeper.contains(contentId) {
            removeFromFavorites(contentId: contentId)
            refreshAction?()
        } else {
            addToFavorites(contentId: contentId)
        }
    }

    public func share(content: AnyEquatableMedoContent) {
        guard let contentType = ContentType.shareType(for: content.type) else {
            showUnableToGetContentAlert(content.title)
            return
        }

        if UIDevice.isiPhone {
            do {
                try SharingUtility.shareSound(
                    from: content.fileURL(),
                    andContentId: content.id,
                    context: contentType
                ) { didShare in
                    if didShare {
                        self.toast.wrappedValue = Toast(message: Shared.soundSharedSuccessfullyMessage, type: .success)
                    }
                }
            } catch {
                showUnableToGetContentAlert(content.title)
            }
        } else {
            do {
                let url = try content.fileURL()
                iPadShareSheet = ActivityViewController(activityItems: [url]) { activity, completed, items, error in
                    if completed {
                        self.isShowingShareSheet = false

                        guard let activity = activity else {
                            return
                        }
                        let destination = ShareDestination.translateFrom(activityTypeRawValue: activity.rawValue)
                        Logger.shared.logShared(contentType, contentId: content.id, destination: destination, destinationBundleId: activity.rawValue)

                        AppStoreReviewSteward.requestReviewBasedOnVersionAndCount()

                        self.toast.wrappedValue = Toast(message: Shared.soundSharedSuccessfullyMessage, type: .success)
                    }
                }
            } catch {
                showUnableToGetContentAlert(content.title)
            }

            isShowingShareSheet = true
        }
    }

    public func openShareAsVideoModal(for content: AnyEquatableMedoContent) {
        selectedContent = content
        activeSheet = .shareAsVideo(content)
    }

    public func addToFolder(_ content: AnyEquatableMedoContent) {
        selectedContentMultiple = [content]
        activeSheet = .addToFolder([content])
    }

    public func showDetails(for content: AnyEquatableMedoContent) {
        selectedContent = content
        activeSheet = .contentDetail(content)
    }

    public func showAuthor(withId authorId: String) {
        guard let author = try? contentRepository.author(withId: authorId) else {
            print("PlayableContentState error: unable to find author with id \(authorId)")
            return
        }
        authorToOpen = author
    }

    public func redownloadContent(withId contentId: String, ofType contentType: MediaType) {
        Task {
            do {
                if contentType == .sound {
                    try await contentFileManager.downloadSound(withId: contentId)
                } else {
                    try await contentFileManager.downloadSong(withId: contentId)
                }
                toast.wrappedValue = Toast(
                    message: "Conteúdo baixado com sucesso. Tente tocá-lo novamente.",
                    type: .success
                )
            } catch {
                showUnableToRedownloadContentAlert()
            }
        }
    }

    public func onRedownloadContentOptionSelected() {
        guard let content = selectedContent else { return }
        redownloadContent(withId: content.id, ofType: content.type)
    }

    public func onReportContentIssueSelected() async {
        await Mailman.openDefaultEmailApp(
            subject: Shared.issueSuggestionEmailSubject,
            body: Shared.issueSuggestionEmailBody
        )
    }

    public func onDidExitShareAsVideoSheet() {
        guard !shareAsVideoResult.videoFilepath.isEmpty else { return }

        if shareAsVideoResult.exportMethod == .saveAsVideo {
            showVideoSavedSuccessfullyToast()
        } else {
            shareVideo(
                withPath: shareAsVideoResult.videoFilepath,
                andContentId: shareAsVideoResult.contentId,
                title: selectedContent?.title ?? ""
            )
        }

        // Reset after processing to prevent reprocessing on subsequent sheet dismissals
        shareAsVideoResult = ShareAsVideoResult(videoFilepath: "", contentId: "", exportMethod: .shareSheet)
    }

    public func onAddedContentToFolderSuccessfully(
        folderName: String,
        pluralization: WordPluralization
    ) async {
        let selectedCount = selectedContentMultiple?.count ?? 1

        toast.wrappedValue = Toast(message: pluralization.getAddedToFolderToastText(folderName: folderName), type: .success)

        if pluralization == .plural {
            await analyticsService.send(
                originatingScreen: currentScreen.rawValue,
                action: "didAddManySoundsToFolder(\(selectedCount))"
            )
        }
    }

    public func typeForShareAsVideo() -> ContentType {
        guard let content = selectedContent else {
            return .videoFromSound
        }
        return content.type == .sound ? .videoFromSound : .videoFromSong
    }

    public func suggestOtherAuthorName(for content: AnyEquatableMedoContent) async {
        await Mailman.openDefaultEmailApp(
            subject: String(format: Shared.suggestOtherAuthorNameEmailSubject, content.title),
            body: String(format: Shared.suggestOtherAuthorNameEmailBody, content.subtitle, content.id)
        )
    }
}

// MARK: - Internal Functions

extension PlayableContentState {

    func loadFavorites() {
        do {
            let favorites = try contentRepository.favorites()
            favoritesKeeper.removeAll()
            favorites.forEach { favorite in
                self.favoritesKeeper.insert(favorite.contentId)
            }
        } catch {
            print("Falha ao carregar favoritos: \(error.localizedDescription)")
        }
    }

    private func addToFavorites(contentId: String) {
        let newFavorite = Favorite(contentId: contentId, dateAdded: Date())

        do {
            let favoriteAlreadyExists = try contentRepository.favoriteExists(contentId)
            guard favoriteAlreadyExists == false else { return }

            try contentRepository.insert(favorite: newFavorite)
            favoritesKeeper.insert(newFavorite.contentId)
        } catch {
            print("Issue saving Favorite '\(newFavorite.contentId)': \(error.localizedDescription)")
        }
    }

    private func removeFromFavorites(contentId: String) {
        do {
            try contentRepository.deleteFavorite(contentId)
            favoritesKeeper.remove(contentId)
        } catch {
            print("Issue removing Favorite '\(contentId)'.")
        }
    }

    private func onAudioPlayerUpdate(
        playerState: AudioPlayer.State?,
        onPlaybackStopped: @escaping () -> Void
    ) {
        guard playerState?.activity == .stopped else { return }
        nowPlayingKeeper.removeAll()
        onPlaybackStopped()
    }

    private func showVideoSavedSuccessfullyToast() {
        toast.wrappedValue = Toast(
            message: UIDevice.isMac ? Shared.ShareAsVideo.videoSavedSucessfullyMac : Shared.ShareAsVideo.videoSavedSucessfully,
            type: .success
        )
    }

    private func shareVideo(
        withPath filepath: String,
        andContentId contentId: String,
        title soundTitle: String
    ) {
        let videoType = ContentType.videoShareType(for: selectedContent?.type ?? .sound) ?? .videoFromSound

        if UIDevice.isiPhone {
            do {
                try SharingUtility.share(
                    videoType,
                    withPath: filepath,
                    andContentId: contentId,
                    shareSheetDelayInSeconds: 0.6
                ) { didShareSuccessfully in
                    if didShareSuccessfully {
                        self.toast.wrappedValue = Toast(message: Shared.videoSharedSuccessfullyMessage, type: .success)
                    }

                    WallE.deleteAllVideoFilesFromDocumentsDir()
                }
            } catch {
                showUnableToGetContentAlert(soundTitle)
            }
        } else {
            guard filepath.isEmpty == false else {
                return
            }

            let url = URL(fileURLWithPath: filepath)

            iPadShareSheet = ActivityViewController(activityItems: [url]) { activity, completed, items, error in
                if completed {
                    self.isShowingShareSheet = false

                    guard let activity = activity else {
                        return
                    }
                    let destination = ShareDestination.translateFrom(activityTypeRawValue: activity.rawValue)
                    Logger.shared.logShared(
                        videoType,
                        contentId: contentId,
                        destination: destination,
                        destinationBundleId: activity.rawValue
                    )

                    AppStoreReviewSteward.requestReviewBasedOnVersionAndCount()

                    self.toast.wrappedValue = Toast(message: Shared.videoSharedSuccessfullyMessage, type: .success)
                }

                WallE.deleteAllVideoFilesFromDocumentsDir()
            }

            isShowingShareSheet = true
        }
    }
}

// MARK: - Alerts

extension PlayableContentState {

    private func showUnableToGetContentAlert(_ contentTitle: String) {
        HapticFeedback.error()
        alertState = .issueSharingContent
        alertTitle = Shared.contentNotFoundAlertTitle(contentTitle)
        alertMessage = Shared.contentNotFoundAlertMessage
    }

    private func showServerContentNotAvailableAlert(_ content: AnyEquatableMedoContent) {
        selectedContent = content
        HapticFeedback.error()
        alertState = .contentFileNotFound
        alertTitle = Shared.contentNotFoundAlertTitle(content.title)
        alertMessage = Shared.serverContentNotAvailableRedownloadMessage
    }

    private func showUnableToRedownloadContentAlert() {
        alertState = .unableToRedownloadContent
        alertTitle = "Não Foi Possível Baixar o Conteúdo"
        alertMessage = "Tente novamente mais tarde."
    }
}

