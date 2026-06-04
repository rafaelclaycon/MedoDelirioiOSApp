//
//  ContentGrid.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI
import UIKit

/// A generic view that displays a list of sounds with customizable states for loading, empty, and error conditions.
///
/// `ContentGrid` supports various customization options, including search functionality, multi-selection, and conditional UI elements like
/// sound counts, explicit content warnings, and more. It relies on `ContentGridViewModel` to manage its data and state.
///
/// - Parameters:
///   - authorId: The author's ID when `ContentGrid` is inside `AuthorDetailView`. This is used to avoid reopening the same author more than once when a user taps the author's name in `ContentDetailView`.
///   - LoadingView: A view shown when data is loading.
///   - EmptyStateView: A view displayed when there are no sounds to show.
///   - ErrorView: A view displayed when data loading fails.
struct ContentGrid<
    LoadingView: View,
    EmptyStateView: View,
    ErrorView: View
>: View {

    // MARK: - Dependencies

    private var state: LoadingState<[AnyEquatableMedoContent]>
    @State private var viewModel: ContentGridViewModel
    private var toast: Binding<Toast?>
    private var searchTextIsEmpty: Binding<Bool?>
    private let allowSearch: Bool
    private let showNewTag: Bool
    private let isFavoritesOnlyView: Bool
    private let authorId: String?
    private let reactionId: String?
    private let containerSize: CGSize
    private let scrollViewProxy: ScrollViewProxy?

    @ViewBuilder private let loadingView: LoadingView
    @ViewBuilder private let emptyStateView: EmptyStateView
    @ViewBuilder private let errorView: ErrorView

    // MARK: - Stored Properties

    @State private var columns: [GridItem] = []
    private let phoneItemSpacing: CGFloat = 9
    private let padItemSpacing: CGFloat = 14
    @State private var showMultiSelectButtons: Bool = false
    @State private var multiSelectButtonsEnabled: Bool = false
    @State private var allSelectedAreFavorites: Bool = false

    // MARK: - Computed Properties

    private var searchResults: [AnyEquatableMedoContent] {
        switch state {
        case .loaded(let content):
            if viewModel.searchText.isEmpty {
                return content
            } else {
                return content.filter { item in
                    let searchString = "\(item.description.lowercased().withoutDiacritics()) \(item.subtitle.lowercased().withoutDiacritics())"
                    return searchString.contains(viewModel.searchText.lowercased().withoutDiacritics())
                }
            }
        case .loading, .error:
            return []
        }
    }

    // MARK: - Environment

    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.push) private var push

    // MARK: - Initializer

    init(
        state: LoadingState<[AnyEquatableMedoContent]>,
        viewModel: ContentGridViewModel,
        toast: Binding<Toast?>,

        searchTextIsEmpty: Binding<Bool?> = .constant(nil),
        allowSearch: Bool = false,
        showNewTag: Bool = true,
        isFavoritesOnlyView: Bool = false,
        authorId: String? = nil,
        reactionId: String? = nil,
        containerSize: CGSize,
        scrollViewProxy: ScrollViewProxy? = nil,

        loadingView: LoadingView,
        emptyStateView: EmptyStateView,
        errorView: ErrorView
    ) {
        self.state = state
        self.viewModel = viewModel
        self.toast = toast
        self.searchTextIsEmpty = searchTextIsEmpty
        self.allowSearch = allowSearch
        self.showNewTag = showNewTag
        self.isFavoritesOnlyView = isFavoritesOnlyView
        self.authorId = authorId
        self.reactionId = reactionId
        self.containerSize = containerSize
        self.scrollViewProxy = scrollViewProxy
        self.loadingView = loadingView
        self.emptyStateView = emptyStateView
        self.errorView = errorView
    }

    // MARK: - View Body

    var body: some View {
        switch state {
        case .loading:
            loadingView

        case .loaded(let loadedContent):
            if loadedContent.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: UIDevice.isiPhone ? phoneItemSpacing : padItemSpacing) {
                    if searchResults.isEmpty {
                        NoSearchResultsView(searchText: viewModel.searchText)
                    } else {
                        ForEach(searchResults) { content in
                            Group {
                                if FeatureFlag.isEnabled(.novoVisualGradeConteudos) {
                                    ModernContent.Button(
                                        content: content,
                                        showNewTag: showNewTag,
                                        favorites: viewModel.favoritesKeeper,
                                        highlighted: viewModel.highlightKeeper,
                                        nowPlaying: viewModel.nowPlayingKeeper,
                                        selectedItems: viewModel.selectionKeeper,
                                        currentContentListMode: viewModel.currentListMode
                                    )
                                } else {
                                    PlayableContentView(
                                        content: content,
                                        showNewTag: showNewTag,
                                        favorites: viewModel.favoritesKeeper,
                                        highlighted: viewModel.highlightKeeper,
                                        nowPlaying: viewModel.nowPlayingKeeper,
                                        selectedItems: viewModel.selectionKeeper,
                                        currentContentListMode: viewModel.currentListMode
                                    )
                                }
                            }
                            .contentShape(
                                .contextMenuPreview,
                                RoundedRectangle(cornerRadius: FeatureFlag.isEnabled(.novoVisualGradeConteudos) ? 18 : .spacing(.large), style: .continuous)
                            )
                            .onTapGesture {
                                viewModel.onContentSelected(content, loadedContent: loadedContent)
                            }
                            .contextMenu {
                                if viewModel.currentListMode.wrappedValue != .selection {
                                    contextMenuOptionsView(
                                        content: content,
                                        menuOptions: viewModel.menuOptions,
                                        favorites: viewModel.favoritesKeeper,
                                        loadedContent: loadedContent
                                    )
                                }
                            } preview: {
                                ModernContent.Preview(content: content)
                            }
                        }
                    }
                }
                .if(allowSearch) {
                    $0
                        .searchable(text: $viewModel.searchText)
                        .disableAutocorrection(true)
                }
                // Grid-specific alerts (folder operations)
                .alert(isPresented: $viewModel.showAlert) {
                    switch viewModel.alertType {
                    case .issueExportingManySounds, .issueRemovingContentFromFolder:
                        return Alert(
                            title: Text(viewModel.alertTitle),
                            message: Text(viewModel.alertMessage),
                            dismissButton: .default(Text("OK"))
                        )

                    case .removeSingleContent:
                        return Alert(
                            title: Text(viewModel.alertTitle),
                            message: Text(viewModel.alertMessage),
                            primaryButton: .destructive(
                                Text("Remover"),
                                action: { viewModel.onRemoveSingleContentSelected() }
                            ),
                            secondaryButton: .cancel(Text("Cancelar"))
                        )

                    case .removeMultipleContent:
                        return Alert(
                            title: Text(viewModel.alertTitle),
                            message: Text(viewModel.alertMessage),
                            primaryButton: .destructive(
                                Text("Remover"),
                                action: { Task { await viewModel.onRemoveMultipleContentSelected() } }
                            ),
                            secondaryButton: .cancel(Text("Cancelar"))
                        )
                    }
                }
                // Playable content UI (alerts for content not found, sheets for share/detail)
                .playableContentUI(
                    state: viewModel.playable,
                    toast: toast,
                    authorId: authorId,
                    reactionId: reactionId,
                    onAuthorSelected: { author in
                        push(GeneralNavigationDestination.authorDetail(author))
                    },
                    onReactionSelected: { reaction in
                        push(GeneralNavigationDestination.reactionDetail(reaction))
                    }
                )
                .onChange(of: viewModel.searchText) {
                    searchTextIsEmpty.wrappedValue = viewModel.searchText.isEmpty
                }
                .onChange(of: viewModel.activeSheet) {
                    if viewModel.activeSheet != nil {
                        if case .addToFolder = viewModel.activeSheet {
                            // Dismiss keyboard when Add to Folder sheet is presented
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
                .onChange(of: containerSize.width) {
                    updateGridLayout()
                }
                .onChange(of: searchResults) {
                    if searchResults.isEmpty {
                        columns = [GridItem(.flexible())]
                    } else {
                        updateGridLayout()
                    }
                }
                .onChange(of: viewModel.selectionKeeper.count) {
                    viewModel.onItemSelectionChanged()
                }
                .onChange(of: viewModel.scrollTo) {
                    if !viewModel.scrollTo.isEmpty {
                        withAnimation {
                            scrollViewProxy?.scrollTo(viewModel.scrollTo, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    viewModel.onViewAppeared()
                    updateGridLayout()
                }
            }

        case .error(_):
            errorView
        }
    }

    // MARK: - Subviews

    @MainActor @ViewBuilder
    private func contextMenuOptionsView(
        content: AnyEquatableMedoContent,
        menuOptions: [ContextMenuSection],
        favorites: Set<String>,
        loadedContent: [AnyEquatableMedoContent]
    ) -> some View {
        ForEach(menuOptions, id: \.title) { section in
            Section {
                ForEach(section.options(content)) { option in
                    if option.appliesTo.contains(content.type) {
                        optionRow(
                            option: option,
                            isFavorite: favorites.contains(content.id),
                            content: content,
                            loadedContent: loadedContent
                        )
                    }
                }
            }
        }
    }

    @MainActor
    @ViewBuilder
    private func optionRow(
        option: ContextMenuOption,
        isFavorite: Bool,
        content: AnyEquatableMedoContent,
        loadedContent: [AnyEquatableMedoContent]
    ) -> some View {
        let optionTitle = option.title(isFavorite)

        Button {
            option.action(
                viewModel,
                ContextMenuPassthroughData(
                    selectedContent: content,
                    loadedContent: loadedContent,
                    isFavoritesOnlyView: isFavoritesOnlyView
                )
            )
        } label: {
            Label(optionTitle, systemImage: option.symbol(isFavorite))
        }
    }

    // MARK: - Functions

    private func updateGridLayout() {
        columns = GridHelper.adaptableColumns(
            listWidth: containerSize.width,
            sizeCategory: sizeCategory,
            spacing: UIDevice.isiPhone ? phoneItemSpacing : padItemSpacing
        )
    }
}

// MARK: - Preview

#Preview {
    ContentGrid(
        state: .loading,
        viewModel: ContentGridViewModel(
            contentRepository: FakeContentRepository(),
            userFolderRepository: UserFolderRepository(database: LocalDatabase()),
            contentFileManager: ContentFileManager(),
            screen: .mainContentView,
            menuOptions: [.sharingOptions()],
            currentListMode: .constant(.regular),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            analyticsService: AnalyticsService()
        ),
        toast: .constant(nil),
        containerSize: CGSize(width: 390, height: 1200),
        loadingView: BasicLoadingView(text: "Carregando Conteúdos..."),
        emptyStateView: Text("No Sounds to Display"),
        errorView: Text("Error")
    )
    .padding(.horizontal, .spacing(.medium))
}
