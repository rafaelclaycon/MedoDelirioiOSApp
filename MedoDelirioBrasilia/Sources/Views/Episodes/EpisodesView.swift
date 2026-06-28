//
//  EpisodesView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import SwiftUI

struct EpisodesView: View {

    @Environment(EpisodePlayer.self) private var episodePlayer
    @Environment(EpisodeFavoritesStore.self) private var favoritesStore
    @Environment(EpisodeProgressStore.self) private var progressStore
    @Environment(EpisodePlayedStore.self) private var playedStore
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore
    @Environment(EpisodesBadgeStore.self) private var badgeStore
    @Environment(TranscriptDownloadService.self) private var transcriptService
    @Environment(\.push) private var push
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var viewModel = ViewModel(episodesService: EpisodesService.shared)
    @State private var selectedFilter: EpisodeFilterOption = .all
    @State private var activePlaybackStates: Set<EpisodePlaybackStateFilter> = EpisodesView.loadPlaybackStates()
    @State private var sortAscending = false
    @State private var showEpisodeNotificationsBanner = true
    @State private var showNotificationSettings = false

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            switch viewModel.state {
            case .loading:
                LoadingView(
                    width: geometry.size.width,
                    height: geometry.size.height
                )

            case .loaded(let episodes):
                let filtered = filteredEpisodes(from: episodes)

                if episodes.isEmpty {
                    ContentUnavailableView(
                        "Nenhum Episódio",
                        systemImage: "radio",
                        description: Text("Não foi possível encontrar episódios no momento.")
                    )
                } else {
                    VStack(spacing: 0) {
                        ContentModePicker(
                            options: EpisodeFilterOption.allCases,
                            selected: $selectedFilter,
                            allowScrolling: true
                        )
                        .scrollClipDisabled()

                        if
                            !AppPersistentMemory.shared.getHasDismissedEpisodeNotificationsBanner()
                            && !UserSettings().getEnableEpisodeNotifications()
                            && showEpisodeNotificationsBanner
                        {
                            EpisodeNotificationsBannerView(isBeingShown: $showEpisodeNotificationsBanner)
                                .padding([.top, .horizontal], .spacing(.medium))
                        }

                        TranscriptDownloadBannerView()
                            .padding([.top, .horizontal], .spacing(.medium))

                        if filtered.isEmpty {
                            emptyStateForFilter(selectedFilter)
                        } else {
                            List {
                                ForEach(groupedByYear(filtered)) { group in
                                    Section {
                                        ForEach(group.episodes) { episode in
                                            episodeRow(for: episode)
                                        }
                                    } header: {
                                        Text(String(group.year))
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .listRowInsets(EdgeInsets(
                                                top: 0,
                                                leading: horizontalRowInset,
                                                bottom: 0,
                                                trailing: horizontalRowInset
                                            ))
                                    }
                                }

                                if CommandLine.arguments.contains("-SHOW_MORE_DEV_OPTIONS") {
                                    Section {
                                        Text("\(episodes.count) episodes in DB · \(filtered.count) after filters")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .listRowSeparator(.hidden)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .refreshable {
                                await viewModel.onPullToRefresh()
                            }
                        }
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
            }
        }
        .navigationTitle("Episódios")
        .sheet(isPresented: $showNotificationSettings, onDismiss: {
            badgeStore.recompute()
        }) {
            NavigationStack {
                NotificationsSettingsView(showCloseButton: true)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showNotificationSettings = true
                } label: {
                    Image(systemName: "bell.badge")
                }
                .accessibilityLabel("Configurações de notificações")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(EpisodePlaybackStateFilter.allCases, id: \.self) { state in
                        Button {
                            togglePlaybackState(state)
                        } label: {
                            Label(
                                state.displayName,
                                systemImage: activePlaybackStates.contains(state) ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                } label: {
                    Image(
                        systemName: activePlaybackStates == EpisodePlaybackStateFilter.allSet
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                }
                .accessibilityLabel("Filtrar por estado")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Ordenação", selection: $sortAscending) {
                        Text("Mais Recentes no Topo")
                            .tag(false)

                        Text("Mais Antigos no Topo")
                            .tag(true)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Ordenar episódios")
            }
        }
        .oneTimeTask {
            await viewModel.onViewLoaded()
        }
        .onAppear {
            badgeStore.markAsVisited()
            Task {
                await AnalyticsService().send(
                    originatingScreen: "EpisodesView",
                    action: "didViewEpisodesScreen"
                )
            }
        }
        .onChange(of: activePlaybackStates) {
            savePlaybackStates()
        }
        .topToast($viewModel.toast)
        .background(EpisodePlayerAlerts(player: episodePlayer))
    }

    // MARK: - Empty States

    @ViewBuilder
    private func emptyStateForFilter(_ filter: EpisodeFilterOption) -> some View {
        switch filter {
        case .all:
            emptyStateForPlaybackState

        case .favorites:
            ContentUnavailableView {
                Label {
                    Text("Nenhum Favorito")
                } icon: {
                    Image(systemName: "star")
                        .foregroundStyle(.yellow)
                }
            } description: {
                Text("Deslize um episódio para a direita e toque na estrela para favoritá-lo.")
                    .padding(.top, .spacing(.nano))
            }

        case .bookmarked:
            ContentUnavailableView {
                Label {
                    Text("Nenhum Marcador")
                } icon: {
                    Image(systemName: "bookmark")
                        .foregroundStyle(Color.rubyRed)
                }
            } description: {
                Text("Use o botão de marcador na tela Reproduzindo para guardar momentos importantes.")
                    .padding(.top, .spacing(.nano))
            }
        }
    }

    private var emptyStateForPlaybackState: some View {
        ContentUnavailableView {
            Label("Nenhum Resultado", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("Nenhum episódio encontrado para os filtros selecionados.")
                .padding(.top, .spacing(.nano))
        }
    }

    // MARK: - Episode Row

    private func episodeRow(for episode: PodcastEpisode) -> some View {
        EpisodeRow(
            episode: episode,
            isFavorite: favoritesStore.isFavorite(episode.id),
            bookmarkCount: bookmarkStore.bookmarks(for: episode.id).count,
            progress: progressStore.progress(for: episode.id),
            isPlayed: playedStore.isPlayed(episode.id)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            push(episode)
        }
        .swipeActions(edge: .trailing) {
            Button {
                if !playedStore.isPlayed(episode.id) {
                    progressStore.clear(episodeID: episode.id)
                    let memory = AppPersistentMemory.shared
                    memory.setEpisodesCompletedCount(memory.getEpisodesCompletedCount() + 1)

                    if UserSettings().getAutoDeletePlayedEpisodes() {
                        try? FileManager.default.removeItem(at: EpisodePlayer.localFileURL(for: episode))
                    }
                }
                playedStore.toggle(episode.id)
            } label: {
                Label(
                    playedStore.isPlayed(episode.id) ? "Marcar como Não Finalizado" : "Marcar como Finalizado",
                    systemImage: playedStore.isPlayed(episode.id) ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button {
                favoritesStore.toggle(episode.id)
            } label: {
                Label(
                    favoritesStore.isFavorite(episode.id) ? "Desfavoritar" : "Favoritar",
                    systemImage: favoritesStore.isFavorite(episode.id) ? "star.slash" : "star"
                )
            }
            .tint(.yellow)
        }
        .listRowSeparator(.visible)
        .listRowInsets(EdgeInsets(
            top: 6,
            leading: horizontalRowInset,
            bottom: 6,
            trailing: horizontalRowInset
        ))
    }

    /// Horizontal inset for list rows. Adds extra breathing room on regular-width
    /// layouts (iPad/Mac). Applied via `listRowInsets` rather than padding/content
    /// margins so it's symmetric and independent of the sidebar's safe area, while
    /// the scroll indicator stays on the screen edge.
    private var horizontalRowInset: CGFloat {
        hSizeClass == .regular ? 16 + .spacing(.large) : 16
    }

    // MARK: - Grouping & Filtering

    private struct EpisodeYearGroup: Identifiable {
        let year: Int
        let episodes: [PodcastEpisode]
        var id: Int { year }
    }

    private func groupedByYear(_ episodes: [PodcastEpisode]) -> [EpisodeYearGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: episodes) { calendar.component(.year, from: $0.pubDate) }
        return grouped
            .map { EpisodeYearGroup(year: $0.key, episodes: $0.value) }
            .sorted { sortAscending ? $0.year < $1.year : $0.year > $1.year }
    }

    private func filteredEpisodes(from episodes: [PodcastEpisode]) -> [PodcastEpisode] {
        let chipFiltered: [PodcastEpisode] = switch selectedFilter {
        case .all:
            episodes
        case .favorites:
            episodes.filter { favoritesStore.isFavorite($0.id) }
        case .bookmarked:
            episodes.filter { bookmarkStore.episodeIdsWithBookmarks().contains($0.id) }
        }

        let allSelected = activePlaybackStates == EpisodePlaybackStateFilter.allSet
        let stateFiltered: [PodcastEpisode] = if allSelected {
            chipFiltered
        } else {
            chipFiltered.filter { episode in
                let isFinished = playedStore.isPlayed(episode.id)
                let isStarted = !isFinished && hasProgress(episode.id)
                let isNotStarted = !isFinished && !isStarted

                return (activePlaybackStates.contains(.notStarted) && isNotStarted)
                    || (activePlaybackStates.contains(.started) && isStarted)
                    || (activePlaybackStates.contains(.finished) && isFinished)
            }
        }

        return sortAscending
            ? stateFiltered.sorted { $0.pubDate < $1.pubDate }
            : stateFiltered.sorted { $0.pubDate > $1.pubDate }
    }

    private func togglePlaybackState(_ state: EpisodePlaybackStateFilter) {
        if activePlaybackStates.contains(state) {
            if activePlaybackStates.count > 1 {
                activePlaybackStates.remove(state)
            }
        } else {
            activePlaybackStates.insert(state)
        }
    }

    // MARK: - Playback State Filter Persistence

    private static let playbackStatesKey = "episodesActivePlaybackStates"

    private static func loadPlaybackStates() -> Set<EpisodePlaybackStateFilter> {
        guard let raw = UserDefaults.standard.string(forKey: playbackStatesKey) else {
            return EpisodePlaybackStateFilter.allSet
        }
        let decoded = raw.split(separator: ",").compactMap { EpisodePlaybackStateFilter(rawValue: String($0)) }
        return decoded.isEmpty ? EpisodePlaybackStateFilter.allSet : Set(decoded)
    }

    private func savePlaybackStates() {
        let raw = activePlaybackStates.map(\.rawValue).joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: Self.playbackStatesKey)
    }

    private func hasProgress(_ episodeID: String) -> Bool {
        guard let progress = progressStore.progress(for: episodeID) else { return false }
        return progress.currentTime > 0 && progress.duration > 0
    }
}

// MARK: - Subviews

extension EpisodesView {

    struct EpisodeRow: View {

        let episode: PodcastEpisode
        let isFavorite: Bool
        let bookmarkCount: Int
        let progress: EpisodeProgressStore.EpisodeProgress?
        let isPlayed: Bool
        var playCount: Int?
        var mostPopularThisWeek: Bool?

        private var hasProgress: Bool {
            guard let progress else { return false }
            return progress.currentTime > 0 && progress.duration > 0
        }

        var body: some View {
            HStack(spacing: .spacing(.xSmall)) {
                VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                    HStack(spacing: .spacing(.xxxSmall)) {
                        Text(episode.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }

                        if bookmarkCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bookmark.fill")
                                Text("\(bookmarkCount)")
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.rubyRed)
                        }

                        if let playCount {
                            Text("\(playCount) reproduções")
                                .font(.caption)
                                .padding(.leading, 10)
                                //.foregroundStyle(.secondary)
                        }
                    }

                    Text(episode.title)
                        .font(.title3)
                        .fontDesign(.serif)
                        .lineLimit(2)

                    if let plainText = episode.plainTextDescription {
                        let compressed = plainText
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        Text(compressed)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if hasProgress, let progress {
                        ProgressView(value: progress.currentTime, total: progress.duration)
                            .tint(.blue)
                            .frame(height: 6)
                    }
                }

                Spacer(minLength: 0)

                if isPlayed {
                    Image(systemName: "checkmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(width: 60)
                } else {
                    EpisodePlaybackControlsColumn(episode: episode, progress: progress)
                }
            }
            .padding(.vertical, .spacing(.small))
            .opacity(isPlayed ? 0.5 : 1.0)
        }

    }

    struct LoadingView: View {

        let width: CGFloat
        let height: CGFloat

        var body: some View {
            VStack(spacing: 50) {
                ProgressView()
                    .scaleEffect(2.0)

                Text("Carregando Episódios...")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.gray)
            }
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

                Text("Erro ao Carregar os Episódios")
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

private struct EpisodePlayerAlerts: View {
    let player: EpisodePlayer

    var body: some View {
        Color.clear
            .alert(
                "Download Grande",
                isPresented: Binding(
                    get: { player.pendingCellularDownload != nil },
                    set: { _ in }
                )
            ) {
                Button("Baixar Mesmo Assim") {
                    Task { await player.confirmCellularDownload() }
                }
                Button("Cancelar", role: .cancel) {
                    player.dismissCellularDownload()
                }
            } message: {
                Text("Você está usando dados móveis e este episódio tem aproximadamente \(player.pendingDownloadSizeMB) MB. Deseja continuar com o download?")
            }
            .alert("Erro", isPresented: Binding(
                get: { player.playerError != nil },
                set: { if !$0 { player.playerError = nil } }
            )) {
                Button("OK") { player.playerError = nil }
            } message: {
                Text(player.playerError ?? "")
            }
    }
}

// MARK: - Liquid Glass Helper

private extension View {

    @ViewBuilder
    func if_iOS26GlassElseBorderless() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.borderless)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EpisodesView()
    }
    .environment(EpisodePlayer())
    .environment(EpisodeFavoritesStore())
    .environment(EpisodeProgressStore())
    .environment(EpisodePlayedStore())
    .environment(EpisodeBookmarkStore())
    .environment(EpisodesBadgeStore())
    .environment(TranscriptDownloadService())
}

#Preview("Episode") {
    EpisodesView.EpisodeRow(
        episode: .mockLastWeek,
        isFavorite: false,
        bookmarkCount: 0,
        progress: nil,
        isPlayed: false
    )
    .padding()
    .environment(EpisodePlayer())
}

#Preview("Episode with All Bells and Whistles") {
    EpisodesView.EpisodeRow(
        episode: .mockLastWeek,
        isFavorite: true,
        bookmarkCount: 5,
        progress: .init(currentTime: 20, duration: 80),
        isPlayed: false,
        playCount: 33
    )
    .padding()
    .environment(EpisodePlayer())
}

#Preview("Played Episode") {
    EpisodesView.EpisodeRow(
        episode: .mockLastWeek,
        isFavorite: false,
        bookmarkCount: 0,
        progress: nil,
        isPlayed: true
    )
    .padding()
    .environment(EpisodePlayer())
}
