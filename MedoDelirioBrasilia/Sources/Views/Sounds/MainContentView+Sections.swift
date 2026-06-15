//
//  MainContentView+Sections.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

// MARK: - Body Sections

extension MainContentView {

    @ViewBuilder
    var contentModePicker: some View {
        if currentContentListMode.wrappedValue == .regular {
            ContentModePicker(
                options: UIDevice.deviceType == .iPhone ? ContentModeOption.allCases : [.all, .songs],
                selected: $viewModel.currentViewMode,
                allowScrolling: UIDevice.deviceType == .iPhone
            )
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    func soundsContent(geometry: GeometryProxy, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: .spacing(.xSmall)) {
            VStack(spacing: .spacing(.xSmall)) {
                if viewModel.displayLongUpdateBanner {
                    LongUpdateBanner(
                        completedNumber: viewModel.contentUpdateService.processedUpdateNumber,
                        totalUpdateCount: viewModel.contentUpdateService.totalUpdateCount,
                        estimatedSecondsRemaining: viewModel.contentUpdateService.estimatedSecondsRemaining
                    )
                }

                if viewModel.currentViewMode == .all {
                    BannersView(
                        bannerRepository: bannerRepository,
                        toast: viewModel.toast
                    )
                }
            }

            ContentGrid(
                state: viewModel.state,
                viewModel: contentGridViewModel,
                toast: viewModel.toast,
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

            if
                viewModel.currentViewMode == .all,
                !UserSettings().getShowExplicitContent()
            {
                ExplicitDisabledWarning(
                    text: UIDevice.deviceType == .iPhone ? Shared.contentFilterMessageForSoundsiPhone : Shared.contentFilterMessageForSoundsiPadMac
                )
                .padding(.top, explicitOffWarningTopPadding)
            }

            if
                viewModel.currentViewMode == .all,
                loadedContent.count > 0
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
    }

    @ViewBuilder
    func foldersContent(geometry: GeometryProxy) -> some View {
        MyFoldersiPhoneView(
            contentRepository: contentRepository,
            userFolderRepository: userFolderRepository,
            containerSize: geometry.size
        )
        .environment(deleteFolderAide)
        .padding(.horizontal, .spacing(.medium))
    }

    @ViewBuilder
    func authorsContent(geometry: GeometryProxy) -> some View {
        AuthorsGrid(
            viewModel: authorsGridViewModel,
            containerWidth: geometry.size.width
        )
        .padding(.horizontal, .spacing(.medium))
    }

    // MARK: - Scroll Content

    @ViewBuilder
    func scrollContent(geometry: GeometryProxy, proxy: ScrollViewProxy) -> some View {
        scrollContentCore(geometry: geometry, proxy: proxy)
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
            .onChange(of: settingsHelper.updateSoundsList) {
                if settingsHelper.updateSoundsList {
                    viewModel.onExplicitContentSettingChanged()
                    settingsHelper.updateSoundsList = false
                }
            }
            .onChange(of: trendsHelper.contentIdToNavigateTo) {
                highlight(contentId: trendsHelper.contentIdToNavigateTo)
            }
            .task {
                await viewModel.onViewDidAppear()
            }
            .onChange(of: scenePhase) {
                Task {
                    await viewModel.onScenePhaseChanged(newPhase: scenePhase)
                }
            }
    }

    @ViewBuilder
    private func scrollContentCore(geometry: GeometryProxy, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: .spacing(.xSmall)) {
            contentModePicker

            switch viewModel.currentViewMode {
            case .all, .favorites, .songs:
                soundsContent(geometry: geometry, proxy: proxy)
            case .folders:
                foldersContent(geometry: geometry)
            case .authors:
                authorsContent(geometry: geometry)
            }
        }
        // Lets the Folders empty state center itself in the visible area below the picker.
        .frame(minHeight: viewModel.currentViewMode == .folders ? geometry.size.height : nil)
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
                matchedTransitionNamespace: namespace
            )
        }
    }
}
