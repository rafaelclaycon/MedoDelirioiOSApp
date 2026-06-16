//
//  MainContentViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 14/04/24.
//

import SwiftUI

@MainActor
@Observable
final class MainContentViewModel {

    var state: LoadingState<[AnyEquatableMedoContent]> = .loading

    var currentViewMode: ContentModeOption
    var contentSortOption: Int
    var authorSortOption: Int

    private var currentActivity: NSUserActivity?

    // MARK: - Stored Properties

    public var currentContentListMode: Binding<ContentGridMode>
    public var toast: Binding<Toast?>
    public var floatingOptions: Binding<FloatingContentOptions?>
    private let contentRepository: ContentRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol

    // MARK: - Computed Properties

    private var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Content Update

    var contentUpdateService = ContentUpdateService(
        apiClient: APIClient.shared,
        database: LocalDatabase.shared,
        fileManager: ContentFileManager(),
        appMemory: AppPersistentMemory.shared,
        logger: Logger.shared
    )
    private let syncValues: SyncValues

    var displayLongUpdateBanner: Bool {
        contentUpdateService.isUpdating &&
        contentUpdateService.totalUpdateCount >= 10 &&
        contentUpdateService.processedUpdateNumber < contentUpdateService.totalUpdateCount
    }

    // MARK: - Initializer

    init(
        currentViewMode: ContentModeOption,
        contentSortOption: Int,
        authorSortOption: Int,
        currentContentListMode: Binding<ContentGridMode>,
        toast: Binding<Toast?>,
        floatingOptions: Binding<FloatingContentOptions?>,
        syncValues: SyncValues,
        contentRepository: ContentRepositoryProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.currentViewMode = currentViewMode
        self.contentSortOption = contentSortOption
        self.authorSortOption = authorSortOption
        self.currentContentListMode = currentContentListMode
        self.toast = toast
        self.floatingOptions = floatingOptions
        self.syncValues = syncValues
        self.contentRepository = contentRepository
        self.analyticsService = analyticsService
    }
}

// MARK: - User Actions

extension MainContentViewModel {

    public func onViewDidAppear() async {
        loadContent()
        donateActivity()
        let didUpdate = await contentUpdateService.update()
        loadContent(clearCache: didUpdate)
        
        // Always update sync status to stop the spinner
        syncValues.syncStatus = contentUpdateService.lastUpdateStatus
        
        // Only show toast if there were actual updates
        if didUpdate {
            let message = syncValues.syncStatus.description
            toast.wrappedValue = Toast(message: message, type: syncValues.syncStatus == .done ? .success : .warning)
        }
    }

    public func onSelectedViewModeChanged() async {
        loadContent()
        donateActivity()
        await fireAnalytics()
    }

    public func onContentSortOptionChanged() {
        loadContent()
    }

    public func onExplicitContentSettingChanged() {
        loadContent()
    }

    public func onContentUpdateRequested() async {
        await updateContent(lastAttempt: AppPersistentMemory.shared.getLastUpdateAttempt())
    }

    public func onScenePhaseChanged(newPhase: ScenePhase) async {
        if newPhase == .active {
            await warmOpenContentUpdate()
        }
    }

    public func onFavoritesChanged() {
        loadContent()
    }

    /// Donates a Siri Suggestion for the active mode. Folders and Authors modes
    /// donate from their own embedded view models, so only `.all` and `.favorites`
    /// are handled here.
    private func donateActivity() {
        let activityType: String
        let title: String
        switch currentViewMode {
        case .all:
            activityType = Shared.ActivityTypes.playAndShareSounds
            title = "Ver e compartilhar vírgulas"
        case .favorites:
            activityType = Shared.ActivityTypes.viewFavorites
            title = "Ver vírgulas favoritas"
        default:
            return
        }
        currentActivity = UserActivityWaiter.getDonatableActivity(
            withType: activityType,
            andTitle: title,
            persistentIdentifier: activityType
        )
        currentActivity?.becomeCurrent()
    }
}

// MARK: - Internal Functions

extension MainContentViewModel {

    private func loadContent(clearCache: Bool = false) {
        state = .loading

        if clearCache {
            contentRepository.clearCache()
        }

        do {
            let allowSensitive = UserSettings().getShowExplicitContent()
            let sort = SoundSortOption(rawValue: contentSortOption) ?? .dateAddedDescending
            if currentViewMode == .all {
                state = .loaded(try contentRepository.allContent(allowSensitive, sort))
            } else if currentViewMode == .favorites {
                state = .loaded(try contentRepository.favorites(allowSensitive, sort))
            } else if currentViewMode == .songs {
                state = .loaded(try contentRepository.songs(allowSensitive, sort))
            }
        } catch {
            state = .error(error.localizedDescription)
            debugPrint(error)
        }
    }

    private func updateContent(lastAttempt: String) async {
        guard
            CommandLine.arguments.contains("-IGNORE_CONTENT_UPDATE_WAIT") ||
            lastAttempt == "" ||
            (lastAttempt.iso8601withFractionalSeconds?.minutesPassed(1) ?? false)
        else {
            if syncValues.syncStatus == .updating {
                syncValues.syncStatus = .done
            }
            let message = String(format: Shared.Sync.waitMessage, lastAttempt.timeUntil(addingMinutes: 1))
            toast.wrappedValue = Toast(message: message, type: .wait)
            return
        }

        await contentUpdateService.update()
        
        // Always update sync status and show toast for explicit refresh requests
        syncValues.syncStatus = contentUpdateService.lastUpdateStatus
        let message = syncValues.syncStatus.description
        toast.wrappedValue = Toast(message: message, type: syncValues.syncStatus == .done ? .success : .warning)
    }

    /// Warm open means the app was reopened before it left memory.
    private func warmOpenContentUpdate() async {
        guard !isRunningUnitTests else { return }

        let lastUpdateAttempt = AppPersistentMemory.shared.getLastUpdateAttempt()
        guard
            syncValues.syncStatus != .updating,
            let date = lastUpdateAttempt.iso8601withFractionalSeconds,
            date.minutesPassed(60)
        else { return }

        await updateContent(lastAttempt: lastUpdateAttempt)
    }

    private func fireAnalytics() async {
        let screen = "MainContentView"
        if currentViewMode == .favorites {
            await analyticsService.send(originatingScreen: screen, action: "didViewFavoritesTab")
        } else if currentViewMode == .songs {
            await analyticsService.send(originatingScreen: screen, action: "didViewSongsTab")
        } else if currentViewMode == .folders {
            await analyticsService.send(originatingScreen: screen, action: "didViewFoldersTab")
        } else if currentViewMode == .authors {
            await analyticsService.send(originatingScreen: screen, action: "didViewAuthorsTab")
        }
    }
}
