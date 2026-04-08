//
//  MostSharedByAudienceView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 11/10/22.
//

import SwiftUI

struct MostSharedByAudienceView: View {

    @Bindable var viewModel: ViewModel
    @Binding var tabSelection: PhoneTab
    @Binding var activePadScreen: PadScreen?
    @Environment(TrendsHelper.self) private var trendsHelper
    @Environment(\.scenePhase) var scenePhase

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - View Body

    var body: some View {
        VStack(spacing: .spacing(.large)) {
            TitledRankingView(
                title: "Sons Mais Compartilhados",
                state: viewModel.soundsState,
                timeIntervalOption: $viewModel.soundsTimeInterval,
                lastUpdatedText: viewModel.soundsLastCheckString,
                navigateToText: "Ir para Conteúdo",
                navigateToAction: { soundId in
                    navigateTo(content: soundId)
                }
            )
            .onChange(of: viewModel.soundsTimeInterval) {
                Task {
                    await viewModel.onSoundsSelectedTimeIntervalChanged(newTimeInterval: viewModel.soundsTimeInterval)
                }
            }

            TitledRankingView(
                title: "Músicas Mais Compartilhadas",
                state: viewModel.songsState,
                timeIntervalOption: $viewModel.songsTimeInterval,
                lastUpdatedText: viewModel.songsLastCheckString,
                navigateToText: "Ir para Conteúdo",
                navigateToAction: { songId in
                    navigateTo(content: songId)
                }
            )
            .onChange(of: viewModel.songsTimeInterval) {
                Task {
                    await viewModel.onSongsSelectedTimeIntervalChanged(newTimeInterval: viewModel.songsTimeInterval)
                }
            }

            ReactionsRankingView(
                title: "Reações Mais Populares",
                state: viewModel.reactionsState,
                lastUpdatedText: viewModel.reactionsLastCheckString,
                navigateToAction: { reactionId in
                    navigateTo(reaction: reactionId)
                },
                reloadAction: {
                    Task {
                        await viewModel.onReloadPopularReactionsSelected()
                    }
                }
            )

            Text("Os dados se referem apenas à audiência dos apps iOS/iPadOS/Mac.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, .spacing(.xxLarge))
                .padding(.bottom, .spacing(.xxLarge))
                .padding(.top, -5)
        }
        .padding(.bottom, .spacing(.small))
        .onReceive(timer) { input in
            viewModel.onLastCheckStringUpdatingTimerFired()
        }
        .onAppear {
            Task {
                await viewModel.onViewAppeared()
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text(viewModel.alertTitle), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
        .onChange(of: scenePhase) {
            Task {
                await viewModel.onScenePhaseChanged(isNewPhaseActive: scenePhase == .active)
            }
        }
    }

    // MARK: - Functions

    private func navigateTo(content contentId: String) {
        if UIDevice.isiPhone {
            tabSelection = .sounds
        } else {
            activePadScreen = .allSounds
        }
        trendsHelper.contentIdToNavigateTo = contentId
    }

    private func navigateTo(reaction reactionId: String) {
        if UIDevice.isiPhone {
            tabSelection = .reactions
        } else {
            activePadScreen = .reactions
        }
        trendsHelper.reactionIdToNavigateTo = reactionId
    }
}

// MARK: - Subviews

extension MostSharedByAudienceView {

    struct TitledRankingView: View {

        // MARK: - External Dependencies

        let title: String
        let state: LoadingState<[TopChartItem]>
        @Binding var timeIntervalOption: TrendsTimeInterval
        let lastUpdatedText: String
        let navigateToText: String
        let navigateToAction: (String) -> Void

        // MARK: - Private Properti

        private let columns = [GridItem(.flexible())]
        private let columnsMac = [GridItem(.fixed(500))]

        private var dropDownText: String {
            switch timeIntervalOption {
            case .last24Hours:
                Shared.Trends.last24Hours
            case .last3Days:
                Shared.Trends.last3Days
            case .lastWeek:
                Shared.Trends.lastWeek
            case .lastMonth:
                Shared.Trends.lastMonth
            case .last3Months:
                Shared.Trends.last3Months
            case .year2026:
                Shared.Trends.year2026
            case .year2025:
                Shared.Trends.year2025
            case .year2024:
                Shared.Trends.year2024
            case .year2023:
                Shared.Trends.year2023
            case .year2022:
                Shared.Trends.year2022
            case .allTime:
                Shared.Trends.allTime
            }
        }

        // MARK: - View Body

        var body: some View {
            VStack(spacing: .spacing(.small)) {
                HStack {
                    Text(title)
                        .font(.title2)
                    Spacer()
                }
                .padding(.horizontal)

                HStack(spacing: .spacing(.large)) {
                    timeIntervalSelector()

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 1)
                .padding(.bottom)

                switch state {
                case .loading:
                    LoadingView()

                case .loaded(let items):
                    VStack(spacing: .spacing(.large)) {
                        if items.isEmpty {
                            NoDataToDisplayView()
                        } else {
                            LazyVGrid(columns: UIDevice.isMac ? columnsMac : columns, spacing: 10) {
                                ForEach(items) { item in
                                    TopChartRow(item: item)
                                        .onTapGesture {
                                            navigateToAction(item.contentId)
                                        }
                                        .contextMenu {
                                            if UIDevice.isiPhone {
                                                Button {
                                                    navigateToAction(item.contentId)
                                                } label: {
                                                    Label(
                                                        navigateToText,
                                                        systemImage: "arrow.uturn.backward"
                                                    )
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, .spacing(.medium))
                            .padding(.top, -8)
                        }

                        Text(lastUpdatedText)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom)
                    }

                case .error(let errorMessage):
                    Text(errorMessage)
                }
            }
        }

        // MARK: - Subviews

        @ViewBuilder func timeIntervalSelector() -> some View {
            Menu {
                menuItem(Shared.Trends.last24Hours, interval: .last24Hours)
                menuItem(Shared.Trends.last3Days, interval: .last3Days)
                menuItem(Shared.Trends.lastWeek, interval: .lastWeek)
                menuItem(Shared.Trends.lastMonth, interval: .lastMonth)

                if CommandLine.arguments.contains("-SHOW_MORE_DEV_OPTIONS") {
                    menuItem(Shared.Trends.last3Months, interval: .last3Months)
                }

                Menu("Por Ano") {
                    menuItem(Shared.Trends.year2026, interval: .year2026)
                    menuItem(Shared.Trends.year2025, interval: .year2025)
                    menuItem(Shared.Trends.year2024, interval: .year2024)
                    menuItem(Shared.Trends.year2023, interval: .year2023)
                    menuItem(Shared.Trends.year2022, interval: .year2022)
                }

                menuItem(Shared.Trends.allTime, interval: .allTime)
            } label: {
                if #available(iOS 26, *) {
                    HStack(spacing: .spacing(.xxSmall)) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(dropDownText)
                    }
                    .padding(.vertical, .spacing(.xSmall))
                    .padding(.horizontal, .spacing(.small))
                    .glassEffect(.regular.interactive())
                } else {
                    HStack(spacing: .spacing(.xxSmall)) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(dropDownText)
                    }
                }
            }
        }

        private func menuItem(_ title: String, interval: TrendsTimeInterval) -> some View {
            Button {
                timeIntervalOption = interval
            } label: {
                if timeIntervalOption == interval {
                    Label(title, systemImage: "checkmark")
                } else {
                    Text(title)
                }
            }
        }
    }

    struct ReactionsRankingView: View {

        let title: String
        let state: LoadingState<[TopChartReaction]>
        let lastUpdatedText: String
        let navigateToAction: (String) -> Void
        let reloadAction: () -> Void

        @State private var columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
        //@Environment(\.sizeCategory) var sizeCategory

        var body: some View {
            VStack(spacing: .spacing(.xxSmall)) {
                HStack {
                    Text(title)
                        .font(.title2)
                    Spacer()
                }
                .padding(.horizontal)

                switch state {
                case .loading:
                    LoadingView()

                case .loaded(let items):
                    VStack(spacing: .spacing(.xxxSmall)) {
                        LazyVGrid(
                            columns: columns,
                            spacing: UIDevice.isiPhone ? .spacing(.small) : .spacing(.large)
                        ) {
                            ForEach(items) { item in
                                RankedReactionItem(
                                    item: item
                                )
                                .onTapGesture {
                                    navigateToAction(item.reaction.id)
                                }
                            }
                        }
                        .padding([.top, .leading, .trailing])

                        Text(lastUpdatedText)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom)
                    }

                case .error(let errorMessage):
                    ErrorView(
                        message: errorMessage,
                        retryAction: reloadAction
                    )
                }
            }
        }
    }

    struct RankedReactionItem: View {

        let item: TopChartReaction

        var body: some View {
            VStack(spacing: .spacing(.small)) {
                ReactionItem(reaction: item.reaction)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                Text(item.description)
                    .bold()
                    .multilineTextAlignment(.center)

                Spacer()
            }
        }
    }

    struct NoDataToDisplayView: View {

        var body: some View {
            HStack {
                Spacer()

                VStack(spacing: .spacing(.large)) {
                    Text("Sem Dados para o Período Selecionado")
                        .font(.headline)
                        .padding(.vertical, .spacing(.xxxLarge))
                }

                Spacer()
            }
        }
    }

    struct LoadingView: View {

        var body: some View {
            VStack(spacing: .spacing(.large)) {
                ProgressView()
                    .scaleEffect(1.3, anchor: .center)

                Text("CONTANDO CANALHICES")
                    .foregroundColor(.gray)
                    .font(.callout)
            }
            .padding(.vertical, 100)
        }
    }

    struct ErrorView: View {

        let message: String
        let retryAction: () -> Void

        var body: some View {
            HStack {
                Spacer()

                VStack(spacing: .spacing(.xxLarge)) {
                    Text("Não Foi Possível Obter os Dados Mais Recentes")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)

                    Button {
                        retryAction()
                    } label: {
                        Label("Tentar Novamente", systemImage: "arrow.clockwise")
                    }
                    .borderedButton(colored: .accentColor)
                }

                Spacer()
            }
            .padding(.vertical, .spacing(.xxLarge))
        }
    }
}

// MARK: - Preview

#Preview {
    MostSharedByAudienceView(
        viewModel: MostSharedByAudienceView.ViewModel(
            trendsService: TrendsService(
                database: FakeLocalDatabase(),
                apiClient: FakeAPIClient(),
                contentRepository: FakeContentRepository()
            )
        ),
        tabSelection: .constant(.episodes),
        activePadScreen: .constant(.trends)
    )
}
