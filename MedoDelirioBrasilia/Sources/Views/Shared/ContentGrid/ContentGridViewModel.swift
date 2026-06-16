//
//  ContentGridViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

@MainActor
@Observable
final class ContentGridViewModel {

    // MARK: - Composed Playable State

    let playable: PlayableContentState

    // MARK: - Grid-Specific State

    var menuOptions: [ContextMenuSection]
    var refreshAction: (() -> Void)?
    /// Called when a piece of content starts playing. Used by screens that only care about
    /// genuine engagement (e.g. donating a Siri Suggestion for a reaction once a sound is played).
    var onContentPlayed: (() -> Void)?
    var folder: UserFolder?

    var highlightKeeper = Set<String>()
    var selectionKeeper = Set<String>()

    // Long Updates
    var processedUpdateNumber: Int = 0
    var totalUpdateCount: Int = 0

    // Playlist
    var isPlayingPlaylist: Bool = false
    private var currentTrackIndex: Int = 0

    // Grid Alerts (folder-related)
    var alertTitle: String = ""
    var alertMessage: String = ""
    var showAlert: Bool = false
    var alertType: ContentGridAlert = .removeSingleContent

    // Play Random Sound
    var scrollTo: String = ""

    // Multi-select
    var tabBarVisibility: Visibility = .visible

    // MARK: - Stored Properties

    public var currentListMode: Binding<ContentGridMode>
    public var toast: Binding<Toast?>
    public var floatingOptions: Binding<FloatingContentOptions?>
    private let multiSelectFolderOperation: FolderOperation
    private let contentRepository: ContentRepositoryProtocol
    private let userFolderRepository: UserFolderRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let currentScreen: ContentGridScreen

    // MARK: - Computed Properties (Delegated to Playable)

    var favoritesKeeper: Set<String> {
        get { playable.favoritesKeeper }
        set { playable.favoritesKeeper = newValue }
    }

    var nowPlayingKeeper: Set<String> {
        get { playable.nowPlayingKeeper }
        set { playable.nowPlayingKeeper = newValue }
    }

    var selectedContentSingle: AnyEquatableMedoContent? {
        get { playable.selectedContent }
        set { playable.selectedContent = newValue }
    }

    var selectedContentMultiple: [AnyEquatableMedoContent]? {
        get { playable.selectedContentMultiple }
        set { playable.selectedContentMultiple = newValue }
    }

    var authorToOpen: Author? {
        get { playable.authorToOpen }
        set { playable.authorToOpen = newValue }
    }

    var shareAsVideoResult: ShareAsVideoResult {
        get { playable.shareAsVideoResult }
        set { playable.shareAsVideoResult = newValue }
    }

    var iPadShareSheet: ActivityViewController? {
        get { playable.iPadShareSheet }
        set { playable.iPadShareSheet = newValue }
    }

    var isShowingShareSheet: Bool {
        get { playable.isShowingShareSheet }
        set { playable.isShowingShareSheet = newValue }
    }

    var activeSheet: PlayableContentSheet? {
        get { playable.activeSheet }
        set { playable.activeSheet = newValue }
    }

    // MARK: - Initializer

    init(
        contentRepository: ContentRepositoryProtocol,
        userFolderRepository: UserFolderRepositoryProtocol,
        contentFileManager: ContentFileManagerProtocol,
        screen: ContentGridScreen,
        menuOptions: [ContextMenuSection],
        currentListMode: Binding<ContentGridMode>,
        toast: Binding<Toast?>,
        floatingOptions: Binding<FloatingContentOptions?>,
        refreshAction: (() -> Void)? = nil,
        onContentPlayed: (() -> Void)? = nil,
        insideFolder: UserFolder? = nil,
        multiSelectFolderOperation: FolderOperation = .add,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.contentRepository = contentRepository
        self.userFolderRepository = userFolderRepository
        self.analyticsService = analyticsService
        self.currentScreen = screen
        self.menuOptions = menuOptions
        self.currentListMode = currentListMode
        self.toast = toast
        self.floatingOptions = floatingOptions
        self.refreshAction = refreshAction
        self.onContentPlayed = onContentPlayed
        self.folder = insideFolder
        self.multiSelectFolderOperation = multiSelectFolderOperation

        // Initialize composed PlayableContentState
        self.playable = PlayableContentState(
            contentRepository: contentRepository,
            contentFileManager: contentFileManager,
            analyticsService: analyticsService,
            screen: screen,
            toast: toast
        )
    }
}

// MARK: - User Actions

extension ContentGridViewModel {

    public func onViewAppeared() {
        playable.onViewAppeared()
    }

    public func onContentSelected(
        _ content: AnyEquatableMedoContent,
        loadedContent: [AnyEquatableMedoContent]
    ) {
        if currentListMode.wrappedValue == .regular {
            if nowPlayingKeeper.contains(content.id) {
                AudioPlayer.shared?.togglePlay()
                nowPlayingKeeper.removeAll()
                doPlaylistCleanup() // Needed because user tap a playing sound to stop playing a playlist.
            } else {
                doPlaylistCleanup() // Needed because user can be playing a playlist and decide to tap another sound.
                play(content, loadedContent: loadedContent)
            }
        } else {
            if selectionKeeper.contains(content.id) {
                selectionKeeper.remove(content.id)
            } else {
                selectionKeeper.insert(content.id)
            }
        }
    }

    public func onAddedContentToFolderSuccessfully(
        folderName: String,
        pluralization: WordPluralization
    ) async {
        // Need to get count before clearing the Set.
        let selectedCount: Int = selectionKeeper.count

        if currentListMode.wrappedValue == .selection {
            stopSelecting()
        }

        toast.wrappedValue = Toast(message: pluralization.getAddedToFolderToastText(folderName: folderName), type: .success)

        if pluralization == .plural {
            await analyticsService.send(
                originatingScreen: currentScreen.rawValue,
                action: "didAddManySoundsToFolder(\(selectedCount))"
            )
        }
    }

    public func onViewDisappeared() {
        if isPlayingPlaylist {
            stopPlaying()
        }
    }

    public func onPlayStopPlaylistSelected(loadedContent: [AnyEquatableMedoContent]) {
        playStopPlaylist(loadedContent: loadedContent)
    }

    public func onContentSortingChanged() {
        stopPlaying()
    }

    public func onEnterMultiSelectModeSelected(
        loadedContent: [AnyEquatableMedoContent],
        isFavoritesOnlyView: Bool
    ) {
        startSelecting(loadedContent: loadedContent, isFavoritesOnlyView: isFavoritesOnlyView)
    }

    public func onExitMultiSelectModeSelected() {
        stopSelecting()
    }

    public func onShareManySelected(loadedContent: [AnyEquatableMedoContent]) async {
        await shareSelected(loadedContent: loadedContent)
    }

    public func onAddRemoveManyFromFavoritesSelected(isFavoritesOnlyView: Bool) async {
        await addRemoveManyFromFavorites(isFavoritesOnlyView: isFavoritesOnlyView)
    }

    public func onAddRemoveManyFromFolderSelected(
        _ operation: FolderOperation,
        loadedContent: [AnyEquatableMedoContent]
    ) {
        if operation == .add {
            addManyToFolder(loadedContent: loadedContent)
        } else {
            showRemoveMultipleSoundsConfirmation()
        }
    }

    public func onDidExitShareAsVideoSheet() {
        playable.onDidExitShareAsVideoSheet()
    }

    public func onRedownloadContentOptionSelected() {
        playable.onRedownloadContentOptionSelected()
    }

    public func onReportContentIssueSelected() async {
        await playable.onReportContentIssueSelected()
    }

    public func onRemoveSingleContentSelected() {
        removeSingleContentFromFolder()
    }

    public func onRemoveMultipleContentSelected() async {
        await removeManyFromFolder()
    }

    public func onItemSelectionChanged() {
        guard currentListMode.wrappedValue == .selection else { return }
        floatingOptions.wrappedValue?.areButtonsEnabled = selectionKeeper.count > 0
        floatingOptions.wrappedValue?.allSelectedAreFavorites = allSelectedAreFavorites()
    }
}

// MARK: - Internal Functions

extension ContentGridViewModel {

    private func showVideoSavedSuccessfullyToast() {
        toast.wrappedValue = Toast(
            message: UIDevice.deviceType == .mac ? Shared.ShareAsVideo.videoSavedSucessfullyMac : Shared.ShareAsVideo.videoSavedSucessfully,
            type: .success
        )
    }

    public func typeForShareAsVideo() -> ContentType {
        playable.typeForShareAsVideo()
    }
}

// MARK: - Sound Playback

extension ContentGridViewModel {

    private func playStopPlaylist(loadedContent: [AnyEquatableMedoContent]) {
        if floatingOptions.wrappedValue != nil {
            stopSelecting()
        }
        if isPlayingPlaylist {
            stopPlaying()
        } else {
            playAllOneAfterTheOther(loadedContent: loadedContent)
        }
    }

    private func play(
        _ content: AnyEquatableMedoContent,
        scrollToPlaying: Bool = false,
        loadedContent: [AnyEquatableMedoContent]
    ) {
        if scrollToPlaying {
            scrollTo = content.id
        }

        onContentPlayed?()

        playable.play(content) { [weak self] in
            self?.onPlaybackStopped(scrollToPlaying: scrollToPlaying, loadedContent: loadedContent)
        }
    }

    private func onPlaybackStopped(
        scrollToPlaying: Bool,
        loadedContent: [AnyEquatableMedoContent]
    ) {
        guard !loadedContent.isEmpty else { return }
        guard isPlayingPlaylist else { return }

        currentTrackIndex += 1
        if currentTrackIndex >= loadedContent.count {
            doPlaylistCleanup()
            return
        }

        play(loadedContent[currentTrackIndex], scrollToPlaying: scrollToPlaying, loadedContent: loadedContent)
    }

    private func stopPlaying() {
        if nowPlayingKeeper.count > 0 {
            playable.stopPlayback()
            doPlaylistCleanup()
        }
    }

    private func playAllOneAfterTheOther(loadedContent: [AnyEquatableMedoContent]) {
        guard let first = loadedContent.first else { return }
        isPlayingPlaylist = true
        play(first, scrollToPlaying: true, loadedContent: loadedContent)
    }

    private func doPlaylistCleanup() {
        currentTrackIndex = 0
        isPlayingPlaylist = false
    }

    public func scrollAndPlay(
        contentId: String,
        loadedContent: [AnyEquatableMedoContent]
    ) {
        guard let content = loadedContent.first(where: { $0.id == contentId }) else { return }
        scrollTo = content.id
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
            self.play(content, loadedContent: loadedContent)
        }
    }
}

// MARK: - ContextMenuOption Communication

extension ContentGridViewModel: ContentGridDisplaying {

    func share(content: AnyEquatableMedoContent) {
        playable.share(content: content)
    }

    func openShareAsVideoModal(for content: AnyEquatableMedoContent) {
        playable.openShareAsVideoModal(for: content)
    }

    func toggleFavorite(_ contentId: String, isFavoritesOnlyView: Bool) {
        if isFavoritesOnlyView {
            playable.toggleFavorite(contentId, refreshAction: refreshAction)
        } else {
            playable.toggleFavorite(contentId)
        }
    }

    func addToFolder(_ content: AnyEquatableMedoContent) {
        selectedContentMultiple = [content]
        playable.addToFolder(content)
    }

    func playFrom(
        content: AnyEquatableMedoContent,
        loadedContent: [AnyEquatableMedoContent]
    ) {
        guard let index = loadedContent.firstIndex(where: { $0.id == content.id }) else { return }
        let soundInArray = loadedContent[index]
        currentTrackIndex = index
        isPlayingPlaylist = true
        play(soundInArray, scrollToPlaying: true, loadedContent: loadedContent)
    }

    func removeFromFolder(_ content: AnyEquatableMedoContent) {
        selectedContentSingle = content
        showSoundRemovalConfirmation(soundTitle: content.title)
    }

    func showDetails(for content: AnyEquatableMedoContent) {
        playable.showDetails(for: content)
    }

    func showAuthor(withId authorId: String) {
        playable.showAuthor(withId: authorId)
    }

    func suggestOtherAuthorName(for content: AnyEquatableMedoContent) async {
        await playable.suggestOtherAuthorName(for: content)
    }
}

// MARK: - Multi-Selection

extension ContentGridViewModel {

    private func startSelecting(
        loadedContent: [AnyEquatableMedoContent],
        isFavoritesOnlyView: Bool
    ) {
        stopPlaying()

        if #available(iOS 26, *) {
            if currentListMode.wrappedValue == .regular {
                tabBarVisibility = .hidden
            } else {
                tabBarVisibility = .visible
            }
        }

        if currentListMode.wrappedValue == .regular {
            currentListMode.wrappedValue = .selection
            floatingOptions.wrappedValue = FloatingContentOptions(
                areButtonsEnabled: false,
                allSelectedAreFavorites: false,
                folderOperation: multiSelectFolderOperation,
                shareIsProcessing: false,
                favoriteAction: { Task { await self.addRemoveManyFromFavorites(isFavoritesOnlyView: isFavoritesOnlyView) } },
                folderAction: {
                    if self.multiSelectFolderOperation == .add {
                        self.addManyToFolder(loadedContent: loadedContent)
                    } else {
                        self.showRemoveMultipleSoundsConfirmation()
                    }
                },
                shareAction: {
                    Task {
                        await self.shareSelected(loadedContent: loadedContent)
                    }
                }
            )
        } else {
            currentListMode.wrappedValue = .regular
            selectionKeeper.removeAll()
            floatingOptions.wrappedValue = nil
        }
    }

    private func stopSelecting() {
        currentListMode.wrappedValue = .regular
        selectionKeeper.removeAll()
        selectedContentMultiple = nil
        floatingOptions.wrappedValue = nil
        if #available(iOS 26, *) {
            tabBarVisibility = .visible
        }
    }

    public func allSelectedAreFavorites() -> Bool {
        guard selectionKeeper.count > 0 else { return false }
        return selectionKeeper.isSubset(of: favoritesKeeper)
    }

    private func addRemoveManyFromFavorites(isFavoritesOnlyView: Bool) async {
        // Need to get count before clearing the Set.
        let selectedCount: Int = selectionKeeper.count

        if isFavoritesOnlyView || allSelectedAreFavorites() {
            removeSelectedFromFavorites()
            stopSelecting()
            if let refreshAction {
                refreshAction()
            }
            await analyticsService.send(
                originatingScreen: currentScreen.rawValue,
                action: "didRemoveManySoundsFromFavorites(\(selectedCount))"
            )
        } else {
            addSelectedToFavorites()
            stopSelecting()
            await analyticsService.send(
                originatingScreen: currentScreen.rawValue,
                action: "didAddManySoundsToFavorites(\(selectedCount))"
            )
        }
    }

    private func addSelectedToFavorites() {
        guard selectionKeeper.count > 0 else { return }
        selectionKeeper.forEach { selectedSound in
            playable.toggleFavorite(selectedSound)
        }
    }

    private func removeSelectedFromFavorites() {
        guard selectionKeeper.count > 0 else { return }
        selectionKeeper.forEach { selectedSound in
            playable.toggleFavorite(selectedSound)
        }
    }

    private func addManyToFolder(loadedContent: [AnyEquatableMedoContent]) {
        guard selectionKeeper.count > 0 else { return }
        let selected = loadedContent.filter { selectionKeeper.contains($0.id) }
        selectedContentMultiple = selected
        activeSheet = .addToFolder(selected)
    }

    private func removeManyFromFolder() async {
        guard let folder else { return }
        guard let refreshAction else { return }
        guard selectionKeeper.count > 0 else { return }

        // Need to get count before clearing the Set.
        let selectedCount: Int = selectionKeeper.count // For Analytics

        do {
            try selectionKeeper.forEach { selectedSoundId in
                try userFolderRepository.deleteUserContentFromFolder(withId: folder.id, contentId: selectedSoundId)
            }

            // Need to update folder hash so SyncManager knows about the change on next sync.
            try userFolderRepository.update(folder)

            selectionKeeper.removeAll()
            floatingOptions.wrappedValue = nil
            refreshAction()

            stopSelecting()
            await analyticsService.send(
                currentScreen: currentScreen.rawValue,
                folderName: "\(folder.symbol) \(folder.name)",
                action: "didRemoveManySoundsFromFolder(\(selectedCount))"
            )
        } catch {
            showIssueRemovingContentFromFolderAlert(plural: true)
        }
    }

    private func shareSelected(loadedContent: [AnyEquatableMedoContent]) async {
        guard selectionKeeper.count > 0 else { return }

        floatingOptions.wrappedValue?.shareIsProcessing = true

        selectedContentMultiple = loadedContent.filter({ selectionKeeper.contains($0.id) })
        guard selectedContentMultiple?.count ?? 0 > 0 else { return }

        let successfulMessage = selectedContentMultiple!.count > 1 ? Shared.soundsExportedSuccessfullyMessage : Shared.soundExportedSuccessfullyMessage

        do {
            let hadSuccessSharing = try await SharingUtility.share(content: selectedContentMultiple!)
            floatingOptions.wrappedValue?.shareIsProcessing = false
            stopSelecting()
            if hadSuccessSharing {
                toast.wrappedValue = Toast(message: successfulMessage, type: .success)
            }
        } catch SoundError.fileNotFound(let soundTitle) {
            floatingOptions.wrappedValue?.shareIsProcessing = false
            stopSelecting()
            showUnableToGetSoundAlert(soundTitle)
        } catch {
            floatingOptions.wrappedValue?.shareIsProcessing = false
            stopSelecting()
            showShareManyIssueAlert(error.localizedDescription)
        }
    }
}

// MARK: - Folder

extension ContentGridViewModel {

    private func removeSingleContentFromFolder() {
        guard let folder else { return }
        guard let refreshAction else { return }
        guard let sound = selectedContentSingle else { return }

        do {
            try userFolderRepository.deleteUserContentFromFolder(withId: folder.id, contentId: sound.id)

            // Need to update folder hash so SyncManager knows about the change on next sync.
            try userFolderRepository.update(folder)

            refreshAction()
        } catch {
            showIssueRemovingContentFromFolderAlert()
        }
    }
}

// MARK: - Scroll To Id

extension ContentGridViewModel {

    public func highlight(id contentId: String) {
        highlightKeeper.insert(contentId)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.highlightKeeper.remove(contentId)
        }
    }
}

// MARK: - Alerts

extension ContentGridViewModel {

    private func showUnableToGetSoundAlert(_ soundTitle: String) {
        HapticFeedback.error()
        alertType = .issueExportingManySounds
        alertTitle = Shared.contentNotFoundAlertTitle(soundTitle)
        alertMessage = Shared.contentNotFoundAlertMessage
        showAlert = true
    }

    private func showShareManyIssueAlert(_ localizedError: String) {
        HapticFeedback.error()
        alertType = .issueExportingManySounds
        alertTitle = "Problema ao Tentar Exportar Vários Conteúdos"
        alertMessage = "Houve um problema desconhecido ao tentar compartilhar vários conteúdos. Por favor, envie um print desse erro para o desenvolvedor (e-mail nas Configurações):\n\n\(localizedError)"
        showAlert = true
    }

    private func showSoundRemovalConfirmation(soundTitle: String) {
        alertTitle = "Remover \"\(soundTitle)\"?"
        alertMessage = "O conteúdo continuará disponível fora da pasta."
        alertType = .removeSingleContent
        showAlert = true
    }

    private func showRemoveMultipleSoundsConfirmation() {
        alertTitle = "Remover os conteúdos selecionados?"
        alertMessage = "Os conteúdos continuarão disponíveis fora da pasta."
        alertType = .removeMultipleContent
        showAlert = true
    }

    private func showIssueRemovingContentFromFolderAlert(plural: Bool = false) {
        alertTitle = "Não Foi Possível Remover \(plural ? "os Conteúdos" : "o Conteúdo") da Pasta"
        alertMessage = "Tente novamente mais tarde."
        alertType = .issueRemovingContentFromFolder
        showAlert = true
    }
}
