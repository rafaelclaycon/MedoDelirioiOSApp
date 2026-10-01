//
//  ReactionDetailView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI
import TipKit

struct ReactionDetailView: View {

    @State var viewModel: ReactionDetailViewModel
    @State private var contentGridViewModel: ContentGridViewModel

    @State private var columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
    /// The share preview's image, loaded when the screen appears so sharing is instant.
    @State private var shareImage: Image?

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
            onContentPlayed: viewModel.onReactionEngaged,
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
                        loadingView: ContentGridSkeletonView(containerSize: geometry.size),
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
                        startSelectingAction: {
                            contentGridViewModel.onEnterMultiSelectModeSelected(
                                loadedContent: loadedContent,
                                isFavoritesOnlyView: false
                            )
                        },
                        isPlayingPlaylist: contentGridViewModel.isPlayingPlaylist,
                        soundArrayIsEmpty: soundArrayIsEmpty,
                        isSelecting: contentGridMode.wrappedValue == .selection,
                        shareURL: shareURL,
                        shareTitle: shareTitle,
                        shareImage: shareImage,
                        onShared: { [id = viewModel.reaction.id] in
                            Task { await AnalyticsService().send(originatingScreen: "ReactionDetail", action: "didShareLink(\(id))") }
                        }
                    )
                }
                .task(id: viewModel.reaction.id) {
                    shareImage = await LinkShareButton.loadImage(from: URL(string: viewModel.reaction.image))
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
            .toolbarVisibility(contentGridViewModel.tabBarVisibility, for: .tabBar)
        }
    }
}

// MARK: - Share

extension ReactionDetailView {

    private var shareURL: URL? {
        URL(string: APIConfig.baseLinkURL + "reacao/\(viewModel.reaction.id)")
    }

    private var shareTitle: String {
        "Reação \(viewModel.reaction.title.capitalized(with: Locale(identifier: "pt_BR")))"
    }
}

// MARK: - Subviews

extension ReactionDetailView {

    struct ToolbarControls: ToolbarContent {

        @Binding var contentSortOption: Int
        let playStopAction: () -> Void
        let startSelectingAction: () -> Void
        let isPlayingPlaylist: Bool
        let soundArrayIsEmpty: Bool
        let isSelecting: Bool
        let shareURL: URL?
        let shareTitle: String
        let shareImage: Image?
        /// Runs once the link actually reaches an app (see `LinkShareButton`).
        let onShared: @Sendable () -> Void

        private let shareTip = ReactionShareButtonTip()

        @ViewBuilder
        private var shareButton: some View {
            if let shareURL {
                LinkShareButton(
                    url: shareURL,
                    title: shareTitle,
                    image: shareImage,
                    placeholderSymbol: "theatermasks",
                    onShared: onShared
                )
                .disabled(isSelecting)
                .popoverTip(shareTip)
                .tipViewStyle(PrimaryImageTipViewStyle(tip: shareTip))
            }
        }

        private var playStopIsDisabled: Bool {
            soundArrayIsEmpty || isSelecting
        }

        var body: some ToolbarContent {
            ToolbarItem {
                Button {
                    playStopAction()
                } label: {
                    Image(systemName: isPlayingPlaylist ? "stop.fill" : "play.fill")
                }
                .disabled(playStopIsDisabled)
            }

            ToolbarSpacer(.fixed)

            ToolbarItem {
                shareButton
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
                        Picker("Ordenação", selection: $contentSortOption) {
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
