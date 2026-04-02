//
//  MainView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 19/05/22.
//

import os
import SwiftUI

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "MainView")

struct MainView: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService

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
    @State private var showEpisodesWhatsNew: Bool = false
    @State private var showTranscriptsWhatsNew: Bool = false

    // iPad
    @State private var sidebarFoldersViewModel: SidebarFoldersViewModel
    @State private var authorSortOption: Int = 0
    @State private var authorSortAction: AuthorSortOption = .nameAscending

    // Trends
    @State private var soundIdToGoToFromTrends: String = ""
    @State private var trendsHelper = TrendsHelper()

    // Content Update
    @State private var syncValues = SyncValues()

    // Episodes
    @State private var episodePlayer = EpisodePlayer()
    @State private var episodeFavoritesStore = EpisodeFavoritesStore()
    @State private var episodeProgressStore = EpisodeProgressStore()
    @State private var episodePlayedStore = EpisodePlayedStore()
    @State private var episodeBookmarkStore = EpisodeBookmarkStore()
    @State private var episodeListenStore = EpisodeListenStore()
    @State private var showNowPlaying = false

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
            if UIDevice.isiPhone {
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
                                searchService: searchService,
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

                    Tab("Episódios", systemImage: "radio", value: .trends) {
                        NavigationStack(path: $episodesPath) {
                            EpisodesView()
                                .navigationDestination(for: PodcastEpisode.self) { episode in
                                    EpisodeDetailView(episode: episode)
                                }
                        }
                        .environment(\.push, PushAction { episodesPath.append($0) })
                        .tag(PhoneTab.trends)
                    }

                    Tab(value: .search, role: .search) {
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
                    .if_tabViewBottomAccessory(
                        isEnabled: episodePlayer.currentEpisode != nil
                    ) {
                        NowPlayingAccessoryView(episode: episodePlayer.currentEpisode, player: episodePlayer)
                            .onTapGesture {
                                showNowPlaying = true
                            }
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
                                searchService: searchService,
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
                        .tag(PhoneTab.trends)

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
                    .onContinueUserActivity(Shared.ActivityTypes.playAndShareSounds, perform: { _ in
                        tabSelection.wrappedValue = .sounds
                    })
                    //                .onContinueUserActivity(Shared.ActivityTypes.viewCollections, perform: { _ in
                    //                    tabSelection = .collections
                    //                })
                    //                .onContinueUserActivity(Shared.ActivityTypes.playAndShareSongs, perform: { _ in
                    //                    tabSelection = .songs
                    //                })
                    .onContinueUserActivity(Shared.ActivityTypes.viewLast24HoursTopChart, perform: { _ in
                        tabSelection.wrappedValue = .trends
                        trendsHelper.timeIntervalToGoTo = .last24Hours
                    })
                    .onContinueUserActivity(Shared.ActivityTypes.viewLastWeekTopChart, perform: { _ in
                        tabSelection.wrappedValue = .trends
                        trendsHelper.timeIntervalToGoTo = .lastWeek
                    })
                    .onContinueUserActivity(Shared.ActivityTypes.viewLastMonthTopChart, perform: { _ in
                        tabSelection.wrappedValue = .trends
                        trendsHelper.timeIntervalToGoTo = .lastMonth
                    })
                    .onContinueUserActivity(Shared.ActivityTypes.viewAllTimeTopChart, perform: { _ in
                        tabSelection.wrappedValue = .trends
                        trendsHelper.timeIntervalToGoTo = .allTime
                    })
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
                                searchService: searchService,
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
                        .safeAreaInset(edge: .bottom) {
                            NowPlayingBarContainer(player: episodePlayer, showNowPlaying: $showNowPlaying)
                        }
                    }

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
        .environment(syncValues)
        .environment(episodePlayer)
        .environment(episodeFavoritesStore)
        .environment(episodeProgressStore)
        .environment(episodePlayedStore)
        .environment(episodeBookmarkStore)
        .environment(episodeListenStore)
        .onChange(of: episodePlayer.pendingRemoteBookmark) { _, isPending in
            guard isPending else { return }
            showNowPlaying = true
        }
        .onChange(of: episodePlayer.dismissNowPlaying) { _, shouldDismiss in
            guard shouldDismiss else { return }
            showNowPlaying = false
            episodePlayer.dismissNowPlaying = false
        }
        .onAppear {
            episodePlayer.setSceneActive(scenePhase == .active)
            episodePlayer.progressStore = episodeProgressStore
            episodePlayer.bookmarkStore = episodeBookmarkStore
            episodePlayer.listenStore = episodeListenStore
            episodePlayer.playedStore = episodePlayedStore
            episodePlayer.analyticsService = AnalyticsService()
            episodeBookmarkStore.analyticsService = AnalyticsService()
            logger.debug("MainView appeared")
            sendUserPersonalTrendsToServerIfEnabled()
            displayOnboardingIfNeeded()
            displayEpisodesWhatsNewIfNeeded()
            displayTranscriptsWhatsNewIfNeeded()

            Task {
//                if AppPersistentMemory.shared.hasAllowedContentUpdate() {
//                    await contentUpdateService.update()
//                }
                await sendFolderResearchChanges()
            }

            Task {
                try? await EpisodesService().syncEpisodes()
            }

            if FeatureFlag.isEnabled(.projectEleDisseIssoMesmo) {
                Task {
                    await transcriptDownloadService.syncNewTranscriptsIfNeeded()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            episodePlayer.setSceneActive(newPhase == .active)
        }
        .sheet(isPresented: $showingModalView) {
            switch subviewToOpen {
            case .settings:
                SettingsView(apiClient: APIClient.shared)
                    .environment(settingsHelper)

            case .onboarding:
                OnboardingView()
                    .interactiveDismissDisabled(UIDevice.isiPhone)

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
        }
        .sheet(isPresented: $isShowingSupportSheet) {
            StandaloneSupportView()
        }
        .sheet(isPresented: $showEpisodesWhatsNew, onDismiss: {
            AppPersistentMemory.shared.hasSeenEpisodesWhatsNewScreen(true)
        }) {
            IntroducingEpisodesView(appMemory: AppPersistentMemory.shared)
        }
        .sheet(isPresented: $showTranscriptsWhatsNew, onDismiss: {
            AppPersistentMemory.shared.hasSeenTranscriptsWhatsNewScreen(true)
        }) {
            IntroducingTranscriptsView(appMemory: AppPersistentMemory.shared)
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environment(episodePlayer)
                .environment(episodeBookmarkStore)
        }
        .sheet(isPresented: $episodePlayer.showSupportPrompt, onDismiss: {
            let memory = AppPersistentMemory.shared
            memory.setHasSeenEpisodeSupportPrompt(true)
            memory.setLastSupportPromptDate(Date())
        }) {
            SupportPromptView(
                onSupport: {
                    let memory = AppPersistentMemory.shared
                    memory.setHasSeenEpisodeSupportPrompt(true)
                    memory.setLastSupportPromptDate(Date())
                    episodePlayer.showSupportPrompt = false
                    Task {
                        await AnalyticsService().send(
                            originatingScreen: "SupportPrompt",
                            action: "support_prompt_tapped(trigger=episodes)"
                        )
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShowingSupportSheet = true
                    }
                },
                onDismiss: {
                    let memory = AppPersistentMemory.shared
                    memory.setHasSeenEpisodeSupportPrompt(true)
                    memory.setLastSupportPromptDate(Date())
                    episodePlayer.showSupportPrompt = false
                    Task {
                        await AnalyticsService().send(
                            originatingScreen: "SupportPrompt",
                            action: "support_prompt_dismissed(trigger=episodes)"
                        )
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .onAppear {
                Task {
                    await AnalyticsService().send(
                        originatingScreen: "SupportPrompt",
                        action: "support_prompt_shown(trigger=episodes)"
                    )
                }
            }
        }
    }

    // MARK: - Functions

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

    private func displayEpisodesWhatsNewIfNeeded() {
        guard AppPersistentMemory.shared.hasShownNotificationsOnboarding() else { return }
        guard !AppPersistentMemory.shared.hasSeenEpisodesWhatsNewScreen() else { return }

        showEpisodesWhatsNew = true
    }

    private func displayTranscriptsWhatsNewIfNeeded() {
        guard FeatureFlag.isEnabled(.projectEleDisseIssoMesmo) else { return }
        guard AppPersistentMemory.shared.hasShownNotificationsOnboarding() else { return }
        guard AppPersistentMemory.shared.hasSeenEpisodesWhatsNewScreen() else { return }
        guard !AppPersistentMemory.shared.hasSeenTranscriptsWhatsNewScreen() else { return }

        showTranscriptsWhatsNew = true
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
}
