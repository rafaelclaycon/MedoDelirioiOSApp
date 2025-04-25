//
//  MainView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 19/05/22.
//

import SwiftUI

struct MainView: View {

    @Binding var tabSelection: PhoneTab
    @Binding var padSelection: PadScreen?

    @State private var soundsPath = NavigationPath()
    @State private var favoritesPath = NavigationPath()
    @State private var reactionsPath = NavigationPath()
    @State private var authorsPath = NavigationPath()
    @State private var foldersPath = NavigationPath()
    @State private var episodesPath = NavigationPath()

    @State private var isShowingSettingsSheet: Bool = false
    @StateObject private var settingsHelper = SettingsHelper()
    @State private var folderForEditing: UserFolder?
    @State private var updateFolderList: Bool = false
    @State private var currentSoundsListMode: SoundsListMode = .regular

    @State private var subviewToOpen: MainViewModalToOpen = .onboarding
    @State private var showingModalView: Bool = false

    // iPad
    @StateObject private var viewModel = SidebarViewViewModel()
    @State private var authorSortOption: Int = 0
    @State private var authorSortAction: AuthorSortOption = .nameAscending

    // Trends
    @State private var soundIdToGoToFromTrends: String = .empty
    @State private var trendsHelper = TrendsHelper()

    // Sync
    @StateObject private var syncValues = SyncValues()

    // Podcast Episodes
    @StateObject private var episodesViewModel = EpisodesView.ViewModel(episodeRepository: EpisodeRepository())

    // MARK: - View Body

    var body: some View {
        ZStack {
            if UIDevice.isiPhone {
                TabView(selection: $tabSelection) {
                    NavigationStack(path: $soundsPath) {
                        MainSoundContainer(
                            viewModel: .init(
                                currentViewMode: .allSounds,
                                soundSortOption: UserSettings().mainSoundListSoundSortOption(),
                                authorSortOption: UserSettings().authorSortOption(),
                                currentSoundsListMode: $currentSoundsListMode,
                                syncValues: syncValues
                            ),
                            currentSoundsListMode: $currentSoundsListMode,
                            openSettingsAction: {
                                isShowingSettingsSheet.toggle()
                            }
                        )
                        .environment(trendsHelper)
                        .environmentObject(settingsHelper)
                        .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                            GeneralRouter(destination: screen)
                        }
                    }
                    .tabItem {
                        Label("Sons", systemImage: "speaker.wave.3.fill")
                    }
                    .tag(PhoneTab.sounds)
                    .environment(\.push, PushAction { soundsPath.append($0) })

                    NavigationStack(path: $reactionsPath) {
                        ReactionsView()
                            .environment(trendsHelper)
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen)
                            }
                    }
                    .tabItem {
                        Label("Reações", systemImage: "rectangle.grid.2x2.fill")
                    }
                    .tag(PhoneTab.reactions)
                    .environment(\.push, PushAction { reactionsPath.append($0) })

                    NavigationView {
                        SongsView()
                            .environmentObject(settingsHelper)
                            .environment(trendsHelper)
                    }
                    .tabItem {
                        Label("Músicas", systemImage: "music.quarternote.3")
                    }
                    .tag(PhoneTab.songs)

                    NavigationStack(path: $episodesPath) {
                        NowPlayingBar(
                            content: EpisodesView(viewModel: episodesViewModel),
                            currentState: episodesViewModel.playerState,
                            playButtonAction: { episodesViewModel.onPlayPauseButtonSelected() }
                        )
                        .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                            GeneralRouter(destination: screen)
                        }
                    }
                    .tabItem {
                        Label("Episódios", systemImage: "rectangle.stack.fill")
                    }
                    //.tag(PhoneTab.songs)
                    .environment(\.push, PushAction { episodesPath.append($0) })

                    NavigationView {
                        TrendsView(
                            tabSelection: $tabSelection,
                            activePadScreen: .constant(.trends)
                        )
                        .environment(trendsHelper)
                    }
                    .tabItem {
                        Label("Tendências", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(PhoneTab.trends)
                }
                .onContinueUserActivity(Shared.ActivityTypes.playAndShareSounds, perform: { _ in
                    tabSelection = .sounds
                })
                //            .onContinueUserActivity(Shared.ActivityTypes.viewCollections, perform: { _ in
                //                tabSelection = .collections
                //            })
                .onContinueUserActivity(Shared.ActivityTypes.playAndShareSongs, perform: { _ in
                    tabSelection = .songs
                })
                .onContinueUserActivity(Shared.ActivityTypes.viewLast24HoursTopChart, perform: { _ in
                    tabSelection = .trends
                    trendsHelper.timeIntervalToGoTo = .last24Hours
                })
                .onContinueUserActivity(Shared.ActivityTypes.viewLastWeekTopChart, perform: { _ in
                    tabSelection = .trends
                    trendsHelper.timeIntervalToGoTo = .lastWeek
                })
                .onContinueUserActivity(Shared.ActivityTypes.viewLastMonthTopChart, perform: { _ in
                    tabSelection = .trends
                    trendsHelper.timeIntervalToGoTo = .lastMonth
                })
                .onContinueUserActivity(Shared.ActivityTypes.viewAllTimeTopChart, perform: { _ in
                    tabSelection = .trends
                    trendsHelper.timeIntervalToGoTo = .allTime
                })
            } else {
                if #available(iOS 18, *) {
                    TabView {
                        Tab("Sons", systemImage: "speaker.wave.2") {
                            NavigationStack(path: $soundsPath) {
                                MainSoundContainer(
                                    viewModel: .init(
                                        currentViewMode: .allSounds,
                                        soundSortOption: UserSettings().mainSoundListSoundSortOption(),
                                        authorSortOption: UserSettings().authorSortOption(),
                                        currentSoundsListMode: $currentSoundsListMode,
                                        syncValues: syncValues
                                    ),
                                    currentSoundsListMode: $currentSoundsListMode,
                                    openSettingsAction: {}
                                )
                                .environment(trendsHelper)
                                .environmentObject(settingsHelper)
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen)
                                }
                            }
                            .environment(\.push, PushAction { soundsPath.append($0) })
                        }

                        Tab("Favoritos", systemImage: "star") {
                            NavigationStack(path: $favoritesPath) {
                                MainSoundContainer(
                                    viewModel: .init(
                                        currentViewMode: .favorites,
                                        soundSortOption: UserSettings().mainSoundListSoundSortOption(),
                                        authorSortOption: UserSettings().authorSortOption(),
                                        currentSoundsListMode: $currentSoundsListMode,
                                        syncValues: syncValues,
                                        isAllowedToSync: false
                                    ),
                                    currentSoundsListMode: $currentSoundsListMode,
                                    openSettingsAction: {}
                                )
                                .environment(trendsHelper)
                                .environmentObject(settingsHelper)
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen)
                                }
                            }
                            .environment(\.push, PushAction { favoritesPath.append($0) })
                        }

                        Tab("Reações", systemImage: "rectangle.grid.2x2") {
                            NavigationStack(path: $reactionsPath) {
                                ReactionsView()
                                    .environment(trendsHelper)
                                    .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                        GeneralRouter(destination: screen)
                                    }
                            }
                            .environment(\.push, PushAction { reactionsPath.append($0) })
                        }

                        Tab("Autores", systemImage: "person") {
                            NavigationStack(path: $authorsPath) {
                                AuthorsView(
                                    sortOption: $authorSortOption,
                                    sortAction: $authorSortAction,
                                    searchTextForControl: .constant("")
                                )
                                .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                    GeneralRouter(destination: screen)
                                }
                            }
                            .environment(\.push, PushAction { authorsPath.append($0) })
                        }

                        Tab("Tendências", systemImage: "chart.line.uptrend.xyaxis") {
                            NavigationStack {
                                TrendsView(
                                    tabSelection: $tabSelection,
                                    activePadScreen: .constant(.trends)
                                )
                                .environment(trendsHelper)
                            }
                        }

                        TabSection("Mais") {
                            Tab("Músicas", systemImage: "music.quarternote.3") {
                                NavigationStack {
                                    SongsView()
                                        .environmentObject(settingsHelper)
                                        .environment(trendsHelper)
                                }
                            }
                        }

                        TabSection("Minhas Pastas") {
                            Tab("Todas as Pastas", systemImage: "folder") {
                                NavigationStack(path: $foldersPath) {
                                    AllFoldersiPadView(
                                        folderForEditing: $folderForEditing,
                                        updateFolderList: $updateFolderList
                                    )
                                    .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                        GeneralRouter(destination: screen)
                                    }
                                }
                                .environment(\.push, PushAction { foldersPath.append($0) })
                            }

                            ForEach(viewModel.folders) { folder in
                                Tab {
                                    NavigationStack {
                                        FolderDetailView(
                                            folder: folder,
                                            currentSoundsListMode: $currentSoundsListMode
                                        )
                                    }
                                } label: {
                                    Text("\(folder.symbol)   \(folder.name)")
                                        .padding()
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
                        viewModel.reloadFolderList(withFolders: try? LocalDatabase.shared.allFolders())
                    }
                } else {
                    NavigationSplitView {
                        SidebarView(
                            state: $padSelection,
                            isShowingSettingsSheet: $isShowingSettingsSheet,
                            folderForEditing: $folderForEditing,
                            updateFolderList: $updateFolderList,
                            currentSoundsListMode: $currentSoundsListMode
                        )
                        .environment(trendsHelper)
                        .environmentObject(settingsHelper)
                        .environmentObject(syncValues)
                    } detail: {
                        NavigationStack(path: $soundsPath) {
                            MainSoundContainer(
                                viewModel: .init(
                                    currentViewMode: .allSounds,
                                    soundSortOption: UserSettings().mainSoundListSoundSortOption(),
                                    authorSortOption: AuthorSortOption.nameAscending.rawValue,
                                    currentSoundsListMode: $currentSoundsListMode,
                                    syncValues: syncValues
                                ),
                                currentSoundsListMode: $currentSoundsListMode,
                                openSettingsAction: {}
                            )
                            .environment(trendsHelper)
                            .environmentObject(settingsHelper)
                            .navigationDestination(for: GeneralNavigationDestination.self) { screen in
                                GeneralRouter(destination: screen)
                            }
                            .environment(\.push, PushAction { soundsPath.append($0) })
                        }
                    }
                }
            }
        }
        .environmentObject(syncValues)
        .onAppear {
            print("MAIN VIEW - ON APPEAR")
            sendUserPersonalTrendsToServerIfEnabled()
            displayOnboardingIfNeeded()
        }
        .sheet(isPresented: $showingModalView) {
            switch subviewToOpen {
            case .settings:
                SettingsCasingWithCloseView(isBeingShown: $showingModalView)
                    .environmentObject(settingsHelper)

            case .onboarding:
                FirstOnboardingView(isBeingShown: $showingModalView)
                    .interactiveDismissDisabled(UIDevice.current.userInterfaceIdiom == .phone ? true : false)

            case .whatsNew:
                IntroducingReactionsView()
                    .interactiveDismissDisabled()

            case .retrospective:
                EmptyView()
            }
        }
        .sheet(item: $folderForEditing) { folder in
            FolderInfoEditingView(
                folder: folder,
                folderRepository: UserFolderRepository(),
                dismissSheet: {
                    folderForEditing = nil
                    updateFolderList = true
                }
            )
        }
        // Could be removed in the future, but for now using `showingModalView` bugs out on iPad. Shows Onboarding most of the time.
        .sheet(isPresented: $isShowingSettingsSheet) {
            SettingsCasingWithCloseView(isBeingShown: $isShowingSettingsSheet)
                .environmentObject(settingsHelper)
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

            if let lastDate = AppPersistentMemory().getLastSendDateOfUserPersonalTrendsToServer() {
                if lastDate.onlyDate! < Date.now.onlyDate! {
                    let result = await Podium.shared.sendShareCountStatsToServer()

                    guard result == .successful || result == .noStatsToSend else {
                        return
                    }
                    AppPersistentMemory().setLastSendDateOfUserPersonalTrendsToServer(to: Date.now.onlyDate!)
                }
            } else {
                let result = await Podium.shared.sendShareCountStatsToServer()

                guard result == .successful || result == .noStatsToSend else {
                    return
                }
                AppPersistentMemory().setLastSendDateOfUserPersonalTrendsToServer(to: Date.now.onlyDate!)
            }
        }
    }

    private func displayOnboardingIfNeeded() {
        if !AppPersistentMemory().hasShownNotificationsOnboarding() {
            subviewToOpen = .onboarding
            showingModalView = true
        } else if !AppPersistentMemory().hasSeenReactionsWhatsNewScreen(), UIDevice.isiPhone {
            subviewToOpen = .whatsNew
            showingModalView = true
        }
    }
}

// MARK: - Preview

#Preview {
    MainView(
        tabSelection: .constant(.sounds),
        padSelection: .constant(.allSounds)
    )
}
