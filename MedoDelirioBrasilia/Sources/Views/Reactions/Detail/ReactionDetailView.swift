//
//  ReactionDetailView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import LinkPresentation
import SwiftUI

struct ReactionDetailView: View {

    @State var viewModel: ReactionDetailViewModel
    @State private var contentGridViewModel: ContentGridViewModel

    @State private var columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var isPreparingShare: Bool = false
    @State private var shareLinkMetadata: LPLinkMetadata?
    @State private var showShareSheet = false

    private var contentGridMode: Binding<ContentGridMode>

    // MARK: - Computed Properties

    private var toolbarControlsOpacity: CGFloat {
        guard case .loaded(let content) = viewModel.state else { return 1.0 }
        return content.isEmpty ? 0.5 : 1.0
    }

    private var soundArrayIsEmpty: Bool {
        guard case .loaded(let content) = viewModel.state else { return true }
        return content.isEmpty
    }

    private var loadedContent: [AnyEquatableMedoContent] {
        guard case .loaded(let content) = viewModel.state else { return [] }
        return content
    }

    // MARK: - Initializer

    init(
        viewModel: ReactionDetailViewModel,
        currentListMode: Binding<ContentGridMode>,
        contentRepository: ContentRepositoryProtocol
    ) {
        self.viewModel = viewModel
        self.contentGridMode = currentListMode
        self.contentGridViewModel = ContentGridViewModel(
            contentRepository: contentRepository,
            userFolderRepository: UserFolderRepository(database: LocalDatabase.shared),
            contentFileManager: ContentFileManager(),
            screen: .reactionDetailView,
            menuOptions: [.sharingOptions(), .organizingOptions(), .playFromThisSound(), .detailsOptions()],
            currentListMode: currentListMode,
            toast: viewModel.toast,
            floatingOptions: viewModel.floatingOptions,
            analyticsService: AnalyticsService()
        )
    }

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: .spacing(.medium)) {
                    GeometryReader { headerProxy in
                        let offset = headerProxy.frame(in: .global).minY
                        let extraHeight = max(0, offset)
                        ReactionDetailHeader(
                            title: viewModel.reaction.title,
                            subtitle: viewModel.subtitle,
                            imageUrl: viewModel.reaction.image,
                            attributionText: viewModel.reaction.attributionText,
                            attributionURL: viewModel.reaction.attributionURL
                        )
                        .frame(height: 260 + extraHeight)
                        .offset(y: -extraHeight)
                    }
                    .frame(height: 260)
                    .clipShape(TopOpenRectangle())
                    .padding(.bottom, 6)

                    ContentGrid(
                        state: viewModel.state,
                        viewModel: contentGridViewModel,
                        toast: viewModel.toast,
                        showNewTag: false,
                        reactionId: viewModel.reaction.id,
                        containerSize: geometry.size,
                        loadingView: BasicLoadingView(text: "Carregando Conteúdos..."),
                        emptyStateView: EmptyStateView(
                            reloadAction: {
                                Task {
                                    await viewModel.onRetrySelected()
                                }
                            }
                        ),
                        errorView: ErrorView(
                            reactionNoLongerExists: viewModel.reactionNoLongerExists,
                            errorMessage: viewModel.errorMessage,
                            tryAgainAction: {
                                Task {
                                    await viewModel.onRetrySelected()
                                }
                            }
                        )
                    )
                    .environment(TrendsHelper())
                    .padding(.horizontal, .spacing(.medium))

                    Spacer()
                        .frame(height: .spacing(.large))
                }
                .toolbar {
                    ToolbarControls(
                        contentSortOption: $viewModel.contentSortOption,
                        playStopAction: { contentGridViewModel.onPlayStopPlaylistSelected(loadedContent: loadedContent) },
                        shareAction: prepareShare,
                        startSelectingAction: {
                            contentGridViewModel.onEnterMultiSelectModeSelected(
                                loadedContent: loadedContent,
                                isFavoritesOnlyView: false
                            )
                        },
                        isPlayingPlaylist: contentGridViewModel.isPlayingPlaylist,
                        soundArrayIsEmpty: soundArrayIsEmpty,
                        isSelecting: contentGridMode.wrappedValue == .selection,
                        isPreparingShare: isPreparingShare
                    )
                }
                .sheet(isPresented: $showShareSheet) {
                    if let metadata = shareLinkMetadata {
                        LinkMetadataShareSheet(metadata: metadata)
                            .presentationDetents([.medium, .large])
                    }
                }
                .oneTimeTask {
                    await viewModel.onViewLoaded()
                }
                .onAppear {
                    Task {
                        await AnalyticsService().send(
                            originatingScreen: "ReactionDetailView",
                            action: "didViewReaction(\(viewModel.reaction.title))"
                        )
                    }
                }
                .onChange(of: viewModel.contentSortOption) {
                    contentGridViewModel.onContentSortingChanged()
                    Task {
                        await viewModel.onContentSortingChanged()
                    }
                }
            }
            .edgesIgnoringSafeArea(.top)
            .toast(contentGridViewModel.toast)
            .floatingContentOptions(contentGridViewModel.floatingOptions)
            .toolbar(contentGridViewModel.tabBarVisibility, for: .tabBar)
        }
    }
}

// MARK: - Share

extension ReactionDetailView {

    private func prepareShare() {
        guard !isPreparingShare else { return }
        guard let shareURL = URL(string: APIConfig.baseLinkURL + "reacao/\(viewModel.reaction.id)") else {
            return
        }
        isPreparingShare = true

        Task {
            let meta = LPLinkMetadata()
            meta.url = shareURL
            meta.title = "Reação \(viewModel.reaction.title.capitalized(with: Locale(identifier: "pt_BR")))"

            if let imageURL = URL(string: viewModel.reaction.image),
               let (data, _) = try? await URLSession.shared.data(from: imageURL),
               let image = UIImage(data: data) {
                meta.imageProvider = NSItemProvider(object: image)
            }

            shareLinkMetadata = meta
            isPreparingShare = false
            showShareSheet = true
        }
    }
}

// MARK: - Subviews

extension ReactionDetailView {

    struct ToolbarControls: ToolbarContent {

        @Binding var contentSortOption: Int
        let playStopAction: () -> Void
        let shareAction: () -> Void
        let startSelectingAction: () -> Void
        let isPlayingPlaylist: Bool
        let soundArrayIsEmpty: Bool
        let isSelecting: Bool
        var isPreparingShare: Bool = false

        private var playStopIsDisabled: Bool {
            soundArrayIsEmpty || isSelecting
        }

        var body: some ToolbarContent {
            if #available(iOS 26.0, *) {
                ToolbarItem {
                    Button {
                        playStopAction()
                    } label: {
                        Image(systemName: isPlayingPlaylist ? "stop.fill" : "play.fill")
                    }
                    .disabled(playStopIsDisabled)
                }

                if FeatureFlag.isEnabled(.shareButton) {
                    ToolbarSpacer(.fixed)

                    ToolbarItem {
                        Button(action: shareAction) {
                            if isPreparingShare {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isSelecting || isPreparingShare)
                    }
                }

                ToolbarSpacer(.fixed)

                ToolbarItem {
                    Menu {
                        Section {
                            Button {
                                startSelectingAction()
                            } label: {
                                Label(
                                    isSelecting ? "Cancelar Seleção" : "Selecionar",
                                    systemImage: isSelecting ? "xmark.circle" : "checkmark.circle"
                                )
                            }
                        }

                        Section {
                            Picker("Ordenação de Sons", selection: $contentSortOption) {
                                ForEach(ReactionSoundSortOption.allCases, id: \.self) { option in
                                    Text(option.description).tag(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            } else {
                ToolbarItem {
                    Button {
                        playStopAction()
                    } label: {
                        Image(systemName: isPlayingPlaylist ? "stop.fill" : "play.fill")
                            .opacity(playStopIsDisabled ? 0.5 : 1.0)
                    }
                    .disabled(playStopIsDisabled)
                }

                if FeatureFlag.isEnabled(.shareButton) {
                    ToolbarItem {
                        Button(action: shareAction) {
                            if isPreparingShare {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isSelecting || isPreparingShare)
                    }
                }

                ToolbarItem {
                    Menu {
                        Section {
                            Button {
                                startSelectingAction()
                            } label: {
                                Label(
                                    isSelecting ? "Cancelar Seleção" : "Selecionar",
                                    systemImage: isSelecting ? "xmark.circle" : "checkmark.circle"
                                )
                            }
                        }

                        Section {
                            Picker("Ordenação de Sons", selection: $contentSortOption) {
                                ForEach(ReactionSoundSortOption.allCases, id: \.self) { option in
                                    Text(option.description).tag(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
    }

    struct EmptyStateView: View {

        let reloadAction: () -> Void

        var body: some View {
            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "pc")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .foregroundStyle(.gray)

                Text("Essa Reação está vazia. Parece que você chegou muito cedo.")
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)

                Button {
                    reloadAction()
                } label: {
                    Label("Recarregar", systemImage: "arrow.clockwise")
                }
                .padding(.bottom)

                Spacer()
            }
            .padding(.horizontal, 30)
        }
    }

    struct ErrorView: View {

        let reactionNoLongerExists: Bool
        let errorMessage: String
        let tryAgainAction: () -> Void

        var body: some View {
            if reactionNoLongerExists {
                VStack(spacing: 40) {
                    Text("🗑️")
                        .font(.system(size: 68))

                    VStack(spacing: 36) {
                        Text("Reação Removida do Servidor")
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)

                        Text("Essa Reação não existe mais no servidor. Por favor, volte para a lista de Reações e puxe a partir do topo para atualizá-la.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                }
            } else {
                VStack(spacing: 40) {
                    Text("☹️")
                        .font(.system(size: 86))
                    
                    VStack(spacing: 40) {
                        Text("Erro ao Carregar os Sons Dessa Reação")
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                        
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.gray)
                        
                        Button {
                            tryAgainAction()
                        } label: {
                            Label("Tentar Novamente", systemImage: "arrow.clockwise")
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReactionDetailView(
        viewModel: ReactionDetailViewModel(
            reaction: .acidMock,
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            contentRepository: FakeContentRepository()
        ),
        currentListMode: .constant(.regular),
        contentRepository: FakeContentRepository()
    )
}
