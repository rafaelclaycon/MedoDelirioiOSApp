//
//  SearchResultsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 20/01/25.
//

import SwiftUI

struct SearchResultsView: View {

    @Bindable var playable: PlayableContentState

    let searchString: String
    let results: SearchResults
    var reactionsState: LoadingState<[Reaction]> = .loaded([])
    let containerWidth: CGFloat
    var toast: Binding<Toast?>
    var menuOptions: [ContextMenuSection]
    @Binding var searchMode: SearchMode
    var isSearchingTranscripts: Bool = false
    var retryLoadReactionsAction: (() async -> Void)? = nil

    @State private var columns: [GridItem] = []

    private let itemCountWhenCollapsed: Int = 4

    @Environment(TranscriptDownloadService.self) private var transcriptService

    private var hasAnyNonReactionResults: Bool {
        switch searchMode {
        case .virgulas:
            return !(results.soundsMatchingTitle?.isEmpty ?? true) ||
                !(results.soundsMatchingContent?.isEmpty ?? true) ||
                !(results.songsMatchingTitle?.isEmpty ?? true) ||
                !(results.songsMatchingContent?.isEmpty ?? true) ||
                !(results.authors?.isEmpty ?? true) ||
                !(results.folders?.isEmpty ?? true)
        case .episodios:
            return !(results.episodesMatchingTitle?.isEmpty ?? true) ||
                !(results.episodesMatchingDescription?.isEmpty ?? true) ||
                !(results.episodesMatchingTranscript?.isEmpty ?? true)
        }
    }

    private var showNoResultsView: Bool {
        guard !hasAnyNonReactionResults else { return false }
        if searchMode == .virgulas {
            guard case .loaded = reactionsState else { return false }
            let hasMatchingTitle = !(results.reactionsMatchingTitle?.isEmpty ?? true)
            let hasMatchingFeeling = !(results.reactionsMatchingFeeling?.isEmpty ?? true)
            return !hasMatchingTitle && !hasMatchingFeeling
        }
        if isSearchingTranscripts { return false }
        return true
    }

    // MARK: - Environment

    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.push) private var push

    // MARK: - View Body

    var body: some View {
        VStack(spacing: .spacing(.medium)) {
            Picker("", selection: $searchMode) {
                ForEach(SearchMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, .spacing(.medium))
            .onAppear {
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.font: UIFont.systemFont(ofSize: 15, weight: .semibold)],
                    for: .normal
                )
            }

            if showNoResultsView {
                NoSearchResultsView(
                    searchText: searchString,
                    showSuggestionButton: searchMode == .virgulas
                )
            } else if searchMode == .virgulas {
                    LazyVGrid(
                        columns: columns,
                        spacing: .spacing(.medium)
                    ) {
                        // MARK: - Sounds

                        if let soundsMatchingTitle = results.soundsMatchingTitle, !soundsMatchingTitle.isEmpty {
                            CollapsibleResultSection(
                                items: soundsMatchingTitle,
                                itemCountWhenCollapsed: itemCountWhenCollapsed,
                                headerSymbol: "quote.bubble",
                                headerTitle: "Nome das Vírgulas",
                                searchString: searchString,
                                contentView: { item in
                                    PlayableContentView(
                                        content: item,
                                        favorites: playable.favoritesKeeper,
                                        highlighted: Set<String>(),
                                        nowPlaying: playable.nowPlayingKeeper,
                                        selectedItems: Set<String>(),
                                        currentContentListMode: .constant(.regular)
                                    )
                                    .contentShape(
                                        .contextMenuPreview,
                                        RoundedRectangle(cornerRadius: .spacing(.large), style: .continuous)
                                    )
                                    .onTapGesture {
                                        onContentSelected(item, loadedContent: soundsMatchingTitle)
                                    }
                                    .contextMenu {
                                        contextMenuOptionsView(
                                            content: item,
                                            menuOptions: menuOptions,
                                            favorites: playable.favoritesKeeper,
                                            loadedContent: soundsMatchingTitle
                                        )
                                    }
                                }
                            )
                        }

                        if let soundsMatchingContent = results.soundsMatchingContent, !soundsMatchingContent.isEmpty {
                            CollapsibleResultSection(
                                items: soundsMatchingContent,
                                itemCountWhenCollapsed: itemCountWhenCollapsed,
                                headerSymbol: "quote.bubble",
                                headerTitle: "Conteúdo das Vírgulas",
                                searchString: searchString,
                                contentView: { item in
                                    ContentWithDescriptionMatch(
                                        content: item,
                                        highlight: searchString,
                                        playable: playable
                                    )
                                }
                            )
                        }

                        // MARK: - Songs

                        if let songsMatchingTitle = results.songsMatchingTitle, !songsMatchingTitle.isEmpty {
                            CollapsibleResultSection(
                                items: songsMatchingTitle,
                                itemCountWhenCollapsed: itemCountWhenCollapsed,
                                headerSymbol: "music.quarternote.3",
                                headerTitle: "Nome das Músicas",
                                searchString: searchString,
                                contentView: { item in
                                    PlayableContentView(
                                        content: item,
                                        favorites: playable.favoritesKeeper,
                                        highlighted: Set<String>(),
                                        nowPlaying: playable.nowPlayingKeeper,
                                        selectedItems: Set<String>(),
                                        currentContentListMode: .constant(.regular)
                                    )
                                    .contentShape(
                                        .contextMenuPreview,
                                        RoundedRectangle(cornerRadius: .spacing(.large), style: .continuous)
                                    )
                                    .onTapGesture {
                                        onContentSelected(item, loadedContent: songsMatchingTitle)
                                    }
                                    .contextMenu {
                                        contextMenuOptionsView(
                                            content: item,
                                            menuOptions: menuOptions,
                                            favorites: playable.favoritesKeeper,
                                            loadedContent: songsMatchingTitle
                                        )
                                    }
                                }
                            )
                        }

                        if let songsMatchingContent = results.songsMatchingContent, !songsMatchingContent.isEmpty {
                            CollapsibleResultSection(
                                items: songsMatchingContent,
                                itemCountWhenCollapsed: itemCountWhenCollapsed,
                                headerSymbol: "music.quarternote.3",
                                headerTitle: "Conteúdo das Músicas",
                                searchString: searchString,
                                contentView: { item in
                                    ContentWithDescriptionMatch(
                                        content: item,
                                        highlight: searchString,
                                        playable: playable
                                    )
                                }
                            )
                        }

                    }

                    // MARK: - Authors

                    LazyVGrid(
                        columns: [GridItem(.flexible())],
                        spacing: .spacing(.medium)
                    ) {
                        if let authors = results.authors, !authors.isEmpty {
                            CollapsibleResultSection(
                                items: authors,
                                itemCountWhenCollapsed: itemCountWhenCollapsed,
                                headerSymbol: "person.2",
                                headerTitle: "Autores",
                                searchString: searchString,
                                contentView: { item in
                                    HorizontalAuthorView(author: item)
                                        .onTapGesture {
                                            push(GeneralNavigationDestination.authorDetail(item))
                                        }
                                }
                            )
                        }
                    }

                    // MARK: - Folders

                    LazyVGrid(
                        columns: columns,
                        spacing: .spacing(.medium)
                    ) {
                        if let folders = results.folders, !folders.isEmpty {
                            CollapsibleResultSection(
                                items: folders,
                                itemCountWhenCollapsed: itemCountWhenCollapsed,
                                headerSymbol: "folder",
                                headerTitle: "Pastas",
                                searchString: searchString,
                                contentView: { item in
                                    FolderView(folder: item)
                                        .onTapGesture {
                                            push(GeneralNavigationDestination.folderDetail(item))
                                        }
                                }
                            )
                        }
                    }

                    // MARK: - Reactions

                    LazyVGrid(
                        columns: columns,
                        spacing: .spacing(.medium)
                    ) {
                        reactionsSection
                    }
                }

                if searchMode == .episodios {
                    // MARK: - Episode Transcripts

                    if transcriptService.transcriptsDownloaded {
                        TranscriptDownloadBannerView()

                        if isSearchingTranscripts {
                            TranscriptSearchLoadingView()
                        } else if let groups = results.episodesMatchingTranscript, !groups.isEmpty {
                            CollapsibleResultSection(
                                items: groups,
                                itemCountWhenCollapsed: itemCountWhenCollapsed,
                                headerSymbol: "text.quote",
                                headerTitle: "Transcrições dos Episódios",
                                searchString: searchString,
                                contentView: { group in
                                    TranscriptEpisodeCard(
                                        group: group,
                                        highlight: searchString
                                    )
                                }
                            )
                        }
                    } else if case .downloading = transcriptService.state {
                        TranscriptDownloadBannerView()
                    } else if case .failed = transcriptService.state {
                        TranscriptDownloadBannerView()
                    } else {
                        TranscriptDownloadPromptView()
                    }

                    // MARK: - Episodes (always visible)

                    if let episodesMatchingTitle = results.episodesMatchingTitle, !episodesMatchingTitle.isEmpty {
                        CollapsibleResultSection(
                            items: episodesMatchingTitle,
                            itemCountWhenCollapsed: itemCountWhenCollapsed,
                            headerSymbol: "radio",
                            headerTitle: "Nome dos Episódios",
                            searchString: searchString,
                            contentView: { episode in
                                EpisodeSearchResult(episode: episode)
                                    .onTapGesture {
                                        push(GeneralNavigationDestination.episodeDetail(episode))
                                    }
                            }
                        )
                    }

                    if let episodesMatchingDescription = results.episodesMatchingDescription, !episodesMatchingDescription.isEmpty {
                        CollapsibleResultSection(
                            items: episodesMatchingDescription,
                            itemCountWhenCollapsed: itemCountWhenCollapsed,
                            headerSymbol: "radio",
                            headerTitle: "Descrição dos Episódios",
                            searchString: searchString,
                            contentView: { episode in
                                EpisodeDescriptionSearchResult(
                                    episode: episode,
                                    highlight: searchString
                                )
                                .onTapGesture {
                                    push(GeneralNavigationDestination.episodeDetail(episode))
                                }
                            }
                        )
                    }
                }
            }
            .playableContentUI(
                state: playable,
                toast: toast,
                onAuthorSelected: { author in
                    push(GeneralNavigationDestination.authorDetail(author))
                },
                onReactionSelected: { reaction in
                    push(GeneralNavigationDestination.reactionDetail(reaction))
                }
            )
            .onAppear {
                playable.onViewAppeared()
                updateGridLayout()
            }
            .onChange(of: containerWidth) {
                updateGridLayout()
            }
    }

    // MARK: - Actions

    private func onContentSelected(
        _ content: AnyEquatableMedoContent,
        loadedContent: [AnyEquatableMedoContent]
    ) {
        if playable.nowPlayingKeeper.contains(content.id) {
            AudioPlayer.shared?.togglePlay()
            playable.nowPlayingKeeper.removeAll()
        } else {
            playable.play(content)
        }
    }

    // MARK: - Subviews

    @MainActor @ViewBuilder
    private var reactionsSection: some View {
        switch reactionsState {
        case .loading:
            Section {
                ReactionsLoadingView()
            } header: {
                HeaderView(
                    symbol: "theatermasks",
                    title: "Reações",
                    resultCount: 0
                )
            }

        case .error(let message):
            Section {
                ReactionsErrorView(
                    message: message,
                    retryAction: retryLoadReactionsAction
                )
            } header: {
                HeaderView(
                    symbol: "theatermasks",
                    title: "Reações",
                    resultCount: 0
                )
            }

        case .loaded:
            if let reactionsMatchingTitle = results.reactionsMatchingTitle, !reactionsMatchingTitle.isEmpty {
                CollapsibleResultSection(
                    items: reactionsMatchingTitle,
                    itemCountWhenCollapsed: itemCountWhenCollapsed,
                    headerSymbol: "theatermasks",
                    headerTitle: "Reações",
                    searchString: searchString,
                    contentView: { item in
                        ReactionItem(reaction: item)
                            .onTapGesture {
                                push(GeneralNavigationDestination.reactionDetail(item))
                            }
                    }
                )
            }

            if let reactionsMatchingFeeling = results.reactionsMatchingFeeling, !reactionsMatchingFeeling.isEmpty {
                CollapsibleResultSection(
                    items: reactionsMatchingFeeling,
                    itemCountWhenCollapsed: itemCountWhenCollapsed,
                    headerSymbol: "theatermasks",
                    headerTitle: "Reações que expressam o sentimento de \"\(searchString)\"",
                    searchString: searchString,
                    contentView: { item in
                        ReactionItem(reaction: item)
                            .onTapGesture {
                                push(GeneralNavigationDestination.reactionDetail(item))
                            }
                    }
                )
            }
        }
    }

    @MainActor @ViewBuilder
    private func contextMenuOptionsView(
        content: AnyEquatableMedoContent,
        menuOptions: [ContextMenuSection],
        favorites: Set<String>,
        loadedContent: [AnyEquatableMedoContent]
    ) -> some View {
        // Sharing section
        Section {
            Button {
                playable.share(content: content)
            } label: {
                Label(Shared.shareSoundButtonText, systemImage: "square.and.arrow.up")
            }

            Button {
                playable.openShareAsVideoModal(for: content)
            } label: {
                Label(Shared.shareAsVideoButtonText, systemImage: "film")
            }
        }

        // Organizing section
        Section {
            Button {
                playable.toggleFavorite(content.id)
            } label: {
                Label(
                    favorites.contains(content.id) ? Shared.removeFromFavorites : Shared.addToFavorites,
                    systemImage: favorites.contains(content.id) ? "star.slash" : "star"
                )
            }

            Button {
                playable.addToFolder(content)
            } label: {
                Label(Shared.addToFolderButtonText, systemImage: "folder.badge.plus")
            }
        }

        // Details section
        Section {
            Button {
                playable.showDetails(for: content)
            } label: {
                Label("Ver Detalhes", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Functions

    private func updateGridLayout() {
        columns = GridHelper.adaptableColumns(
            listWidth: containerWidth,
            sizeCategory: sizeCategory,
            spacing: .spacing(.small)
        )
    }
}

// MARK: - Subviews

extension SearchResultsView {

    struct HeaderView: View {

        let symbol: String
        let title: String
        let resultCount: Int

        private var countText: String {
            resultCount == 1 ? "1 RESULTADO" : "\(resultCount) RESULTADOS"
        }

        var body: some View {
            HStack {
                Image(systemName: symbol)

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer()

                Text(countText)
                    .font(.footnote)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, .spacing(.xSmall))
            .background(Color.systemBackground)
        }
    }

    struct ContentWithDescriptionMatch: View {

        let content: AnyEquatableMedoContent
        let highlight: String
        @Bindable var playable: PlayableContentState

        private let contextRadius = 40

        private var text: AttributedString {
            let description = content.description

            // Normalize highlight string to match search behavior (strip punctuation, handle diacritics)
            let normalizedHighlight = highlight
                .folding(options: .diacriticInsensitive, locale: .current)
                .replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)

            // Find the match location using normalized search
            guard let matchRange = description.range(
                of: normalizedHighlight,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) else {
                return AttributedString(description)
            }

            // Calculate snippet bounds centered around the match
            let matchStartOffset = description.distance(from: description.startIndex, to: matchRange.lowerBound)
            let matchEndOffset = description.distance(from: description.startIndex, to: matchRange.upperBound)

            let snippetStartOffset = max(0, matchStartOffset - contextRadius)
            let snippetEndOffset = min(description.count, matchEndOffset + contextRadius)

            let snippetStart = description.index(description.startIndex, offsetBy: snippetStartOffset)
            let snippetEnd = description.index(description.startIndex, offsetBy: snippetEndOffset)

            var snippet = String(description[snippetStart..<snippetEnd])

            // Add ellipsis if truncated
            if snippetStartOffset > 0 { snippet = "..." + snippet }
            if snippetEndOffset < description.count { snippet = snippet + "..." }

            // Apply highlight to the snippet using normalized search
            var attributedString = AttributedString(snippet)
            if let range = attributedString.range(
                of: normalizedHighlight,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                attributedString[range].foregroundColor = .yellow
                attributedString[range].font = .headline
            }
            return attributedString
        }

        var body: some View {
            VStack {
                PlayableContentView(
                    content: content,
                    favorites: playable.favoritesKeeper,
                    highlighted: Set<String>(),
                    nowPlaying: playable.nowPlayingKeeper,
                    selectedItems: Set<String>(),
                    currentContentListMode: .constant(.regular)
                )
                .contentShape(
                    .contextMenuPreview,
                    RoundedRectangle(cornerRadius: .spacing(.large), style: .continuous)
                )
                .onTapGesture {
                    if playable.nowPlayingKeeper.contains(content.id) {
                        AudioPlayer.shared?.togglePlay()
                        playable.nowPlayingKeeper.removeAll()
                    } else {
                        playable.play(content)
                    }
                }
                .contextMenu {
                    Section {
                        Button {
                            playable.share(content: content)
                        } label: {
                            Label(Shared.shareSoundButtonText, systemImage: "square.and.arrow.up")
                        }

                        Button {
                            playable.openShareAsVideoModal(for: content)
                        } label: {
                            Label(Shared.shareAsVideoButtonText, systemImage: "film")
                        }
                    }

                    Section {
                        Button {
                            playable.toggleFavorite(content.id)
                        } label: {
                            Label(
                                playable.favoritesKeeper.contains(content.id) ? Shared.removeFromFavorites : Shared.addToFavorites,
                                systemImage: playable.favoritesKeeper.contains(content.id) ? "star.slash" : "star"
                            )
                        }

                        Button {
                            playable.addToFolder(content)
                        } label: {
                            Label(Shared.addToFolderButtonText, systemImage: "folder.badge.plus")
                        }
                    }

                    Section {
                        Button {
                            playable.showDetails(for: content)
                        } label: {
                            Label("Ver Detalhes", systemImage: "info.circle")
                        }
                    }
                }

                Text("\"\(text)\"")
                    .italic()
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.gray)

                Spacer()
            }
        }
    }

    struct CollapsibleResultSection<T: Identifiable, ItemView: View>: View {

        let items: [T]
        let itemCountWhenCollapsed: Int
        let headerSymbol: String
        let headerTitle: String
        let searchString: String
        let contentView: (T) -> ItemView

        @State private var isCollapsed: Bool = true

        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            Section {
                if isCollapsed {
                    ForEach(items.prefix(itemCountWhenCollapsed)) { item in
                        contentView(item)
                    }
                } else {
                    ForEach(items) { item in
                        contentView(item)
                    }
                }
            } header: {
                HeaderView(
                    symbol: headerSymbol,
                    title: headerTitle,
                    resultCount: items.count
                )
            } footer: {
                if items.count > itemCountWhenCollapsed && isCollapsed {
                    if #available(iOS 26, *) {
                        HStack {
                            Spacer()
                            Text("Ver Tudo")
                                .bold()
                            Spacer()
                        }
                        .foregroundStyle(
                            colorScheme == .dark ? .primary : Color.darkestGreen
                        )
                        .frame(height: 46)
                        .glassEffect(
                            .regular.tint(
                                .accentColor.opacity(0.3)
                            ).interactive()
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                isCollapsed.toggle()
                            }
                        }
                        .accessibilityLabel("Ver todos os resultados")
                        .accessibilityAddTraits(.isButton)
                    } else {
                        Button {
                            withAnimation {
                                isCollapsed.toggle()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Ver Tudo")
                                    .bold()
                                Spacer()
                            }
                        }
                        .largeRoundedRectangleBordered(colored: .green)
                        .accessibilityLabel("Ver todos os resultados")
                    }
                }
            }
            .onChange(of: searchString) {
                isCollapsed = true
            }
        }
    }

    struct ReactionsLoadingView: View {

        var body: some View {
            HStack(spacing: .spacing(.small)) {
                ProgressView()
                Text("Carregando reações...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spacing(.medium))
        }
    }

    struct ReactionsErrorView: View {

        let message: String
        var retryAction: (() async -> Void)?

        var body: some View {
            VStack(spacing: .spacing(.small)) {
                HStack(spacing: .spacing(.xSmall)) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Erro ao carregar reações")
                        .foregroundStyle(.secondary)
                }

                if let retryAction {
                    Button {
                        Task {
                            await retryAction()
                        }
                    } label: {
                        Label("Tentar Novamente", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spacing(.medium))
        }
    }

    struct EpisodeSearchResult: View {

        let episode: PodcastEpisode

        var body: some View {
            VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                Text(episode.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(episode.title)
                    .font(.title3)
                    .fontDesign(.serif)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacing(.xxSmall))
        }
    }

    struct EpisodeDescriptionSearchResult: View {

        let episode: PodcastEpisode
        let highlight: String

        private let contextRadius = 40

        private var text: AttributedString {
            let description = episode.plainTextDescription ?? ""

            let normalizedHighlight = highlight
                .folding(options: .diacriticInsensitive, locale: .current)
                .replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)

            guard let matchRange = description.range(
                of: normalizedHighlight,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) else {
                return AttributedString(description)
            }

            let matchStartOffset = description.distance(from: description.startIndex, to: matchRange.lowerBound)
            let matchEndOffset = description.distance(from: description.startIndex, to: matchRange.upperBound)

            let snippetStartOffset = max(0, matchStartOffset - contextRadius)
            let snippetEndOffset = min(description.count, matchEndOffset + contextRadius)

            let snippetStart = description.index(description.startIndex, offsetBy: snippetStartOffset)
            let snippetEnd = description.index(description.startIndex, offsetBy: snippetEndOffset)

            var snippet = String(description[snippetStart..<snippetEnd])

            if snippetStartOffset > 0 { snippet = "..." + snippet }
            if snippetEndOffset < description.count { snippet = snippet + "..." }

            var attributedString = AttributedString(snippet)
            if let range = attributedString.range(
                of: normalizedHighlight,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                attributedString[range].foregroundColor = .yellow
                attributedString[range].font = .headline
            }
            return attributedString
        }

        var body: some View {
            VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                Text(episode.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(episode.title)
                    .font(.title3)
                    .fontDesign(.serif)
                    .lineLimit(2)

                Text("\"\(text)\"")
                    .italic()
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacing(.xxSmall))
        }
    }
}

// MARK: - Transcript Episode Card

struct TranscriptEpisodeCard: View {

    let group: EpisodeTranscriptGroup
    let highlight: String

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                Text(group.episode.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(group.episode.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.serif)
                    .lineLimit(2)
            }

            ForEach(Array(group.matches.enumerated()), id: \.element.id) { index, match in
                if index > 0 {
                    Divider()
                }

                TranscriptCueRow(
                    match: match,
                    episode: group.episode,
                    highlight: highlight
                )
            }
        }
        .padding(.spacing(.medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

struct TranscriptCueRow: View {

    let match: TranscriptMatch
    let episode: PodcastEpisode
    let highlight: String

    @Environment(EpisodePlayer.self) private var player
    @State private var showDownloadConfirmation = false
    @State private var isLoading = false

    private var highlightedText: AttributedString {
        let source = match.cueText
        let normalizedHighlight = highlight
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)

        var attributed = AttributedString(source)
        if let range = attributed.range(
            of: normalizedHighlight,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) {
            attributed[range].foregroundColor = .yellow
            attributed[range].font = .body.bold()
        }
        return attributed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
            HStack(spacing: .spacing(.xSmall)) {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.darkerGreen)

                Text(match.formattedTimestamp)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(Color.darkerGreen)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(highlightedText)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .spacing(.xxxSmall))
        .contentShape(Rectangle())
        .opacity(isLoading ? 0.6 : 1)
        .onTapGesture {
            guard !isLoading else { return }
            handleTap()
        }
        .alert(
            "Baixar e reproduzir a partir de \(match.formattedTimestamp)?",
            isPresented: $showDownloadConfirmation
        ) {
            Button("Baixar e Reproduzir") {
                playFromTimestamp()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(episode.title)
        }
    }

    private func handleTap() {
        if EpisodePlayer.isDownloaded(episode) || player.isCurrentEpisode(episode) {
            playFromTimestamp()
        } else {
            showDownloadConfirmation = true
        }
    }

    private func playFromTimestamp() {
        isLoading = true
        Task {
            await player.play(episode: episode)
            try? await Task.sleep(for: .milliseconds(300))
            player.seek(to: match.timestamp)
            isLoading = false
        }
    }
}

// MARK: - Transcript Download Prompt

struct TranscriptSearchLoadingView: View {

    var body: some View {
        HStack(spacing: .spacing(.small)) {
            ProgressView()
            Text("Buscando nas transcrições...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacing(.medium))
    }
}

struct TranscriptDownloadPromptView: View {

    var icon: String = "arrow.down.circle"
    var title: String = "Buscar dentro dos episódios?"
    var subtitle: String = "Para pesquisar nas transcrições dos episódios, é necessário baixar os arquivos primeiro. Isso usa poucos dados."
    var priorityEpisodeId: String? = nil
    var analyticsSource: String = "Search"

    @Environment(TranscriptDownloadService.self) private var service
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: .spacing(.large)) {
            Spacer()
                .frame(height: .spacing(.large))

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .spacing(.large))

            if #available(iOS 26, *) {
                Button {
                    Task { await service.downloadTranscripts(priorityEpisodeId: priorityEpisodeId) }
                    Task { await AnalyticsService().send(originatingScreen: analyticsSource, action: "transcripts_opted_in") }
                } label: {
                    Text("Baixar Transcrições")
                        .font(.callout)
                        .bold()
                        .foregroundStyle(colorScheme == .dark ? .primary : Color.darkestGreen)
                        .padding(.vertical, .spacing(.small))
                        .padding(.horizontal, .spacing(.xLarge))
                        .glassEffect(
                            .regular.tint(
                                Color.green.opacity(0.3)
                            ).interactive()
                        )
                }
            } else {
                Button {
                    Task { await service.downloadTranscripts(priorityEpisodeId: priorityEpisodeId) }
                    Task { await AnalyticsService().send(originatingScreen: analyticsSource, action: "transcripts_opted_in") }
                } label: {
                    HStack {
                        Spacer()
                        Text("Baixar Transcrições")
                            .bold()
                        Spacer()
                    }
                }
                .largeRoundedRectangleBordered(colored: .green)
                .padding(.horizontal, .spacing(.huge))
            }

            Spacer()
                .frame(height: .spacing(.large))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("No Results") {
    @Previewable @State var searchMode: SearchMode = .virgulas

    GeometryReader { geometry in
        ScrollView {
            SearchResultsView(
                playable: PlayableContentState(
                    contentRepository: FakeContentRepository(),
                    contentFileManager: ContentFileManager(),
                    analyticsService: FakeAnalyticsService(),
                    screen: .searchResultsView,
                    toast: .constant(nil)
                ),
                searchString: "Bolsorrrgnnn",
                results: SearchResults(),
                reactionsState: .loaded([]),
                containerWidth: geometry.size.width,
                toast: .constant(nil),
                menuOptions: [],
                searchMode: $searchMode
            )
            .padding(.all, .spacing(.medium))
        }
    }
}

#Preview("Complete") {
    @Previewable @State var searchMode: SearchMode = .virgulas

    GeometryReader { geometry in
        ScrollView {
            SearchResultsView(
                playable: PlayableContentState(
                    contentRepository: FakeContentRepository(),
                    contentFileManager: ContentFileManager(),
                    analyticsService: FakeAnalyticsService(),
                    screen: .searchResultsView,
                    toast: .constant(nil)
                ),
                searchString: "Bolso",
                results: SearchResults(
                    soundsMatchingTitle: Sound.sampleSounds.map { AnyEquatableMedoContent($0) },
                    soundsMatchingContent: [Sound.sampleBolsoA, Sound.sampleBolsoB].map { AnyEquatableMedoContent($0) },
                    authors: [.bozo, .omarAziz],
                    folders: [.mockA, .mockB],
                    reactionsMatchingTitle: [.viralMock, .choqueMock],
                    reactionsMatchingFeeling: [.viralMock]
                ),
                reactionsState: .loaded([]),
                containerWidth: geometry.size.width,
                toast: .constant(nil),
                menuOptions: [],
                searchMode: $searchMode
            )
            .padding(.all, .spacing(.medium))
        }
    }
}

#Preview("Reactions Loading") {
    @Previewable @State var searchMode: SearchMode = .virgulas

    GeometryReader { geometry in
        ScrollView {
            SearchResultsView(
                playable: PlayableContentState(
                    contentRepository: FakeContentRepository(),
                    contentFileManager: ContentFileManager(),
                    analyticsService: FakeAnalyticsService(),
                    screen: .searchResultsView,
                    toast: .constant(nil)
                ),
                searchString: "Bolso",
                results: SearchResults(
                    soundsMatchingTitle: Sound.sampleSounds.map { AnyEquatableMedoContent($0) }
                ),
                reactionsState: .loading,
                containerWidth: geometry.size.width,
                toast: .constant(nil),
                menuOptions: [],
                searchMode: $searchMode
            )
            .padding(.all, .spacing(.medium))
        }
    }
}

#Preview("Reactions Error") {
    @Previewable @State var searchMode: SearchMode = .virgulas

    GeometryReader { geometry in
        ScrollView {
            SearchResultsView(
                playable: PlayableContentState(
                    contentRepository: FakeContentRepository(),
                    contentFileManager: ContentFileManager(),
                    analyticsService: FakeAnalyticsService(),
                    screen: .searchResultsView,
                    toast: .constant(nil)
                ),
                searchString: "Bolso",
                results: SearchResults(
                    soundsMatchingTitle: Sound.sampleSounds.map { AnyEquatableMedoContent($0) }
                ),
                reactionsState: .error("Não foi possível conectar ao servidor"),
                containerWidth: geometry.size.width,
                toast: .constant(nil),
                menuOptions: [],
                searchMode: $searchMode,
                retryLoadReactionsAction: {}
            )
            .padding(.all, .spacing(.medium))
        }
    }
}
