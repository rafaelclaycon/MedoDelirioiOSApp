//
//  FolderDetailView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI

struct FolderDetailView: View {

    @State private var viewModel: FolderDetailViewModel
    @State private var contentGridViewModel: ContentGridViewModel

    /// `@State`, not `let`: editing the folder's name/emoji/color happens in a sheet
    /// that owns its own copy (`FolderInfoEditingView.ViewModel`), so this has to be
    /// re-fetched after the sheet closes rather than mutated in place.
    @State private var folder: UserFolder

    private var currentContentListMode: Binding<ContentGridMode>
    @State private var showingFolderInfoEditingView = false
    @State private var showingModalView = false

    // MARK: - Computed Properties

    private var showSortByDateAddedOption: Bool {
        guard let folderVersion = folder.version else { return false }
        return folderVersion == "2"
    }
    
    private var title: String {
        guard currentContentListMode.wrappedValue == .regular else {
            if contentGridViewModel.selectionKeeper.count == 0 {
                return Shared.SoundSelection.selectSounds
            } else if contentGridViewModel.selectionKeeper.count == 1 {
                return Shared.SoundSelection.soundSelectedSingular
            } else {
                return String(format: Shared.SoundSelection.soundsSelectedPlural, contentGridViewModel.selectionKeeper.count)
            }
        }
        return "\(folder.symbol)  \(folder.name)"
    }

    private var loadedContent: [AnyEquatableMedoContent] {
        guard case .loaded(let content) = viewModel.state else { return [] }
        return content
    }

    // MARK: - Initializer

    init(
        viewModel: FolderDetailViewModel,
        folder: UserFolder,
        currentContentListMode: Binding<ContentGridMode>,
        toast: Binding<Toast?>,
        floatingOptions: Binding<FloatingContentOptions?>,
        contentRepository: ContentRepositoryProtocol
    ) {
        _folder = State(initialValue: folder)

        self.viewModel = viewModel
        self.currentContentListMode = currentContentListMode

        self.contentGridViewModel = ContentGridViewModel(
            contentRepository: contentRepository,
            userFolderRepository: UserFolderRepository(database: LocalDatabase.shared),
            contentFileManager: ContentFileManager(),
            screen: .folderDetailView,
            menuOptions: [.sharingOptions(), .playFromThisSound(), .removeFromFolder()],
            currentListMode: currentContentListMode,
            toast: toast,
            floatingOptions: floatingOptions,
            refreshAction: { viewModel.onContentWasRemovedFromFolder() },
            insideFolder: folder,
            multiSelectFolderOperation: .remove,
            analyticsService: AnalyticsService()
        )
    }

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            if #available(iOS 26.0, *) {
                ScrollView {
                    detailView(size: geometry.size)
                        .toolbar {
                            ToolbarItem(id: "play-stop-button", placement: .topBarTrailing) {
                                if currentContentListMode.wrappedValue == .regular {
                                    playStopButton()
                                } else {
                                    selectionControls
                                }
                            }

                            ToolbarSpacer(.fixed, placement: .topBarTrailing)

                            ToolbarItem(id: "options-menu", placement: .topBarTrailing) {
                                optionsMenu()
                            }
                        }
                }
                .edgesIgnoringSafeArea(.top)
                .toast(contentGridViewModel.toast)
                .floatingContentOptions(contentGridViewModel.floatingOptions)
                // `toolbarVisibility`, not the older `toolbar(_:for:)` it deprecated:
                // the latter silently stops hiding iOS 26's redesigned tab bar, which
                // then sits on top of the selection options in the bottom bar.
                .toolbarVisibility(contentGridViewModel.tabBarVisibility, for: .tabBar)
                .scrollEdgeEffectHidden(true, for: .top)
            } else {
                ScrollView {
                    detailView(size: geometry.size)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                optionsMenu()
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                if currentContentListMode.wrappedValue == .regular {
                                    playStopButton()
                                } else {
                                    selectionControls
                                }
                            }
                        }
                }
                .edgesIgnoringSafeArea(.top)
                .toast(contentGridViewModel.toast)
                .floatingContentOptions(contentGridViewModel.floatingOptions)
                // `toolbarVisibility`, not the older `toolbar(_:for:)` it deprecated:
                // the latter silently stops hiding iOS 26's redesigned tab bar, which
                // then sits on top of the selection options in the bottom bar.
                .toolbarVisibility(contentGridViewModel.tabBarVisibility, for: .tabBar)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    func detailView(size: CGSize) -> some View {
        VStack(spacing: .spacing(.medium)) {
            HeaderView(
                folder: folder,
                itemCountText: viewModel.contentCountText
            )

            ContentGrid(
                state: viewModel.state,
                viewModel: contentGridViewModel,
                toast: contentGridViewModel.toast,
                showNewTag: false,
                containerSize: size,
                loadingView: ContentGridSkeletonView(containerSize: size),
                emptyStateView:
                    VStack {
                        EmptyFolderView()
                            .padding(.horizontal, .spacing(.xxLarge))
                            .padding(.vertical, .spacing(.huge))
                    }
                ,
                errorView:
                    VStack {
                        HStack(spacing: 10) {
                            ProgressView()

                            Text("Erro ao carregar sons.")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
            )
            .environment(TrendsHelper())
            .padding(.horizontal, .spacing(.medium))

            Spacer()
                .frame(height: .spacing(.large))
        }
        .onAppear {
            viewModel.onViewAppeared()
        }
        .onDisappear {
            contentGridViewModel.onViewDisappeared()
        }
        .sheet(isPresented: $showingFolderInfoEditingView) {
            FolderInfoEditingView(
                folder: folder,
                folderRepository: UserFolderRepository(database: LocalDatabase.shared),
                dismissSheet: {
                    showingFolderInfoEditingView = false
                    Task { await reloadFolder() }
                }
            )
        }
    }

    /// Picks up name/emoji/color changes made in the editing sheet. The sheet edits
    /// its own copy and only persists it to the repository on save, so this is the
    /// only way this view finds out — including finding out nothing changed, on
    /// cancel, which is harmless to re-fetch anyway.
    ///
    /// Updates `contentGridViewModel.folder` too, not just this view's own `folder` —
    /// it keeps an independent copy captured once at init, and its folder-removal
    /// paths persist that whole copy back to the repository. Leaving it stale meant
    /// removing a sound right after an edit silently reverted the edit.
    private func reloadFolder() async {
        let repository = UserFolderRepository(database: LocalDatabase.shared)
        guard let folders = try? await repository.allFolders(),
              let updated = folders.first(where: { $0.id == folder.id }) else {
            return
        }
        folder = updated
        contentGridViewModel.folder = updated
    }

    @ViewBuilder func playStopButton() -> some View {
        Button {
            contentGridViewModel.onPlayStopPlaylistSelected(loadedContent: loadedContent)
        } label: {
            Image(systemName: contentGridViewModel.isPlayingPlaylist ? "stop.fill" : "play.fill")
        }
        .disabled(viewModel.contentCount == 0)
    }
    
    @ViewBuilder func optionsMenu() -> some View {
        Menu {
            if currentContentListMode.wrappedValue == .regular {
                Section {
                    Button {
                        contentGridViewModel.onEnterMultiSelectModeSelected(
                            loadedContent: loadedContent,
                            isFavoritesOnlyView: false
                        )
                    } label: {
                        Label("Selecionar", systemImage: "checkmark.circle")
                    }
                }
            }

            Section {
                Picker("Ordenação", selection: $viewModel.contentSortOption) {
                    Text("Título")
                        .tag(0)

                    Text("Nome do Autor")
                        .tag(1)

                    if showSortByDateAddedOption {
                        Text("Adição à Pasta (Mais Recentes no Topo)")
                            .tag(2)
                    }
                }
                .onChange(of: viewModel.contentSortOption) {
                    contentGridViewModel.onContentSortingChanged()
                    viewModel.onContentSortOptionChanged()
                }
                .disabled(viewModel.contentCount == 0)
            }

            Section {
                Button {
                    showingFolderInfoEditingView = true
                } label: {
                    Label("Editar Pasta", systemImage: "pencil")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    var selectionControls: some View {
        Button {
            // Rather than clearing the list mode and selection by hand: leaving
            // selection also has to drop the floating options — the bottom bar is
            // rendered from them, so it lingers otherwise — along with the pending
            // multi-selection and the tab bar override.
            contentGridViewModel.onExitMultiSelectModeSelected()
        } label: {
            Text("Cancelar")
        }
    }
}

// MARK: - Subviews

extension FolderDetailView {

    /// Same stretch-on-pull technique as `AuthorHeaderView.StickyPhotoView`: grows
    /// upward into the overscroll gap on pull-down, scrolls normally otherwise.
    struct StickyFolderBackgroundView: View {

        let color: Color
        let height: CGFloat

        // MARK: - View Body

        var body: some View {
            GeometryReader { proxy in
                let offset = proxy.frame(in: .global).minY
                // Only stretch when the scroll view is pulled down past the top.
                let extraHeight = max(0, offset)

                Color.clear
                    .frame(width: proxy.size.width, height: height + extraHeight)
                    .background {
                        // The background-extension effect must wrap the *fill*, not
                        // the grow/offset transform. On iOS 26 applying it after the
                        // offset pins the fill and kills the stretch.
                        if #available(iOS 26.0, *) {
                            colorfulFill
                                .backgroundExtensionEffect()
                        } else {
                            colorfulFill
                        }
                    }
                    .clipped()
                    .offset(y: -extraHeight)
            }
            .frame(height: height)
            // Clip the bottom (so the fill / background-extension effect can't leak
            // into the content below) while leaving the top open, so the fill can
            // still stretch upward to fill the overscroll gap on pull.
            .clipShape(TopOpenRectangle())
        }

        private var colorfulFill: some View {
            Rectangle()
                .fill(color)
                .overlay { FolderView.SpeckleOverlay() }
        }
    }

    struct HeaderView: View {

        let folder: UserFolder
        let itemCountText: String

        /// Status bar / notch / Dynamic Island inset. The header ignores the top safe
        /// area (`FolderDetailView.body`) so its background can bleed under the status
        /// bar, which means nothing here does this accounting automatically anymore —
        /// the emoji/title block has to steer clear of that region itself.
        private var topSafeAreaInset: CGFloat {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return 0
            }
            return window.safeAreaInsets.top
        }

        /// Standard navigation bar height, on top of the safe area inset above — the
        /// floating toolbar (back button, play, Selecionar, sort) occupies this too.
        private let toolbarHeight: CGFloat = 44

        var body: some View {
            StickyFolderBackgroundView(
                color: folder.backgroundColor.toPastelColor(),
                height: 230
            )
            .overlay {
                VStack(spacing: .zero) {
                    // Fixed, not part of the centering: reserves the toolbar's own
                    // space so the two flexible spacers below center the text in
                    // what's actually left over, not the header's full height.
                    Spacer()
                        .frame(height: topSafeAreaInset + toolbarHeight)

                    Spacer()

                    VStack(spacing: .spacing(.xxSmall)) {
                        HStack(spacing: .spacing(.xSmall)) {
                            Text(folder.symbol)
                                .font(.largeTitle)

                            Text(folder.name)
                                .font(.title)
                                .bold()
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }

                        Text(itemCountText)
                            .font(.footnote)
                            .foregroundStyle(.black.opacity(0.45))
                    }
                    .padding(.horizontal, .spacing(.large))

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Regular") {
    let folder = UserFolder(
        symbol: "🤡",
        name: "Uso diario",
        backgroundColor: "pastelPurple",
        changeHash: "abcdefg",
        contentCount: 3
    )
    let repo = FakeContentRepository()
    let sounds: [Sound] = Sound.sampleSounds
    repo.content = sounds.map { AnyEquatableMedoContent($0) }

    return NavigationStack {
        FolderDetailView(
            viewModel: FolderDetailViewModel(
                folder: folder,
                contentRepository: repo
            ),
            folder: folder,
            currentContentListMode: .constant(.regular),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            contentRepository: repo
        )
    }
}

#Preview("Regular - Selecting") {
    let folder = UserFolder(
        symbol: "🤡",
        name: "Uso diario",
        backgroundColor: "pastelPurple",
        changeHash: "abcdefg",
        contentCount: 3
    )
    let repo = FakeContentRepository()
    let sounds: [Sound] = Sound.sampleSounds
    repo.content = sounds.map { AnyEquatableMedoContent($0) }

    return NavigationStack {
        FolderDetailView(
            viewModel: FolderDetailViewModel(
                folder: folder,
                contentRepository: repo
            ),
            folder: folder,
            currentContentListMode: .constant(.selection),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            contentRepository: repo
        )
    }
}

#Preview("Red") {
    let folder = UserFolder(
        symbol: "🎲",
        name: "Aleatório, Random & WTF",
        backgroundColor: "pastelRed",
        changeHash: "abcdefg",
        contentCount: 3
    )
    let repo = FakeContentRepository()
    let sounds: [Sound] = Sound.sampleSounds
    repo.content = sounds.map { AnyEquatableMedoContent($0) }

    return NavigationStack {
        FolderDetailView(
            viewModel: FolderDetailViewModel(
                folder: folder,
                contentRepository: repo
            ),
            folder: folder,
            currentContentListMode: .constant(.regular),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            contentRepository: repo
        )
    }
}

#Preview("Long Title") {
    let folder = UserFolder(
        symbol: "🗳️",
        name: "Eleições Presidente 2022",
        backgroundColor: "pastelYellow",
        changeHash: "abcdefg",
        contentCount: 3
    )
    let repo = FakeContentRepository()
    let sounds: [Sound] = Sound.sampleSounds
    repo.content = sounds.map { AnyEquatableMedoContent($0) }

    return NavigationStack {
        FolderDetailView(
            viewModel: FolderDetailViewModel(
                folder: folder,
                contentRepository: repo
            ),
            folder: folder,
            currentContentListMode: .constant(.regular),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            contentRepository: repo
        )
    }
}
