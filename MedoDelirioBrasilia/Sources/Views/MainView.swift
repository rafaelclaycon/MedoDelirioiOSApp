//
//  MainView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 19/05/22.
//

import LinkPresentation
import os
import SwiftUI

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "MainView")

struct MainView: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService
    @Environment(ChapterDownloadService.self) private var chapterDownloadService
    @Environment(DeepLinkHandler.self) private var deepLinkHandler

    private var tabSelection: Binding<PhoneTab>
    private var padSelection: Binding<PadScreen?>

    @State private var soundsPath = NavigationPath()
    @State private var favoritesPath = NavigationPath()
    @State private var reactionsPath = NavigationPath()
    @State private var authorsPath = NavigationPath()
    @State private var searchTabPath = NavigationPath()
    @State private var foldersPath = NavigationPath()
    @State private var episodesPath = NavigationPath()

    @State private var isShowingSettingsSheet: Bool = false
    @State private var isShowingSupportSheet: Bool = false
    @State private var settingsHelper = SettingsHelper()
    @State private var folderForEditing: UserFolder?
    @State private var updateFolderList: Bool = false
    @State private var currentContentListMode: ContentGridMode = .regular
    @State private var toast: Toast?
    @State private var floatingOptions: FloatingContentOptions?

    @State private var subviewToOpen: MainViewModalToOpen = .onboarding
    @State private var showingModalView: Bool = false
    @State private var showTranscriptsWhatsNew: Bool = false
    @State private var showShareClipWhatsNew: Bool = false

    // iPad
    @State private var sidebarFoldersViewModel: SidebarFoldersViewModel
    @State private var authorSortOption: Int = 0
    @State private var authorSortAction: AuthorSortOption = .nameAscending

    // Trends
    @State private var soundIdToGoToFromTrends: String = ""
    @State private var trendsHelper = TrendsHelper()

    // Content Update
    @State private var syncValues = SyncValues()

    // Deep link error
    @State private var showDeepLinkError: Bool = false
    @State private var deepLinkErrorTitle: String = ""
    @State private var deepLinkErrorMessage: String = ""

    // Episodes
    @State private var episodePlayer = EpisodePlayer()
    @State private var episodeFavoritesStore = EpisodeFavoritesStore()
    @State private var episodeProgressStore = EpisodeProgressStore()
    @State private var episodePlayedStore = EpisodePlayedStore()
    @State private var episodeBookmarkStore = EpisodeBookmarkStore()
    @State private var episodeListenStore = EpisodeListenStore()
    @State private var episodesBadgeStore = EpisodesBadgeStore()
    @State private var showNowPlaying = false
    @Namespace private var nowPlayingTransition

    /// Whether the iOS 26 tab bar bottom accessory is available on this OS.
    /// On earlier versions the floating `NowPlayingBar` is used instead.
    private var isBottomAccessoryAvailable: Bool {
        if #available(iOS 26.0, *) { return true } else { return false }
    }

    @State private var contentRepository: ContentRepository
    private let trendsService = TrendsService.shared
    @State private var reactionRepository = ReactionRepository()
    @State private var searchService: SearchService

    private let userFolderRepository: UserFolderRepositoryProtocol

    init(
        tabSelection: Binding<PhoneTab>,
        padSelection: Binding<PadScreen?>,
        contentRepository: ContentRepository,
        userFolderRepository: UserFolderRepositoryProtocol = UserFolderRepository(database: LocalDatabase.shared)
    ) {
        self.tabSelection = tabSelection
        self.padSelection = padSelection
        self.userFolderRepository = userFolderRepository
        self._contentRepository = State(initialValue: contentRepository)
        self._sidebarFoldersViewModel = State(initialValue: SidebarFoldersViewModel(userFolderRepository: userFolderRepository))

        self._searchService = State(initialValue:
            SearchService(
                contentRepository: contentRepository,
                authorService: AuthorService(database: LocalDatabase.shared),
                appMemory: AppPersistentMemory.shared,
                userFolderRepository: userFolderRepository,
                userSettings: UserSettings(),
                reactionRepository: ReactionRepository()
            )
        )
    }

    // MARK: - View Body

    var body: some View {
        ZStack {
            if UIDevice.deviceType == .iPhone {
                if #available(iOS 26.0, *) {
                    TabView(selection: tabSelection) {
                        Tab(Shared.TabInfo.name(.sounds), systemImage: Shared.TabInfo.symbol(.sounds), value: .sounds) {
                            NavigationStack(path: $soundsPath) {
                                MainContentView(
                                    viewModel: MainContentViewModel(
                                        currentViewMode: .all,
                                        contentSortOption: UserSettings().mainSoundListSoundSortOption(),
                                        authorSortOption: UserSettings().authorSortOption(),
                                        currentContentListMode: $currentContentListMode,
                                        toast: $toast,
                                        floatingOptions: $floatingOptions,
                                        syncValues: syncValues,
                                        contentRepository: contentRepository,
                                        analyticsService: AnalyticsService()
                                    ),
                                    currentContentListMode: $currentContentListMode,
                                    toast: $toast,
                                    floatingOptions: $floatingOptions,
                                    openSettingsAction: {
                                        isShowingSettingsSheet.toggle()
                                    },
                                    contentRepository: contentRepository,
                                    userFolderRepository: userFolderRepository,
                                    bannerRepository: BannerRepository(),
                                    analyticsService: AnalyticsService()
                                )
                                .environment(trendsHelper)
                                .environment(settingsHelper)
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen, contentRepository: contentRepository)
                                }
                            }
                            .tag(PhoneTab.sounds)
                            .environment(\.push, PushAction { soundsPath.append($0) })
                        }

                        Tab(Shared.TabInfo.name(PhoneTab.reactions), systemImage: Shared.TabInfo.symbol(PhoneTab.reactions), value: .reactions) {
                            NavigationStack(path: $reactionsPath) {
                                ReactionsView()
                                    .environment(trendsHelper)
                                    .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                        GeneralRouter(destination: screen, contentRepository: contentRepository)
                                    }
                            }
                            .tag(PhoneTab.reactions)
                            .environment(\.push, PushAction { reactionsPath.append($0) })
                        }

                        Tab("Episódios", systemImage: "radio", value: .episodes) {
                            NavigationStack(path: $episodesPath) {
                                EpisodesView()
                                    .navigationDestination(for: PodcastEpisode.self) { episode in
                                        EpisodeDetailView(episode: episode)
                                    }
                            }
                            .environment(\.push, PushAction { episodesPath.append($0) })
                            .tag(PhoneTab.episodes)
                        }
                        .badge(episodesBadgeText)

                        let searchNavStack = NavigationStack(path: $searchTabPath) {
                            StandaloneSearchView(
                                searchService: searchService,
                                trendsService: trendsService,
                                contentRepository: contentRepository,
                                userFolderRepository: userFolderRepository,
                                analyticsService: AnalyticsService()
                            )
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen, contentRepository: contentRepository)
                            }
                            .navigationDestination(for: SearchNavigationDestination.self) { screen in
                                switch screen {
                                case .trends:
                                    TrendsView(
                                        audienceViewModel: MostSharedByAudienceView.ViewModel(trendsService: trendsService),
                                        tabSelection: tabSelection,
                                        activePadScreen: .constant(.trends)
                                    )
                                    .environment(trendsHelper)
                                }
                            }
                        }
                        .environment(\.push, PushAction { searchTabPath.append($0) })

                        // The `.prominent` tab role is an iOS 27 SDK symbol, so it only
                        // compiles with the Xcode that bundles that SDK.
                        #if compiler(>=6.4)
                        if #available(iOS 27.0, *) {
                            Tab("Buscar", systemImage: "magnifyingglass", value: .search, role: .prominent) {
                                searchNavStack
                            }
                        } else {
                            Tab(value: .search, role: .search) {
                                searchNavStack
                            }
                        }
                        #else
                        Tab(value: .search, role: .search) {
                            searchNavStack
                        }
                        #endif
                    }
                    .if_tabViewBottomAccessory(
                        isEnabled: episodePlayer.currentEpisode != nil
                    ) {
                        NowPlayingAccessoryView(
                            episode: episodePlayer.currentEpisode,
                            player: episodePlayer,
                            onShare: { shareCurrentEpisode() },
                            onGoToEpisode: { goToCurrentEpisode() }
                        )
                        .onTapGesture {
                            showNowPlaying = true
                        }
                        .matchedTransitionSource(id: "nowPlaying", in: nowPlayingTransition)
                    }
                    .tabBarMinimizeBehavior(.onScrollDown)
                } else {
                    TabView(selection: tabSelection) {
                        NavigationStack(path: $soundsPath) {
                            MainContentView(
                                viewModel: MainContentViewModel(
                                    currentViewMode: .all,
                                    contentSortOption: UserSettings().mainSoundListSoundSortOption(),
                                    authorSortOption: UserSettings().authorSortOption(),
                                    currentContentListMode: $currentContentListMode,
                                    toast: $toast,
                                    floatingOptions: $floatingOptions,
                                    syncValues: syncValues,
                                    contentRepository: contentRepository,
                                    analyticsService: AnalyticsService()
                                ),
                                currentContentListMode: $currentContentListMode,
                                toast: $toast,
                                floatingOptions: $floatingOptions,
                                openSettingsAction: {
                                    isShowingSettingsSheet.toggle()
                                },
                                contentRepository: contentRepository,
                                userFolderRepository: userFolderRepository,
                                bannerRepository: BannerRepository(),
                                analyticsService: AnalyticsService()
                            )
                            .environment(trendsHelper)
                            .environment(settingsHelper)
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen, contentRepository: contentRepository)
                            }
                        }
                        .tabItem {
                            Label(Shared.TabInfo.name(.sounds), systemImage: Shared.TabInfo.symbol(.sounds))
                        }
                        .tag(PhoneTab.sounds)
                        .environment(\.push, PushAction { soundsPath.append($0) })

                        NavigationStack(path: $reactionsPath) {
                            ReactionsView()
                                .environment(trendsHelper)
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen, contentRepository: contentRepository)
                                }
                        }
                        .tabItem {
                            Label(Shared.TabInfo.name(PhoneTab.reactions), systemImage: Shared.TabInfo.symbol(PhoneTab.reactions))
                        }
                        .tag(PhoneTab.reactions)
                        .environment(\.push, PushAction { reactionsPath.append($0) })

                        NavigationStack(path: $episodesPath) {
                            EpisodesView()
                                .navigationDestination(for: PodcastEpisode.self) { episode in
                                    EpisodeDetailView(episode: episode)
                                }
                        }
                        .environment(\.push, PushAction { episodesPath.append($0) })
                        .safeAreaInset(edge: .bottom) {
                            NowPlayingBarContainer(player: episodePlayer, showNowPlaying: $showNowPlaying)
                                .padding(.bottom, .spacing(.xSmall))
                        }
                        .tabItem {
                            Label("Episódios", systemImage: "radio")
                        }
                        .badge(episodesBadgeText)
                        .tag(PhoneTab.episodes)

                        NavigationStack(path: $searchTabPath) {
                            StandaloneSearchView(
                                searchService: searchService,
                                trendsService: trendsService,
                                contentRepository: contentRepository,
                                userFolderRepository: userFolderRepository,
                                analyticsService: AnalyticsService()
                            )
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen, contentRepository: contentRepository)
                            }
                            .navigationDestination(for: SearchNavigationDestination.self) { screen in
                                switch screen {
                                case .trends:
                                    TrendsView(
                                        audienceViewModel: MostSharedByAudienceView.ViewModel(trendsService: trendsService),
                                        tabSelection: tabSelection,
                                        activePadScreen: .constant(.trends)
                                    )
                                    .environment(trendsHelper)
                                }
                            }
                        }
                        .tabItem {
                            Label(Shared.TabInfo.name(.search), systemImage: Shared.TabInfo.symbol(.search))
                        }
                        .tag(PhoneTab.search)
                        .environment(\.push, PushAction { searchTabPath.append($0) })
                    }
                }
            } else {
                TabView {
                    Tab(Shared.TabInfo.name(.allSounds), systemImage: Shared.TabInfo.symbol(.allSounds)) {
                        NavigationStack(path: $soundsPath) {
                            MainContentView(
                                viewModel: MainContentViewModel(
                                    currentViewMode: .all,
                                    contentSortOption: UserSettings().mainSoundListSoundSortOption(),
                                    authorSortOption: UserSettings().authorSortOption(),
                                    currentContentListMode: $currentContentListMode,
                                    toast: $toast,
                                    floatingOptions: $floatingOptions,
                                    syncValues: syncValues,
                                    contentRepository: contentRepository,
                                    analyticsService: AnalyticsService()
                                ),
                                currentContentListMode: $currentContentListMode,
                                toast: $toast,
                                floatingOptions: $floatingOptions,
                                openSettingsAction: {},
                                contentRepository: contentRepository,
                                userFolderRepository: userFolderRepository,
                                bannerRepository: BannerRepository(),
                                analyticsService: AnalyticsService()
                            )
                            .environment(trendsHelper)
                            .environment(settingsHelper)
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen, contentRepository: contentRepository)
                            }
                        }
                        .environment(\.push, PushAction { soundsPath.append($0) })
                    }

                    Tab(Shared.TabInfo.name(.favorites), systemImage: Shared.TabInfo.symbol(.favorites)) {
                        NavigationStack(path: $favoritesPath) {
                            StandaloneFavoritesView(
                                viewModel: StandaloneFavoritesViewModel(
                                    contentSortOption: UserSettings().mainSoundListSoundSortOption(),
                                    toast: $toast,
                                    floatingOptions: $floatingOptions,
                                    contentRepository: contentRepository
                                ),
                                currentContentListMode: $currentContentListMode,
                                openSettingsAction: {},
                                contentRepository: contentRepository
                            )
                            .environment(trendsHelper)
                            .environment(settingsHelper)
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen, contentRepository: contentRepository)
                            }
                        }
                        .environment(\.push, PushAction { favoritesPath.append($0) })
                    }

                    Tab(Shared.TabInfo.name(PadScreen.reactions), systemImage: Shared.TabInfo.symbol(PadScreen.reactions)) {
                        NavigationStack(path: $reactionsPath) {
                            ReactionsView()
                                .environment(trendsHelper)
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen, contentRepository: contentRepository)
                                }
                        }
                        .environment(\.push, PushAction { reactionsPath.append($0) })
                    }

                    Tab(Shared.TabInfo.name(.groupedByAuthor), systemImage: Shared.TabInfo.symbol(.groupedByAuthor)) {
                        NavigationStack(path: $authorsPath) {
                            StandaloneAuthorsView()
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen, contentRepository: contentRepository)
                                }
                        }
                        .environment(\.push, PushAction { authorsPath.append($0) })
                    }

                    Tab("Episódios", systemImage: "radio") {
                        NavigationStack(path: $episodesPath) {
                            EpisodesView()
                                .navigationDestination(for: PodcastEpisode.self) { episode in
                                    EpisodeDetailView(episode: episode)
                                }
                        }
                        .environment(\.push, PushAction { episodesPath.append($0) })
                        .if(!isBottomAccessoryAvailable) { view in
                            view.safeAreaInset(edge: .bottom) {
                                NowPlayingBarContainer(player: episodePlayer, showNowPlaying: $showNowPlaying)
                            }
                        }
                    }
                    .badge(episodesBadgeText)

                    TabSection("Minhas Pastas") {
                        Tab(Shared.TabInfo.name(.allFolders), systemImage: Shared.TabInfo.symbol(.allFolders)) {
                            NavigationStack(path: $foldersPath) {
                                StandaloneFolderGridView(
                                    folderForEditing: $folderForEditing,
                                    updateFolderList: $updateFolderList,
                                    contentRepository: contentRepository
                                )
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen, contentRepository: contentRepository)
                                }
                            }
                            .environment(\.push, PushAction { foldersPath.append($0) })
                        }

                        switch sidebarFoldersViewModel.state {
                        case .loading:
                            Tab {
                                EmptyView()
                            } label: {
                                ProgressView()
                            }

                        case .loaded(let folders):
                            ForEach(folders) { folder in
                                Tab {
                                    NavigationStack {
                                        FolderDetailView(
                                            viewModel: FolderDetailViewModel(
                                                folder: folder,
                                                contentRepository: contentRepository
                                            ),
                                            folder: folder,
                                            currentContentListMode: $currentContentListMode,
                                            toast: $toast,
                                            floatingOptions: $floatingOptions,
                                            contentRepository: contentRepository
                                        )
                                    }
                                } label: {
                                    Text("\(folder.symbol)   \(folder.name)")
                                        .padding()
                                }
                            }

                        case .error(_):
                            Tab {
                                EmptyView()
                            } label: {
                                Text("Erro carregando as pastas.")
                            }
                        }
                    }
                    .sectionActions {
                        Button {
                            folderForEditing = UserFolder.newFolder()
                        } label: {
                            Label("Nova Pasta", systemImage: "plus")
                                .foregroundColor(.accentColor)
                        }
                    }

                    Tab(role: .search) {
                        NavigationStack(path: $searchTabPath) {
                            StandaloneSearchView(
                                searchService: searchService,
                                trendsService: trendsService,
                                contentRepository: contentRepository,
                                userFolderRepository: userFolderRepository,
                                analyticsService: AnalyticsService()
                            )
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen, contentRepository: contentRepository)
                            }
                            .navigationDestination(for: SearchNavigationDestination.self) { screen in
                                switch screen {
                                case .trends:
                                    TrendsView(
                                        audienceViewModel: MostSharedByAudienceView.ViewModel(trendsService: trendsService),
                                        tabSelection: tabSelection,
                                        activePadScreen: .constant(.trends)
                                    )
                                    .environment(trendsHelper)
                                }
                            }
                        }
                        .environment(\.push, PushAction { searchTabPath.append($0) })
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                .if_tabViewBottomAccessoryIfAvailable(
                    isEnabled: episodePlayer.currentEpisode != nil
                ) {
                    if #available(iOS 26.0, *) {
                        // No `matchedTransitionSource` here: on iPad the Now Playing
                        // sheet presents as a centered card and the zoom morph from a
                        // bottom-bar accessory misbehaves, so iPad uses the standard
                        // sheet animation (see `if_zoomNavigationTransition`).
                        NowPlayingAccessoryView(
                            episode: episodePlayer.currentEpisode,
                            player: episodePlayer,
                            onShare: { shareCurrentEpisode() },
                            onGoToEpisode: { goToCurrentEpisode() }
                        )
                        .onTapGesture {
                            showNowPlaying = true
                        }
                        .frame(maxWidth: 700)
                    }
                }
                .tabViewSidebarHeader {
                    HStack {
                        Text("Medo e Delírio")
                            .font(.title)
                            .bold()

                        Spacer()
                    }
                }
                .tabViewSidebarFooter {
                    HStack {
                        Button {
                            isShowingSettingsSheet.toggle()
                        } label: {
                            Label("Configurações", systemImage: "gearshape")
                        }

                        Spacer()
                    }
                    .padding(.top, 30)
                }
                .onAppear {
                    Task {
                        await sidebarFoldersViewModel.onViewAppeared()
                    }
                }
            }
        }
        .environment(transcriptDownloadService)
        .environment(syncValues)
        .environment(episodePlayer)
        .environment(episodeFavoritesStore)
        .environment(episodeProgressStore)
        .environment(episodePlayedStore)
        .environment(episodeBookmarkStore)
        .environment(episodeListenStore)
        .environment(episodesBadgeStore)
        // Siri Suggestions. Attached here, on the shared ancestor, so they fire on
        // every device path (both iPhone TabView variants and iPad).
        .onContinueUserActivity(Shared.ActivityTypes.playAndShareSounds) { _ in
            tabSelection.wrappedValue = .sounds
            trendsHelper.contentModeToGoTo = .all
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewFavorites) { _ in
            tabSelection.wrappedValue = .sounds
            trendsHelper.contentModeToGoTo = .favorites
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewCollections) { _ in
            tabSelection.wrappedValue = .sounds
            trendsHelper.contentModeToGoTo = .folders
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewAuthors) { _ in
            tabSelection.wrappedValue = .sounds
            trendsHelper.contentModeToGoTo = .authors
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewReactions) { _ in
            tabSelection.wrappedValue = .reactions
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewReaction) { activity in
            guard let reactionId = activity.userInfo?["reactionId"] as? String else { return }
            handleDeepLink(.reaction(id: reactionId))
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewLast24HoursTopChart) { _ in
            goToTrends(timeInterval: .last24Hours)
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewLastWeekTopChart) { _ in
            goToTrends(timeInterval: .lastWeek)
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewLastMonthTopChart) { _ in
            goToTrends(timeInterval: .lastMonth)
        }
        .onContinueUserActivity(Shared.ActivityTypes.viewAllTimeTopChart) { _ in
            goToTrends(timeInterval: .allTime)
        }
        .onChange(of: tabSelection.wrappedValue) { _, newTab in
            if newTab == .episodes {
                episodesBadgeStore.markAsVisited()
            }
        }
        .onChange(of: episodePlayer.pendingRemoteBookmark) { _, isPending in
            guard isPending else { return }
            showNowPlaying = true
        }
        .onChange(of: episodePlayer.dismissNowPlaying) { _, shouldDismiss in
            guard shouldDismiss else { return }
            showNowPlaying = false
            episodePlayer.dismissNowPlaying = false
        }
        .onChange(of: deepLinkHandler.pendingDeepLink) { _, deepLink in
            guard let deepLink else { return }
            handleDeepLink(deepLink)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTrends)) { _ in
            tabSelection.wrappedValue = .search
            searchTabPath.append(SearchNavigationDestination.trends)
        }
        .alert(deepLinkErrorTitle, isPresented: $showDeepLinkError) {
            Button("OK") { }
        } message: {
            Text(deepLinkErrorMessage)
        }
        .onAppear {
            episodePlayer.setSceneActive(scenePhase == .active)
            episodePlayer.progressStore = episodeProgressStore
            episodePlayer.bookmarkStore = episodeBookmarkStore
            episodePlayer.listenStore = episodeListenStore
            episodePlayer.playedStore = episodePlayedStore
            episodePlayer.analyticsService = AnalyticsService()
            episodePlayer.chapterDownloadService = chapterDownloadService
            episodeBookmarkStore.analyticsService = AnalyticsService()
            logger.debug("MainView appeared")
            sendUserPersonalTrendsToServerIfEnabled()
            displayOnboardingIfNeeded()
            // Only one "what's new" sheet can be presented at a time, so these
            // are mutually exclusive per app open — ShareClip (the newer
            // feature) takes priority; Transcripts catches up on a later open.
            if !displayShareClipWhatsNewIfNeeded() {
                displayTranscriptsWhatsNewIfNeeded()
            }

            Task {
//                if AppPersistentMemory.shared.hasAllowedContentUpdate() {
//                    await contentUpdateService.update()
//                }
                await sendFolderResearchChanges()
            }

            Task {
                try? await EpisodesService.shared.syncEpisodes()
                episodesBadgeStore.recompute()
            }

            if tabSelection.wrappedValue == .episodes {
                episodesBadgeStore.markAsVisited()
            }

            Task {
                await transcriptDownloadService.syncNewTranscriptsIfNeeded()
            }

            // Not gated on any opt-in: the whole catalog's chapters are a couple
            // hundred KB, so every user gets them.
            Task {
                await chapterDownloadService.syncIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            episodePlayer.setSceneActive(newPhase == .active)
            if newPhase == .active {
                episodesBadgeStore.recompute()

                // `onAppear` above only runs once per launch, which used to mean an app
                // kept in the background for days never saw newly generated chapters.
                Task {
                    await chapterDownloadService.syncIfNeeded(
                        minimumInterval: ChapterDownloadService.minimumCheckInterval
                    )
                }
            }
        }
        .sheet(isPresented: $showingModalView) {
            switch subviewToOpen {
            case .settings:
                SettingsView(apiClient: APIClient.shared)
                    .environment(settingsHelper)
                    .environment(transcriptDownloadService)

            case .onboarding:
                OnboardingView()
                    .interactiveDismissDisabled(UIDevice.deviceType == .iPhone)

            case .retrospective, .whatsNew:
                EmptyView()
            }
        }
        .sheet(item: $folderForEditing) { folder in
            FolderInfoEditingView(
                folder: folder,
                folderRepository: userFolderRepository,
                dismissSheet: {
                    folderForEditing = nil
                    updateFolderList = true
                }
            )
        }
        // Could be removed in the future, but for now using `showingModalView` bugs out on iPad. Shows Onboarding most of the time.
        .sheet(isPresented: $isShowingSettingsSheet) {
            SettingsView(apiClient: APIClient.shared)
                .environment(settingsHelper)
                .environment(transcriptDownloadService)
        }
        .sheet(isPresented: $isShowingSupportSheet) {
            StandaloneSupportView()
        }
        .sheet(isPresented: $showShareClipWhatsNew, onDismiss: {
            AppPersistentMemory.shared.hasSeenShareClipWhatsNewScreen(true)
        }) {
            IntroducingShareClipView(appMemory: AppPersistentMemory.shared)
        }
        .sheetOrFullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environment(episodePlayer)
                .environment(episodeBookmarkStore)
                .environment(transcriptDownloadService)
                .environment(episodeFavoritesStore)
                .if_zoomNavigationTransition(
                    sourceID: "nowPlaying",
                    in: nowPlayingTransition,
                    isEnabled: UIDevice.deviceType == .iPhone
                )
        }
        .sheet(isPresented: $episodePlayer.showSupportPrompt, onDismiss: {
            let memory = AppPersistentMemory.shared
            memory.setHasSeenEpisodeSupportPrompt(true)
            memory.setLastSupportPromptDate(Date())
        }) {
            // One screen only: the pitch and the donate buttons together,
            // instead of the old explainer-prompt-then-support two-step.
            StandaloneSupportView(context: .episodeCompleted)
                .onAppear {
                    Task {
                        await AnalyticsService().send(
                            originatingScreen: "SupportPrompt",
                            action: "support_sheet_shown(trigger=episodes)"
                        )
                    }
                }
        }
    }

    // MARK: - Computed

    private var episodesBadgeText: Text? {
        switch episodesBadgeStore.badge {
        case .none:
            return nil
        case .count(let n):
            return Text("\(n)")
        }
    }

    // MARK: - Functions

    /// Prepares and presents the share sheet for the currently playing episode.
    ///
    /// Presented imperatively rather than via a SwiftUI `.sheet` because the
    /// accessory menu only appears at regular width (iPad), where a
    /// `UIActivityViewController` embedded in a sheet renders blank — it needs a
    /// popover anchor instead.
    private func shareCurrentEpisode() {
        guard let episode = episodePlayer.currentEpisode else { return }
        guard let shareURL = URL(string: APIConfig.baseLinkURL + "episodio/\(episode.id)") else { return }
        Task { await AnalyticsService().send(originatingScreen: "NowPlayingAccessory", action: "didTapShare(\(episode.id))") }

        Task { @MainActor in
            let meta = LPLinkMetadata()
            meta.url = shareURL
            meta.title = episode.title

            if let imageURL = episode.imageURL,
               let (data, _) = try? await URLSession.shared.data(from: imageURL),
               let image = UIImage(data: data) {
                meta.imageProvider = NSItemProvider(object: image)
            }

            presentShareSheet(for: meta)
        }
    }

    @MainActor
    private func presentShareSheet(for metadata: LPLinkMetadata) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        else { return }

        var presenter = window.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        guard let presenter else { return }

        let source = LinkMetadataItemSource(metadata: metadata)
        let activityVC = UIActivityViewController(activityItems: [source], applicationActivities: nil)

        // iPad requires a popover anchor; center it near the bottom, where the accessory lives.
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 80,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true)
    }

    /// Navigates to the currently playing episode's detail screen on the Episodes tab.
    private func goToCurrentEpisode() {
        guard let episode = episodePlayer.currentEpisode else { return }
        tabSelection.wrappedValue = .episodes
        episodesPath.append(episode)
    }

    /// Routes a Trends top-chart Siri Suggestion to the Trends screen (under the Search tab),
    /// carrying the requested time interval via `TrendsHelper` for the view to apply.
    private func goToTrends(timeInterval: TrendsTimeInterval) {
        trendsHelper.timeIntervalToGoTo = timeInterval
        tabSelection.wrappedValue = .search
        if searchTabPath.isEmpty {
            searchTabPath.append(SearchNavigationDestination.trends)
        }
    }

    private func handleDeepLink(_ deepLink: DeepLink) {
        deepLinkHandler.pendingDeepLink = nil

        switch deepLink {
        case .reaction(let id):
            tabSelection.wrappedValue = .reactions
            Task {
                do {
                    let reaction = try await reactionRepository.reaction(id)
                    reactionsPath.append(GeneralNavigationDestination.reactionDetail(reaction))
                } catch {
                    deepLinkErrorTitle = "Opa! 😅"
                    deepLinkErrorMessage = "Essa reação sumiu! Deve ter ido pra alguma CPI sem avisar. Tente novamente mais tarde."
                    showDeepLinkError = true
                }
            }

        case .episode(let id):
            tabSelection.wrappedValue = .episodes
            do {
                guard let episode = try LocalDatabase.shared.podcastEpisode(id: id) else {
                    deepLinkErrorTitle = "Opa! 😅"
                    deepLinkErrorMessage = "Esse episódio saiu correndo e não conseguimos encontrá-lo. Tente novamente mais tarde."
                    showDeepLinkError = true
                    return
                }
                episodesPath.append(episode)
            } catch {
                deepLinkErrorTitle = "Opa! 😅"
                deepLinkErrorMessage = "Esse episódio saiu correndo e não conseguimos encontrá-lo. Tente novamente mais tarde."
                showDeepLinkError = true
            }
        }
    }

    private func sendUserPersonalTrendsToServerIfEnabled() {
        Task {
            guard UserSettings().getEnableTrends() else {
                return
            }
            guard UserSettings().getEnableShareUserPersonalTrends() else {
                return
            }

            let todayDate = Date.now.onlyDate ?? Date.now

            if let lastDate = AppPersistentMemory.shared.getLastSendDateOfUserPersonalTrendsToServer(),
               let lastOnlyDate = lastDate.onlyDate {
                if lastOnlyDate < todayDate {
                    let result = await Podium.shared.sendShareCountStatsToServer()

                    guard result == .successful || result == .noStatsToSend else {
                        return
                    }
                    AppPersistentMemory.shared.setLastSendDateOfUserPersonalTrendsToServer(to: todayDate)
                }
            } else {
                let result = await Podium.shared.sendShareCountStatsToServer()

                guard result == .successful || result == .noStatsToSend else {
                    return
                }
                AppPersistentMemory.shared.setLastSendDateOfUserPersonalTrendsToServer(to: todayDate)
            }
        }
    }

    private func displayOnboardingIfNeeded() {
        if !AppPersistentMemory.shared.hasShownNotificationsOnboarding() {
            subviewToOpen = .onboarding
            showingModalView = true
        }
    }

    private func displayTranscriptsWhatsNewIfNeeded() {
        guard AppPersistentMemory.shared.hasShownNotificationsOnboarding() else { return }
        guard !AppPersistentMemory.shared.hasSeenTranscriptsWhatsNewScreen() else { return }

        showTranscriptsWhatsNew = true
    }

    @discardableResult
    private func displayShareClipWhatsNewIfNeeded() -> Bool {
        guard AppPersistentMemory.shared.hasShownNotificationsOnboarding() else { return false }
        guard !AppPersistentMemory.shared.hasSeenShareClipWhatsNewScreen() else { return false }

        showShareClipWhatsNew = true
        return true
    }

    private func sendFolderResearchChanges() async {
        do {
            let provider = FolderResearchProvider(
                userSettings: UserSettings(),
                appMemory: AppPersistentMemory.shared,
                localDatabase: LocalDatabase.shared,
                repository: FolderResearchRepository()
            )
            try await provider.sendChanges()
        } catch {
            await AnalyticsService().send(
                originatingScreen: "MainView",
                action: "issueSendingFolderResearchChanges(\(error.localizedDescription))"
            )
        }
    }
}

// MARK: - NowPlayingBarContainer

/// Isolates `EpisodePlayer` observation so that high-frequency property changes
/// (e.g. `currentTime` every 0.5s) only invalidate this small view, not the
/// parent `MainView.body`. Fixes an iOS 18 over-tracking issue where accessing
/// any `@Observable` property caused all mutations to trigger body re-evaluation.
private struct NowPlayingBarContainer: View {

    let player: EpisodePlayer
    @Binding var showNowPlaying: Bool

    var body: some View {
        if player.currentEpisode != nil {
            NowPlayingBar(episode: player.currentEpisode, player: player)
                .onTapGesture { showNowPlaying = true }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView(
        tabSelection: .constant(.sounds),
        padSelection: .constant(.allSounds),
        contentRepository: ContentRepository(database: LocalDatabase.shared)
    )
    .environment(EpisodePlayer())
    .environment(TranscriptDownloadService())
    .environment(ChapterDownloadService())
}
