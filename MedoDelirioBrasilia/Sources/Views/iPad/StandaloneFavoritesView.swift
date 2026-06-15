//
//  StandaloneFavoritesView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/04/25.
//

import SwiftUI

struct StandaloneFavoritesView: View {

    @State private var viewModel: StandaloneFavoritesViewModel
    @State private var contentGridViewModel: ContentGridViewModel
    
    private var currentContentListMode: Binding<ContentGridMode>
    private let openSettingsAction: () -> Void

    @State private var soundSearchTextIsEmpty: Bool? = true

    private var loadedContent: [AnyEquatableMedoContent] {
        guard case .loaded(let content) = viewModel.state else { return [] }
        return content
    }

    // MARK: - Initializer

    init(
        viewModel: StandaloneFavoritesViewModel,
        currentContentListMode: Binding<ContentGridMode>,
        openSettingsAction: @escaping () -> Void,
        contentRepository: ContentRepositoryProtocol
    ) {
        self.viewModel = viewModel
        self.currentContentListMode = currentContentListMode
        self.openSettingsAction = openSettingsAction
        self.contentGridViewModel = ContentGridViewModel(
            contentRepository: contentRepository,
            userFolderRepository: UserFolderRepository(database: LocalDatabase.shared),
            contentFileManager: ContentFileManager(),
            screen: .standaloneFavoritesView,
            menuOptions: [.sharingOptions(), .organizingOptions(), .detailsOptions()],
            currentListMode: .constant(.regular),
            toast: viewModel.toast,
            floatingOptions: viewModel.floatingOptions,
            refreshAction: viewModel.onFavoriteRemoved,
            analyticsService: AnalyticsService()
        )
    }

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: .spacing(.xSmall)) {
                    ContentGrid(
                        state: viewModel.state,
                        viewModel: contentGridViewModel,
                        toast: viewModel.toast,
                        isFavoritesOnlyView: true,
                        containerSize: geometry.size,
                        loadingView:
                            VStack {
                                HStack(spacing: 10) {
                                    ProgressView()

                                    Text("Carregando Conteúdos...")
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        ,
                        emptyStateView:
                            VStack {
                                NoFavoritesView()
                                    .padding(.horizontal, .spacing(.xLarge))
                                    .padding(.vertical, .spacing(.huge))
                            }
                        ,
                        errorView: VStack { ContentLoadErrorView() }
                    )

                    Spacer()
                        .frame(height: .spacing(.large))
                }
                .padding(.horizontal, .spacing(.medium))
                .navigationTitle(Text("Favoritos"))
                .toolbar {
                    LeadingToolbarControls(
                        isSelecting: currentContentListMode.wrappedValue == .selection,
                        cancelAction: { contentGridViewModel.onExitMultiSelectModeSelected() },
                        openSettingsAction: openSettingsAction
                    )

                    ContentToolbarOptionsView(
                        contentSortOption: $viewModel.contentSortOption,
                        contentListMode: currentContentListMode.wrappedValue,
                        multiSelectAction: {
                            contentGridViewModel.onEnterMultiSelectModeSelected(
                                loadedContent: loadedContent,
                                isFavoritesOnlyView: true
                            )
                        },
                        contentSortChangeAction: {
                            viewModel.onContentSortOptionChanged()
                        }
                    )
                }
                .onAppear {
                    viewModel.onViewDidAppear()
                }
            }
            .toast(contentGridViewModel.toast)
            .floatingContentOptions(contentGridViewModel.floatingOptions)
        }
    }
}

