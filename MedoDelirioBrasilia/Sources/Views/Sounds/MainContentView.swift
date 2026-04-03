//
//  MainContentContainerView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

/// Main view of the app, reponsible for showing the content grid.
struct MainContentView: View {

    @State var viewModel: MainContentViewModel
    @State var contentGridViewModel: ContentGridViewModel
    var currentContentListMode: Binding<ContentGridMode>
    let openSettingsAction: () -> Void
    let contentRepository: ContentRepositoryProtocol
    let userFolderRepository: UserFolderRepositoryProtocol
    let bannerRepository: BannerRepositoryProtocol
    let searchService: SearchServiceProtocol
    let analyticsService: AnalyticsServiceProtocol

    @State var subviewToOpen: MainSoundContainerModalToOpen = .syncInfo
    @State var showingModalView = false
    @State var contentSearchTextIsEmpty: Bool? = true

    // iOS 18 Search
    @State var searchText: String = ""
    @State var searchResults = SearchResults()
    @State var searchToast: Toast? = nil
    @State var isInSearchMode: Bool = false
    @State var reactionsState: LoadingState<[Reaction]> = .loading
    @State var showSearchFeedbackAlert: Bool = false
    @State var searchPlayable: PlayableContentState?
    @State var searchMode: SearchMode = .virgulas
    @State var transcriptSearchTask: Task<Void, Never>?
    @State var isSearchingTranscripts = false
    @State var hasSentTranscriptSearchAnalytics = false

    // Folders
    @State var deleteFolderAide = DeleteFolderViewAide()

    // Authors
    @State var authorsGridViewModel = AuthorsGrid.ViewModel(
        authorService: AuthorService(database: LocalDatabase.shared),
        userSettings: UserSettings(),
        sortOption: UserSettings().authorSortOption()
    )

    @ScaledMetric var explicitOffWarningTopPadding: CGFloat = .spacing(.medium)
    @ScaledMetric var explicitOffWarningBottomPadding: CGFloat = .spacing(.large)

    // MARK: - Environment Objects

    @Environment(TrendsHelper.self) var trendsHelper
    @Environment(SettingsHelper.self) var settingsHelper
    @Environment(PlayRandomSoundHelper.self) var playRandomSoundHelper
    @Environment(TranscriptDownloadService.self) var transcriptDownloadService
    @Environment(\.push) var push

    // MARK: - Computed Properties

    var title: String {
        guard currentContentListMode.wrappedValue == .regular else {
            return selectionNavBarTitle(for: contentGridViewModel)
        }
        return "Vírgulas"
    }

    var loadedContent: [AnyEquatableMedoContent] {
        guard case .loaded(let content) = viewModel.state else { return [] }
        return content
    }

    // MARK: - Shared Environment

    @Environment(\.scenePhase) var scenePhase
    @Namespace var namespace

    // MARK: - Initializer

    init(
        viewModel: MainContentViewModel,
        currentContentListMode: Binding<ContentGridMode>,
        toast: Binding<Toast?>,
        floatingOptions: Binding<FloatingContentOptions?>,
        openSettingsAction: @escaping () -> Void,
        contentRepository: ContentRepositoryProtocol,
        userFolderRepository: UserFolderRepositoryProtocol,
        bannerRepository: BannerRepositoryProtocol,
        searchService: SearchServiceProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.viewModel = viewModel
        self.contentGridViewModel = ContentGridViewModel(
            contentRepository: contentRepository,
            userFolderRepository: userFolderRepository,
            contentFileManager: ContentFileManager(),
            screen: .mainContentView,
            menuOptions: [.sharingOptions(), .organizingOptions(), .detailsOptions()],
            currentListMode: currentContentListMode,
            toast: toast,
            floatingOptions: floatingOptions,
            refreshAction: viewModel.onFavoritesChanged,
            analyticsService: analyticsService
        )
        self.currentContentListMode = currentContentListMode
        self.openSettingsAction = openSettingsAction
        self.contentRepository = contentRepository
        self.userFolderRepository = userFolderRepository
        self.bannerRepository = bannerRepository
        self.searchService = searchService
        self.analyticsService = analyticsService
    }

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ScrollViewReader { proxy in
                    scrollContent(geometry: geometry, proxy: proxy)
                }
            }
            .refreshable {
                Task { // Keep this Task to avoid "cancelled" issue.
                    await viewModel.onContentUpdateRequested()
                }
            }
            .toast(viewModel.toast)
            .floatingContentOptions(viewModel.floatingOptions)
            .toolbar(contentGridViewModel.tabBarVisibility, for: .tabBar)
        }
    }
}

// MARK: - Functions

extension MainContentView {

    func selectionNavBarTitle(for viewModel: ContentGridViewModel) -> String {
        if viewModel.selectionKeeper.count == 0 {
            return Shared.SoundSelection.selectSounds
        }
        if viewModel.selectionKeeper.count == 1 {
            return Shared.SoundSelection.soundSelectedSingular
        }
        return String(format: Shared.SoundSelection.soundsSelectedPlural, viewModel.selectionKeeper.count)
    }

    func highlight(contentId: String) {
        guard !contentId.isEmpty else { return }
        viewModel.currentViewMode = .all
        contentGridViewModel.cancelSearchAndHighlight(id: contentId)
        trendsHelper.contentIdToNavigateTo = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(600)) {
            contentGridViewModel.scrollTo = contentId
            HapticFeedback.warning()
        }
    }

    func playRandomSound() async {
        guard
            let randomSound = contentRepository.randomSound(UserSettings().getShowExplicitContent())
        else {
            print("Erro obtendo som aleatório")
            await AnalyticsService().send(action: "hadErrorPlayingRandomSound")
            return
        }
        playRandomSoundHelper.soundIdToPlay = randomSound.id
        await AnalyticsService().send(action: "didPlayRandomSound(\(randomSound.title))")
    }
}

// MARK: - Preview

#Preview {
    MainContentView(
        viewModel: MainContentViewModel(
            currentViewMode: .all,
            contentSortOption: SoundSortOption.dateAddedDescending.rawValue,
            authorSortOption: AuthorSortOption.nameAscending.rawValue,
            currentContentListMode: .constant(.regular),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            syncValues: SyncValues(),
            contentRepository: FakeContentRepository(),
            analyticsService: FakeAnalyticsService()
        ),
        currentContentListMode: .constant(.regular),
        toast: .constant(nil),
        floatingOptions: .constant(nil),
        openSettingsAction: {},
        contentRepository: FakeContentRepository(),
        userFolderRepository: FakeUserFolderRepository(),
        bannerRepository: BannerRepository(),
        searchService: SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: FakeAppPersistentMemory(),
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        ),
        analyticsService: FakeAnalyticsService()
    )
}
