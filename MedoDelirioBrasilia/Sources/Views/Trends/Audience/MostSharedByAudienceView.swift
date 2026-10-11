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
    @Environment(\.usesSidebarLayout) private var usesSidebarLayout
    @Environment(\.push) private var push

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - View Body

    var body: some View {
        // Every section ends with the same room under it (see `ErrorView`), so this
        // is the whole gap before the next title.
        VStack(spacing: .spacing(.xLarge)) {
            TitledRankingView(
                title: viewModel.soundsMetric == .shares ? "Vírgulas Mais Compartilhadas" : "Vírgulas Mais Tocadas",
                state: viewModel.soundsState,
                timeIntervalOption: $viewModel.soundsTimeInterval,
                lastUpdatedText: viewModel.soundsLastCheckString,
                navigateToText: "Ir para Conteúdo",
                metric: $viewModel.soundsMetric,
                navigateToAction: { soundId in
                    navigateTo(content: soundId)
                },
                retryAction: {
                    Task {
                        await viewModel.onSoundsRetrySelected()
                    }
                }
            )
            .onChange(of: viewModel.soundsTimeInterval) {
                Task {
                    await viewModel.onSoundsSelectedTimeIntervalChanged(newTimeInterval: viewModel.soundsTimeInterval)
                }
            }
            .onChange(of: viewModel.soundsMetric) {
                Task {
                    await viewModel.onSoundsMetricChanged()
                }
            }

            TitledRankingView(
                title: viewModel.songsMetric == .shares ? "Músicas Mais Compartilhadas" : "Músicas Mais Tocadas",
                state: viewModel.songsState,
                timeIntervalOption: $viewModel.songsTimeInterval,
                lastUpdatedText: viewModel.songsLastCheckString,
                navigateToText: "Ir para Conteúdo",
                metric: $viewModel.songsMetric,
                navigateToAction: { songId in
                    navigateTo(content: songId)
                },
                retryAction: {
                    Task {
                        await viewModel.onSongsRetrySelected()
                    }
                }
            )
            .onChange(of: viewModel.songsTimeInterval) {
                Task {
                    await viewModel.onSongsSelectedTimeIntervalChanged(newTimeInterval: viewModel.songsTimeInterval)
                }
            }
            .onChange(of: viewModel.songsMetric) {
                Task {
                    await viewModel.onSongsMetricChanged()
                }
            }

            TitledRankingView(
                title: "Episódios Mais Ouvidos",
                state: viewModel.episodesState,
                timeIntervalOption: $viewModel.episodesTimeInterval,
                lastUpdatedText: viewModel.episodesLastCheckString,
                navigateToText: "Abrir Episódio",
                navigateToSystemImage: "radio",
                // Episode plays started being counted in February 2026.
                oldestYear: 2026,
                navigateToAction: { episodeId in
                    navigateTo(episode: episodeId)
                },
                retryAction: {
                    Task {
                        await viewModel.onEpisodesRetrySelected()
                    }
                }
            )
            .onChange(of: viewModel.episodesTimeInterval) {
                Task {
                    await viewModel.onEpisodesSelectedTimeIntervalChanged()
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

            Text("Os dados se referem apenas à audiência das plataformas Apple. Episódios ouvidos no Spotify e em outros apps de podcast não entram na conta.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.horizontal, .spacing(.xxLarge))
                .padding(.bottom, .spacing(.xxLarge))
                .padding(.top, -5)
        }
        .padding(.bottom, .spacing(.small))
        .onReceive(timer) { input in
            viewModel.onLastCheckStringUpdatingTimerFired()
        }
        .onAppear {
            applyTimeIntervalFromSiriIfNeeded()
            Task {
                await viewModel.onViewAppeared()
            }
        }
        .onChange(of: trendsHelper.timeIntervalToGoTo) {
            applyTimeIntervalFromSiriIfNeeded()
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

    /// Applies a time interval requested by a Trends Siri Suggestion. Setting `soundsTimeInterval`
    /// triggers the existing `.onChange` that reloads the sounds ranking for that interval.
    /// The suggestions are for the most shared, so the ranking goes back to shares too.
    private func applyTimeIntervalFromSiriIfNeeded() {
        guard let interval = trendsHelper.timeIntervalToGoTo else { return }
        viewModel.soundsMetric = .shares
        viewModel.soundsTimeInterval = interval
        trendsHelper.timeIntervalToGoTo = nil
    }

    private func navigateTo(content contentId: String) {
        if !usesSidebarLayout {
            tabSelection = .sounds
        } else {
            activePadScreen = .allSounds
        }
        trendsHelper.contentIdToNavigateTo = contentId
    }

    /// Trends always sits in the Search stack, which can show an episode's detail.
    private func navigateTo(episode episodeId: String) {
        guard let episode = try? LocalDatabase.shared.podcastEpisode(id: episodeId) else { return }
        push(GeneralNavigationDestination.episodeDetail(episode))
    }

    private func navigateTo(reaction reactionId: String) {
        if !usesSidebarLayout {
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
        var navigateToSystemImage: String = "arrow.uturn.backward"
        /// The year menu starts here, for rankings with no data before it.
        var oldestYear: Int = 2022
        /// Shows a menu to switch between shares and plays, next to the period.
        var metric: Binding<TrendsMetric>? = nil
        let navigateToAction: (String) -> Void
        let retryAction: () -> Void

        // MARK: - Private Properties

        private let columns = [GridItem(.flexible())]
        private let columnsMac = [GridItem(.fixed(500))]
        private let collapsedItemCount = 3

        @State private var isExpanded: Bool = false

        @Environment(\.usesSidebarLayout) private var usesSidebarLayout
        @Environment(\.horizontalSizeClass) private var hSizeClass

        private var dropDownText: String {
            title(for: timeIntervalOption)
        }

        /// Whether the period menu offers `interval`: not before `oldestYear`, and only
        /// when the selected metric has a ranking of its own for it.
        private func isOffered(_ interval: TrendsTimeInterval) -> Bool {
            if let year = interval.year, year < oldestYear {
                return false
            }
            return metric?.wrappedValue.isAvailable(interval) ?? true
        }

        private func title(for interval: TrendsTimeInterval) -> String {
            if let label = metric?.wrappedValue.label(for: interval) {
                return label
            }
            return switch interval {
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

                // The two menus stack when they don't fit side by side, like on a
                // narrow iPhone or with a large text size.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: .spacing(.small)) {
                        selectors()
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: .spacing(.small)) {
                        selectors()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                            LazyVGrid(columns: UIDevice.deviceType == .mac ? columnsMac : columns, spacing: 10) {
                                ForEach(isExpanded ? items : Array(items.prefix(collapsedItemCount))) { item in
                                    TopChartRow(item: item)
                                        .onTapGesture {
                                            navigateToAction(item.contentId)
                                        }
                                        .contextMenu {
                                            if !usesSidebarLayout {
                                                Button {
                                                    navigateToAction(item.contentId)
                                                } label: {
                                                    Label(
                                                        navigateToText,
                                                        systemImage: navigateToSystemImage
                                                    )
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, .spacing(.medium))
                            .padding(.top, -8)

                            if items.count > collapsedItemCount {
                                showMoreOrLessButton()
                            }
                        }

                        Text(lastUpdatedText)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom)
                    }

                case .error:
                    ErrorView(retryAction: retryAction)
                }
            }
        }

        // MARK: - Subviews

        @ViewBuilder func selectors() -> some View {
            timeIntervalSelector()

            if let metric {
                metricSelector(metric)
            }
        }

        @ViewBuilder func timeIntervalSelector() -> some View {
            Menu {
                menuItem(.last24Hours)
                menuItem(.last3Days)
                menuItem(.lastWeek)
                menuItem(.lastMonth)

                if CommandLine.arguments.contains("-SHOW_MORE_DEV_OPTIONS") {
                    menuItem(.last3Months)
                }

                let years: [TrendsTimeInterval] = [.year2026, .year2025, .year2024, .year2023, .year2022]
                    .filter(isOffered)
                if !years.isEmpty {
                    Menu("Por Ano") {
                        ForEach(years, id: \.self) { year in
                            menuItem(year)
                        }
                    }
                }

                menuItem(.allTime)
            } label: {
                HStack(spacing: .spacing(.xxSmall)) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text(dropDownText)
                }
                .padding(.vertical, .spacing(.xSmall))
                .padding(.horizontal, .spacing(.small))
                .glassEffect(.regular.interactive())
            }
        }

        private func metricSelector(_ metric: Binding<TrendsMetric>) -> some View {
            Menu {
                metricItem("Compartilhadas", systemImage: "square.and.arrow.up", value: .shares, selection: metric)
                metricItem("Tocadas", systemImage: "play.fill", value: .plays, selection: metric)
            } label: {
                HStack(spacing: .spacing(.xxSmall)) {
                    Image(systemName: metric.wrappedValue == .shares ? "square.and.arrow.up" : "play.fill")
                    Text(metricLabel(metric.wrappedValue))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(metric.wrappedValue == .shares ? "Compartilhadas" : "Tocadas")
                .padding(.vertical, .spacing(.xSmall))
                .padding(.horizontal, .spacing(.small))
                .glassEffect(.regular.interactive())
            }
        }

        /// Shortened on compact widths so it fits on the same line as the period.
        private func metricLabel(_ metric: TrendsMetric) -> String {
            switch metric {
            case .shares: hSizeClass == .compact ? "Compart." : "Compartilhadas"
            case .plays: "Tocadas"
            }
        }

        private func metricItem(
            _ title: String,
            systemImage: String,
            value: TrendsMetric,
            selection: Binding<TrendsMetric>
        ) -> some View {
            Button {
                selection.wrappedValue = value
            } label: {
                Label(title, systemImage: selection.wrappedValue == value ? "checkmark" : systemImage)
            }
        }

        private func showMoreOrLessButton() -> some View {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: .spacing(.xxSmall)) {
                    Text(isExpanded ? "Ver Menos" : "Ver Mais")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
        }

        @ViewBuilder
        private func menuItem(_ interval: TrendsTimeInterval) -> some View {
            if isOffered(interval) {
                Button {
                    timeIntervalOption = interval
                } label: {
                    if timeIntervalOption == interval {
                        Label(title(for: interval), systemImage: "checkmark")
                    } else {
                        Text(title(for: interval))
                    }
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

        @State private var width: CGFloat = 0
        @Environment(\.horizontalSizeClass) private var hSizeClass
        @Environment(\.sizeCategory) private var sizeCategory

        private var spacing: CGFloat {
            hSizeClass == .regular ? .spacing(.large) : .spacing(.small)
        }

        /// The same columns as the Reactions tab, so a wide window gets more cards
        /// instead of bigger ones. Top-aligned for descriptions that wrap.
        private var columns: [GridItem] {
            GridHelper.adaptableColumns(
                gridWidth: width,
                sizeCategory: sizeCategory,
                spacing: spacing,
                alignment: .top
            )
        }

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
                    // Same gap above "Última consulta" as the rankings above.
                    VStack(spacing: .spacing(.large)) {
                        LazyVGrid(columns: columns, spacing: spacing) {
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

                case .error:
                    ErrorView(retryAction: reloadAction)
                        // This section has no menus above, so it needs its own gap.
                        .padding(.top, .spacing(.large))
                }
            }
            // The full section width, like the Reactions tab measures its whole screen.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
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
            }
        }
    }

    struct NoDataToDisplayView: View {

        var body: some View {
            VStack(spacing: .spacing(.medium)) {
                Image(systemName: "chart.bar")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("Sem Dados para o Período Selecionado")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .spacing(.xxLarge))
            .padding(.vertical, .spacing(.xLarge))
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

        let retryAction: () -> Void

        var body: some View {
            VStack(spacing: .spacing(.medium)) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                VStack(spacing: .spacing(.xxSmall)) {
                    Text("Não Foi Possível Obter os Dados")
                        .font(.headline)

                    Text("Infelizmente o ranking não carregou desta vez. Tente de novo daqui a pouco.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                Button {
                    retryAction()
                } label: {
                    Label("Tentar Novamente", systemImage: "arrow.clockwise")
                }
                .borderedButton(colored: .accentColor)
                .padding(.top, .spacing(.xxSmall))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .spacing(.xxLarge))
            // Same room below as a loaded ranking leaves under "Última consulta".
            .padding(.bottom, .spacing(.medium))
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
