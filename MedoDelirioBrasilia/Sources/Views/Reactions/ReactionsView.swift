//
//  ReactionsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 13/06/22.
//

import SwiftUI

struct ReactionsView: View {

    @State private var viewModel = ViewModel(reactionRepository: ReactionRepository())

    // iPad Grid Layout
    @State private var columns: [GridItem] = []
    @Environment(\.sizeCategory) var sizeCategory

    @Environment(TrendsHelper.self) private var trendsHelper
    @Environment(\.push) private var push

    /// Equatable token for the current state, used to drive the crossfade
    /// between loading, loaded and error views.
    private enum ViewPhase {
        case loading, loaded, error
    }

    private var phase: ViewPhase {
        switch viewModel.state {
        case .loading: .loading
        case .loaded: .loaded
        case .error: .error
        }
    }

    private var isLoaded: Bool { phase == .loaded }

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            // A single persistent ScrollView owns scrolling so the large nav-bar
            // title stays anchored to it across state changes — only the inner
            // content crossfades, which avoids the title blinking on each swap.
            ScrollView {
                ZStack(alignment: .top) {
                    switch viewModel.state {
                    case .loading:
                        LoadingView(width: geometry.size.width)
                            .transition(.opacity)

                    case .loaded(let reactionGroup):
                        if reactionGroup.regular.isEmpty {
                            EmptyView(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .transition(.opacity)
                        } else {
                            LoadedView(
                                pinnedReactions: reactionGroup.pinned,
                                otherReactions: reactionGroup.regular,
                                columns: columns,
                                pinAction: { reaction in
                                    Task {
                                        await viewModel.onPinReactionSelected(reaction: reaction)
                                    }
                                },
                                unpinAction: { reaction in
                                    Task {
                                        await viewModel.onUnpinReactionSelected(reaction: reaction)
                                    }
                                }
                            )
                            .transition(.opacity)
                            .onAppear {
                                columns = GridHelper.adaptableColumns(
                                    gridWidth: geometry.size.width,
                                    sizeCategory: sizeCategory,
                                    spacing: UIDevice.deviceType == .iPhone ? 12 : 20
                                )

                                Task {
                                    await AnalyticsService().send(
                                        originatingScreen: "ReactionsView",
                                        action: "didViewReactionsTab"
                                    )
                                }
                            }
                            .onChange(of: geometry.size.width) {
                                columns = GridHelper.adaptableColumns(
                                    gridWidth: geometry.size.width,
                                    sizeCategory: sizeCategory,
                                    spacing: UIDevice.deviceType == .iPhone ? 12 : 20
                                )
                            }
                        }

                    case .error(let errorString):
                        ErrorView(
                            error: errorString,
                            tryAgainAction: {
                                Task {
                                    await viewModel.onTryAgainSelected()
                                }
                            },
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .animation(.easeInOut(duration: 0.3), value: phase)
            }
            .scrollDisabled(!isLoaded)
            .refreshable {
                await viewModel.onPullToRefresh()
            }
        }
        .navigationTitle("Reações")
        .toolbar {
            ToolbarControls(
                isEnabled: isLoaded,
                showHowReactionsWorkAction: { viewModel.showHowReactionsWorkSheet.toggle() }
            )
        }
        .sheet(isPresented: $viewModel.showHowReactionsWorkSheet) {
            HowReactionsWorkView()
        }
        .oneTimeTask {
            await viewModel.onViewLoaded()
        }
        .alert(
            "Não Foi Possível Fixar a Reação Selecionada",
            isPresented: $viewModel.showIssueSavingPinAlert,
            actions: { Button("OK", role: .cancel, action: {}) },
            message: { Text("Tente novamente mais tarde.") }
        )
        .alert(
            "Não Foi Possível Desafixar a Reação Selecionada",
            isPresented: $viewModel.showIssueRemovingPinAlert,
            actions: { Button("OK", role: .cancel, action: {}) },
            message: { Text("Tente novamente mais tarde.") }
        )
        .alert(
            "Não Foi Possível Abrir a Reação Selecionada",
            isPresented: $viewModel.showIssueOpeningReaction,
            actions: { Button("OK", role: .cancel, action: {}) },
            message: { Text("Ela pode ter sido removida.") }
        )
        .onChange(of: trendsHelper.reactionIdToNavigateTo) {
            if !trendsHelper.reactionIdToNavigateTo.isEmpty {
                viewModel.onUserTappedReactionInTrendsTab(trendsHelper.reactionIdToNavigateTo) { reaction in
                    push(GeneralNavigationDestination.reactionDetail(reaction))
                }
                trendsHelper.reactionIdToNavigateTo = ""
            }
        }
        .onChange(of: viewModel.reactionToOpen) {
            guard let reaction = viewModel.reactionToOpen else { return }
            push(GeneralNavigationDestination.reactionDetail(reaction))
            viewModel.reactionToOpen = nil
        }
    }
}

// MARK: - Subviews

extension ReactionsView {

    struct ToolbarControls: ToolbarContent {

        let isEnabled: Bool
        let showHowReactionsWorkAction: () -> Void

        var body: some ToolbarContent {
            ToolbarItem {
                Button {
                    showHowReactionsWorkAction()
                } label: {
                    Image(systemName: "questionmark")
                }
                .disabled(!isEnabled)
            }
        }
    }

    struct LoadingView: View {

        let width: CGFloat

        @Environment(\.sizeCategory) private var sizeCategory

        private var spacing: CGFloat { UIDevice.deviceType == .iPhone ? 12 : 20 }

        private var columns: [GridItem] {
            GridHelper.adaptableColumns(
                gridWidth: width,
                sizeCategory: sizeCategory,
                spacing: spacing
            )
        }

        var body: some View {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(0..<12, id: \.self) { _ in
                    ReactionSkeletonView()
                }
            }
            .padding()
        }
    }

    struct EmptyView: View {

        let width: CGFloat
        let height: CGFloat

        var body: some View {
            VStack(spacing: 30) {
                Text("😮")
                    .font(.system(size: 86))

                Text("Nenhuma Reação")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Parece que você chegou muito cedo. Volte daqui a pouco.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 20)
            .frame(width: width)
            .frame(minHeight: height)
        }
    }

    struct ErrorView: View {

        let error: String
        let tryAgainAction: () -> Void
        let width: CGFloat
        let height: CGFloat

        var body: some View {
            VStack(spacing: 30) {
                Text("☹️")
                    .font(.system(size: 86))

                Text("Erro ao Carregar as Reações")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)

                Button {
                    tryAgainAction()
                } label: {
                    Label("Tentar Novamente", systemImage: "arrow.clockwise")
                }
            }
            .padding(.horizontal, 20)
            .frame(width: width)
            .frame(minHeight: height)
        }
    }
}

// MARK: - Preview

#Preview {
    ReactionsView()
}
