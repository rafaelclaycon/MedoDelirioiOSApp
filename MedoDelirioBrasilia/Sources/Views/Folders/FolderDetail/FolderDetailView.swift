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

    let folder: UserFolder

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
        self.folder = folder

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
                            ToolbarItem {
                                if currentContentListMode.wrappedValue == .regular {
                                    playStopButton()
                                } else {
                                    selectionControls
                                }
                            }
                            ToolbarSpacer(.fixed)
                            if currentContentListMode.wrappedValue == .regular {
                                ToolbarItem {
                                    multiselectButton
                                }
                            }
                            ToolbarSpacer(.fixed)
                            ToolbarItem { multiselectAndSortMenu() }
                        }
                }
                .edgesIgnoringSafeArea(.top)
                .toast(contentGridViewModel.toast)
                .floatingContentOptions(contentGridViewModel.floatingOptions)
                .scrollEdgeEffectHidden(true, for: .top)
            } else {
                ScrollView {
                    detailView(size: geometry.size)
                        .toolbar {
                            HStack(spacing: 16) {
                                if currentContentListMode.wrappedValue == .regular {
                                    playStopButton()
                                } else {
                                    selectionControls
                                }

                                multiselectAndSortMenu()
                            }
                        }
                }
                .edgesIgnoringSafeArea(.top)
                .toast(contentGridViewModel.toast)
                .floatingContentOptions(contentGridViewModel.floatingOptions)
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
                loadingView: BasicLoadingView(text: "Carregando Conteúdos..."),
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
                }
            )
        }
        .toolbar(contentGridViewModel.tabBarVisibility, for: .tabBar)
    }

    @ViewBuilder func playStopButton() -> some View {
        Button {
            contentGridViewModel.onPlayStopPlaylistSelected(loadedContent: loadedContent)
        } label: {
            Image(systemName: contentGridViewModel.isPlayingPlaylist ? "stop.fill" : "play.fill")
        }
        .disabled(viewModel.contentCount == 0)
    }
    
    @ViewBuilder func multiselectAndSortMenu() -> some View {
        Menu {
//            Section {
//                Button {
//                    contentGridViewModel.onEnterMultiSelectModeSelected(
//                        loadedContent: loadedContent,
//                        isFavoritesOnlyView: false
//                    )
//                } label: {
//                    Label(
//                        currentContentListMode.wrappedValue == .selection ? "Cancelar Seleção" : "Selecionar",
//                        systemImage: currentContentListMode.wrappedValue == .selection ? "xmark.circle" : "checkmark.circle"
//                    )
//                }
//            }

            //Section {
                Picker("Ordenação de Sons", selection: $viewModel.contentSortOption) {
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
            //}

            //                    Section {
            //                        Button {
            //                            showingFolderInfoEditingView = true
            //                        } label: {
            //                            Label("Editar Pasta", systemImage: "pencil")
            //                        }
            //
            //                        Button(role: .destructive, action: {
            //                            //viewModel.dummyCall()
            //                        }, label: {
            //                            HStack {
            //                                Text("Apagar Pasta")
            //                                Image(systemName: "trash")
            //                            }
            //                        })
            //                    }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .disabled(contentGridViewModel.isPlayingPlaylist || (viewModel.contentCount == 0))
    }
    
    var selectionControls: some View {
        Button {
            currentContentListMode.wrappedValue = .regular
            contentGridViewModel.selectionKeeper.removeAll()
        } label: {
            Text("Cancelar")
        }
    }

    var multiselectButton: some View {
        Button {
            contentGridViewModel.onEnterMultiSelectModeSelected(
                loadedContent: loadedContent,
                isFavoritesOnlyView: false
            )
        } label: {
            Text("Selecionar")
        }
    }
}

// MARK: - Subviews

extension FolderDetailView {

    struct StickyFolderBackgroundView: View {

        let color: Color
        let height: CGFloat

        // MARK: - Computed Properties

        private func scrollOffset(_ geometry: GeometryProxy) -> CGFloat {
            geometry.frame(in: .global).minY
        }

        private func getOffsetForHeaderImage(_ geometry: GeometryProxy) -> CGFloat {
            let offset = scrollOffset(geometry)
            // Image was pulled down
            if offset > 0 {
                return -offset
            }
            return 0
        }

        private func getHeightForHeaderImage(_ geometry: GeometryProxy) -> CGFloat {
            let offset = scrollOffset(geometry)
            let imageHeight = geometry.size.height
            if offset > 0 {
                return imageHeight + offset
            }
            return imageHeight
        }

        // MARK: - View Body

        var body: some View {
            GeometryReader { proxy in
                if #available(iOS 26.0, *) {
                    colorfulRectangle(proxy: proxy)
                        .backgroundExtensionEffect()
                } else {
                    colorfulRectangle(proxy: proxy)
                }
            }
            .frame(height: height)
        }

        @ViewBuilder
        func colorfulRectangle(proxy: GeometryProxy) -> some View {
            Rectangle()
                .fill(color)
                .overlay { FolderView.SpeckleOverlay() }
                .frame(
                    width: proxy.size.width,
                    height: getHeightForHeaderImage(proxy)
                )
                .offset(x: 0, y: getOffsetForHeaderImage(proxy))
        }
    }

    struct HeaderView: View {

        let folder: UserFolder
        let itemCountText: String

        var body: some View {
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                StickyFolderBackgroundView(
                    color: folder.backgroundColor.toPastelColor(),
                    height: 200
                )
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: .spacing(.xxSmall)) {
                        Text(folder.symbol)
                            .font(.largeTitle)

                        Text(folder.name)
                            .font(.title)
                            .bold()
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                    }
                    .padding(.all, .spacing(.large))
                }

                Text(itemCountText)
                    .font(.callout)
                    .foregroundColor(.gray)
                    .bold()
                    .padding(.leading, .spacing(.medium))
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
    var repo = FakeContentRepository()
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
    var repo = FakeContentRepository()
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
    var repo = FakeContentRepository()
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
    var repo = FakeContentRepository()
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
