//
//  MainContentContainerView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

/// Main view of the app, reponsible for showing the content grid.
struct MainContentView: View {

    @State private var viewModel: MainContentViewModel
    @State private var contentGridViewModel: ContentGridViewModel
    private var currentContentListMode: Binding<ContentGridMode>
    private let openSettingsAction: () -> Void
    private let contentRepository: ContentRepositoryProtocol
    private let userFolderRepository: UserFolderRepositoryProtocol
    private let bannerRepository: BannerRepositoryProtocol
    private let searchService: SearchServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    @State private var subviewToOpen: MainSoundContainerModalToOpen = .syncInfo
    @State private var showingModalView = false
    @State private var contentSearchTextIsEmpty: Bool? = true

    // iOS 18 Search
    @State private var searchText: String = ""
    @State private var searchResults = SearchResults()
    @State private var searchToast: Toast? = nil
    @State private var isInSearchMode: Bool = false
    @State private var reactionsState: LoadingState<[Reaction]> = .loading
    @State private var showSearchFeedbackAlert: Bool = false
    @State private var searchPlayable: PlayableContentState?
    @State private var searchMode: SearchMode = .virgulas

    // Folders
    @State private var deleteFolderAide = DeleteFolderViewAide()

    // Authors
    @State private var authorsGridViewModel = AuthorsGrid.ViewModel(
        authorService: AuthorService(database: LocalDatabase.shared),
        userSettings: UserSettings(),
        sortOption: UserSettings().authorSortOption()
    )

    @ScaledMetric private var explicitOffWarningTopPadding: CGFloat = .spacing(.medium)
    @ScaledMetric private var explicitOffWarningBottomPadding: CGFloat = .spacing(.large)

    // MARK: - Environment Objects

    @Environment(TrendsHelper.self) private var trendsHelper
    @Environment(SettingsHelper.self) private var settingsHelper 
    @Environment(PlayRandomSoundHelper.self) private var playRandomSoundHelper
    @Environment(\.push) private var push

    // MARK: - Computed Properties

    private var title: String {
        guard currentContentListMode.wrappedValue == .regular else {
            return selectionNavBarTitle(for: contentGridViewModel)
        }
        return "Vírgulas"
    }

    private var loadedContent: [AnyEquatableMedoContent] {
        guard case .loaded(let content) = viewModel.state else { return [] }
        return content
    }

    @ViewBuilder
    private var searchSuggestionsContent: some View {
        if let searchPlayable {
            SearchSuggestionsView(
                recent: searchService.recentSearches(),
                playable: searchPlayable,
                trendsService: TrendsService.shared,
                onRecentSelectedAction: { text in
                    searchText = text
                },
                onReactionSelectedAction: { reaction in
                    push(GeneralNavigationDestination.reactionDetail(reaction))
                },
                containerWidth: UIScreen.main.bounds.width - 32,
                toast: $searchToast,
                onClearSearchesAction: {
                    searchService.clearRecentSearches()
                }
            )
        }
    }

    // MARK: - Shared Environment

    @Environment(\.scenePhase) var scenePhase
    @Namespace private var namespace

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
                    VStack(spacing: .spacing(.xSmall)) {
                        if contentSearchTextIsEmpty ?? true, currentContentListMode.wrappedValue == .regular, !isInSearchMode {
                            ContentModePicker(
                                options: UIDevice.isiPhone ? ContentModeOption.allCases : [.all, .songs],
                                selected: $viewModel.currentViewMode,
                                allowScrolling: UIDevice.isiPhone
                            )
                            .scrollClipDisabled()
                        }

                        switch viewModel.currentViewMode {
                        case .all, .favorites, .songs:
                            VStack(spacing: .spacing(.xSmall)) {
                                VStack(spacing: .spacing(.xSmall)) {
                                    if viewModel.displayLongUpdateBanner {
                                        LongUpdateBanner(
                                            completedNumber: viewModel.contentUpdateService.processedUpdateNumber,
                                            totalUpdateCount: viewModel.contentUpdateService.totalUpdateCount,
                                            estimatedSecondsRemaining: viewModel.contentUpdateService.estimatedSecondsRemaining
                                        )
                                    }

                                    if viewModel.currentViewMode == .all, contentSearchTextIsEmpty ?? false {
                                        BannersView(
                                            bannerRepository: bannerRepository,
                                            toast: viewModel.toast
                                        )
                                    }
                                }

                                SearchAwareContentView(
                                    searchText: searchText,
                                    searchResults: searchResults,
                                    reactionsState: reactionsState,
                                    searchToast: $searchToast,
                                    isInSearchMode: $isInSearchMode,
                                    searchMode: $searchMode,
                                    searchSuggestionsContent: searchSuggestionsContent,
                                    playable: searchPlayable,
                                    containerWidth: geometry.size.width,
                                    retryLoadReactionsAction: loadReactions,
                                    gridContent: {
                                        ContentGrid(
                                            state: viewModel.state,
                                            viewModel: contentGridViewModel,
                                            toast: viewModel.toast,
                                            searchTextIsEmpty: $contentSearchTextIsEmpty,
                                            allowSearch: false,
                                            isFavoritesOnlyView: viewModel.currentViewMode == .favorites,
                                            containerSize: geometry.size,
                                            scrollViewProxy: proxy,
                                            loadingView: BasicLoadingView(text: "Carregando Conteúdos..."),
                                            emptyStateView:
                                                VStack {
                                                    if viewModel.currentViewMode == .favorites {
                                                        NoFavoritesView()
                                                            .padding(.vertical, .spacing(.huge))
                                                    } else {
                                                        Text("Nenhum som a ser exibido. Isso é esquisito.")
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                            ,
                                            errorView: VStack { ContentLoadErrorView() }
                                        )
                                    }
                                )

                                if
                                    viewModel.currentViewMode == .all,
                                    !UserSettings().getShowExplicitContent(),
                                    !isInSearchMode
                                {
                                    ExplicitDisabledWarning(
                                        text: UIDevice.isiPhone ? Shared.contentFilterMessageForSoundsiPhone : Shared.contentFilterMessageForSoundsiPadMac
                                    )
                                    .padding(.top, explicitOffWarningTopPadding)
                                }

                                if
                                    viewModel.currentViewMode == .all,
                                    loadedContent.count > 0,
                                    contentSearchTextIsEmpty ?? true,
                                    !isInSearchMode
                                {
                                    Text("\(loadedContent.count) ITENS")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, .spacing(.small))
                                        .padding(.bottom, Shared.Constants.soundCountPadBottomPadding)
                                }

                                Spacer()
                                    .frame(height: .spacing(.large))
                            }
                            .padding(.horizontal, .spacing(.medium))

                        case .folders:
                            SearchAwareContentView(
                                searchText: searchText,
                                searchResults: searchResults,
                                reactionsState: reactionsState,
                                searchToast: $searchToast,
                                isInSearchMode: $isInSearchMode,
                                searchMode: $searchMode,
                                searchSuggestionsContent: searchSuggestionsContent,
                                playable: searchPlayable,
                                containerWidth: geometry.size.width,
                                retryLoadReactionsAction: loadReactions,
                                gridContent: {
                                    MyFoldersiPhoneView(
                                        contentRepository: contentRepository,
                                        userFolderRepository: userFolderRepository,
                                        containerSize: geometry.size
                                    )
                                    .environment(deleteFolderAide)
                                }
                            )
                            .padding(.horizontal, .spacing(.medium))

                        case .authors:
                            SearchAwareContentView(
                                searchText: searchText,
                                searchResults: searchResults,
                                reactionsState: reactionsState,
                                searchToast: $searchToast,
                                isInSearchMode: $isInSearchMode,
                                searchMode: $searchMode,
                                searchSuggestionsContent: searchSuggestionsContent,
                                playable: searchPlayable,
                                containerWidth: geometry.size.width,
                                retryLoadReactionsAction: loadReactions,
                                gridContent: {
                                    AuthorsGrid(
                                        viewModel: authorsGridViewModel,
                                        containerWidth: geometry.size.width
                                    )
                                }
                            )
                            .padding(.horizontal, .spacing(.medium))
                        }
                    }
                    .navigationTitle(Text(title))
                    .toolbar {
                        LeadingToolbarControls(
                            isSelecting: currentContentListMode.wrappedValue == .selection,
                            cancelAction: { contentGridViewModel.onExitMultiSelectModeSelected() },
                            openSettingsAction: openSettingsAction
                        )

                        TrailingToolbarControls(
                            currentViewMode: viewModel.currentViewMode,
                            contentListMode: currentContentListMode.wrappedValue,
                            contentSortOption: $viewModel.contentSortOption,
                            authorSortOption: $viewModel.authorSortOption,
                            isInSearchMode: isInSearchMode,
                            openContentUpdateSheet: {
                                subviewToOpen = .syncInfo
                                showingModalView = true
                            },
                            multiSelectAction: {
                                contentGridViewModel.onEnterMultiSelectModeSelected(
                                    loadedContent: loadedContent,
                                    isFavoritesOnlyView: viewModel.currentViewMode == .favorites
                                )
                            },
                            playRandomSoundAction: {
                                Task {
                                    await playRandomSound()
                                }
                            },
                            contentSortChangeAction: {
                                viewModel.onContentSortOptionChanged()
                            },
                            authorSortChangeAction: {
                                authorsGridViewModel.onAuthorSortingChangedExternally(viewModel.authorSortOption)
                            },
                            showFeedbackAction: {
                                showSearchFeedbackAlert = true
                            },
                            matchedTransitionNamespace: namespace
                        )
                    }
                    .if(!UIDevice.isIOS26OrLater) { view in
                        view
                            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: Shared.Search.searchPrompt)
                            .autocorrectionDisabled()
                    }
                    .onChange(of: searchText) {
                        onSearchTextChanged(newString: searchText)
                    }
                    .onChange(of: viewModel.currentViewMode) {
                        Task {
                            await viewModel.onSelectedViewModeChanged()
                        }
                    }
                    .onChange(of: playRandomSoundHelper.soundIdToPlay) {
                        if !playRandomSoundHelper.soundIdToPlay.isEmpty {
                            viewModel.currentViewMode = .all
                            contentGridViewModel.scrollAndPlay(
                                contentId: playRandomSoundHelper.soundIdToPlay,
                                loadedContent: loadedContent
                            )
                            playRandomSoundHelper.soundIdToPlay = ""
                        }
                    }
                    .sheet(isPresented: $showingModalView) {
                        if #available(iOS 26.0, *) {
                            ContentUpdateStatusView(
                                lastUpdateAttempt: AppPersistentMemory().getLastUpdateAttempt(),
                                lastUpdateDate: LocalDatabase.shared.dateTimeOfLastUpdate()
                            )
                            .presentationDetents([.medium, .large])
                            .navigationTransition(
                                .zoom(sourceID: "sync-status-view", in: namespace)
                            )
                        } else {
                            ContentUpdateStatusView(
                                lastUpdateAttempt: AppPersistentMemory().getLastUpdateAttempt(),
                                lastUpdateDate: LocalDatabase.shared.dateTimeOfLastUpdate()
                            )
                        }
                    }
                    // iOS 18 compat: Search feedback button only shows for pre-iOS 26 search UI.
                    .alert(
                        Shared.Search.Feedback.alertTitle,
                        isPresented: $showSearchFeedbackAlert
                    ) {
                        Button("Cancelar", role: .cancel) { }
                        Button("Continuar") {
                            Task {
                                await Mailman.openDefaultEmailApp(
                                    subject: Shared.Search.Feedback.emailSubject,
                                    body: Shared.Search.Feedback.emailBody
                                )
                            }
                        }
                    } message: {
                        Text(Shared.Search.Feedback.alertMessage)
                    }
                    .onChange(of: settingsHelper.updateSoundsList) { // iPad - Settings sensitive toggle.
                        if settingsHelper.updateSoundsList {
                            viewModel.onExplicitContentSettingChanged()
                            settingsHelper.updateSoundsList = false
                        }
                    }
                    .onChange(of: trendsHelper.contentIdToNavigateTo) {
                        highlight(contentId: trendsHelper.contentIdToNavigateTo)
                    }
                    .task {
                        if searchPlayable == nil {
                            searchPlayable = PlayableContentState(
                                contentRepository: contentRepository,
                                contentFileManager: ContentFileManager(),
                                analyticsService: analyticsService,
                                screen: .searchResultsView,
                                toast: $searchToast
                            )
                        }
                        await viewModel.onViewDidAppear()
                    }
                    .onChange(of: scenePhase) {
                        Task {
                            await viewModel.onScenePhaseChanged(newPhase: scenePhase)
                        }
                    }
                    .onChange(of: isInSearchMode) {
                        if isInSearchMode {
                            Task {
                                await loadReactions()
                            }
                        }
                    }
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

// MARK: - Subviews

extension MainContentView {

    struct TrailingToolbarControls: ToolbarContent {

        let currentViewMode: ContentModeOption
        let contentListMode: ContentGridMode
        @Binding var contentSortOption: Int
        @Binding var authorSortOption: Int
        let isInSearchMode: Bool
        let openContentUpdateSheet: () -> Void
        let multiSelectAction: () -> Void
        let playRandomSoundAction: () -> Void
        let contentSortChangeAction: () -> Void
        let authorSortChangeAction: () -> Void
        let showFeedbackAction: () -> Void
        let matchedTransitionNamespace: Namespace.ID

        var body: some ToolbarContent {
            if isInSearchMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFeedbackAction()
                    } label: {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                    }
                }
            } else if currentViewMode != .folders { // MyFoldersiPhoneView takes care of its own toolbar.
                if currentViewMode == .authors {
                    AuthorToolbarOptionsView(
                        authorSortOption: $authorSortOption,
                        onSortingChangedAction: authorSortChangeAction
                    )
                } else {
                    if contentListMode == .regular {
                        if #available(iOS 26.0, *) {
                            ToolbarItem {
                                Button {
                                    openContentUpdateSheet()
                                } label: {
                                    ContentUpdateStatusSymbol()
                                }
                            }
                            .matchedTransitionSource(id: "sync-status-view", in: matchedTransitionNamespace)
                        } else {
                            ToolbarItem {
                                Button {
                                    openContentUpdateSheet()
                                } label: {
                                    ContentUpdateStatusSymbol()
                                }
                            }
                        }
                    }

                    ContentToolbarOptionsView(
                        contentSortOption: $contentSortOption,
                        contentListMode: contentListMode,
                        multiSelectAction: multiSelectAction,
                        playRandomSoundAction: playRandomSoundAction,
                        contentSortChangeAction: contentSortChangeAction
                    )
                }
            }
        }
    }

    struct BannersView: View {

        let bannerRepository: BannerRepositoryProtocol
        @Binding var toast: Toast?

        @State private var data: DynamicBannerData?
        @State private var showDunBanner = !AppPersistentMemory.shared.hasDismissedDunBanner()

        var body: some View {
            VStack {
                if showDunBanner {
                    DunBannerView(isBeingShown: $showDunBanner)
                        .padding(.top, .spacing(.xxxSmall))
                        .padding(.bottom, .spacing(.xSmall))
                }

                if let data {
                    DynamicBanner(
                        bannerData: data,
                        textCopyFeedback: { message in
                            self.toast = Toast(message: message, type: .thankYou)
                        }
                    )
                    .padding(.top, .spacing(.xxxSmall))
                    .padding(.bottom, .spacing(.xSmall))
                }
            }
            .onAppear {
                Task{
                    data = await bannerRepository.dynamicBanner()
                }
            }
        }
    }

    /// A view that reads `isSearching` environment and shows the appropriate content.
    /// This must be a child of a view with `.searchable()` for the environment to work.
    struct SearchAwareContentView<SuggestionsContent: View, GridContent: View>: View {

        let searchText: String
        let searchResults: SearchResults
        let reactionsState: LoadingState<[Reaction]>
        @Binding var searchToast: Toast?
        @Binding var isInSearchMode: Bool
        @Binding var searchMode: SearchMode
        let searchSuggestionsContent: SuggestionsContent
        let playable: PlayableContentState?
        let containerWidth: CGFloat
        var retryLoadReactionsAction: (() async -> Void)? = nil
        @ViewBuilder let gridContent: () -> GridContent

        @Environment(\.isSearching) private var isSearching

        private var shouldShowSearchUI: Bool {
            !UIDevice.isIOS26OrLater && isSearching
        }

        var body: some View {
            Group {
                if shouldShowSearchUI && searchText.isEmpty {
                    searchSuggestionsContent
                } else if shouldShowSearchUI && !searchText.isEmpty {
                    if let playable {
                        SearchResultsView(
                            playable: playable,
                            searchString: searchText,
                            results: searchResults,
                            reactionsState: reactionsState,
                            containerWidth: containerWidth,
                            toast: $searchToast,
                            menuOptions: [.sharingOptions(), .organizingOptions(), .detailsOptions()],
                            searchMode: $searchMode,
                            retryLoadReactionsAction: retryLoadReactionsAction
                        )
                    }
                } else {
                    gridContent()
                }
            }
            .onChange(of: isSearching) {
                isInSearchMode = shouldShowSearchUI
            }
            .onAppear {
                isInSearchMode = shouldShowSearchUI
            }
        }
    }
}

// MARK: - Functions

extension MainContentView {

    private func selectionNavBarTitle(for viewModel: ContentGridViewModel) -> String {
        if viewModel.selectionKeeper.count == 0 {
            return Shared.SoundSelection.selectSounds
        }
        if viewModel.selectionKeeper.count == 1 {
            return Shared.SoundSelection.soundSelectedSingular
        }
        return String(format: Shared.SoundSelection.soundsSelectedPlural, viewModel.selectionKeeper.count)
    }

    private func highlight(contentId: String) {
        guard !contentId.isEmpty else { return }
        viewModel.currentViewMode = .all
        contentGridViewModel.cancelSearchAndHighlight(id: contentId)
        trendsHelper.contentIdToNavigateTo = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(600)) {
            contentGridViewModel.scrollTo = contentId
            HapticFeedback.warning()
        }
    }

    private func playRandomSound() async {
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

    private func onSearchTextChanged(newString: String) {
        guard !newString.isEmpty else {
            searchResults.clearAll()
            return
        }
        searchResults = searchService.results(matching: newString)
    }

    private func loadReactions() async {
        reactionsState = .loading
        await searchService.loadReactions()
        reactionsState = searchService.reactionsState
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
