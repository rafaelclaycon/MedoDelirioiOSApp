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
    var retryLoadReactionsAction: (() async -> Void)? = nil

    @State private var columns: [GridItem] = []

    private let itemCountWhenCollapsed: Int = 4

    private var hasAnyNonReactionResults: Bool {
        let hasContent = !(results.soundsMatchingTitle?.isEmpty ?? true) ||
            !(results.soundsMatchingContent?.isEmpty ?? true) ||
            !(results.songsMatchingTitle?.isEmpty ?? true) ||
            !(results.songsMatchingContent?.isEmpty ?? true) ||
            !(results.authors?.isEmpty ?? true) ||
            !(results.folders?.isEmpty ?? true) ||
            !(results.episodesMatchingTitle?.isEmpty ?? true) ||
            !(results.episodesMatchingDescription?.isEmpty ?? true)
        return hasContent
    }

    private var showNoResultsView: Bool {
        // Show no results only if we have no content AND reactions are loaded with no matches
        guard !hasAnyNonReactionResults else { return false }
        guard case .loaded = reactionsState else { return false }
        let hasMatchingTitle = !(results.reactionsMatchingTitle?.isEmpty ?? true)
        let hasMatchingFeeling = !(results.reactionsMatchingFeeling?.isEmpty ?? true)
        return !hasMatchingTitle && !hasMatchingFeeling
    }

    // MARK: - Environment

    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.push) private var push

    // MARK: - View Body

    var body: some View {
        if showNoResultsView {
            NoSearchResultsView(searchText: searchString)
        } else {
            VStack(spacing: .spacing(.medium)) {
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

                    // MARK: - Authors

                    if let authors = results.authors, !authors.isEmpty {
                        CollapsibleResultSection(
                            items: authors,
                            itemCountWhenCollapsed: itemCountWhenCollapsed,
                            headerSymbol: "person.2",
                            headerTitle: "Autores",
                            searchString: searchString,
                            contentView: { item in
                                VerticalAuthorView(author: item)
                                    .onTapGesture {
                                        push(GeneralNavigationDestination.authorDetail(item))
                                    }
                            }
                        )
                    }

                    // MARK: - Folders

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

                // MARK: - Episodes

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
                        headerTitle: "Conteúdo dos Episódios",
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

                // MARK: - Reactions

                LazyVGrid(
                    columns: columns,
                    spacing: .spacing(.medium)
                ) {
                    reactionsSection
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
            VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                Text(episode.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(episode.title)
                    .font(.body)
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
            VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                Text(episode.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(episode.title)
                    .font(.body)
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

// MARK: - Previews

#Preview("No Results") {
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
                menuOptions: []
            )
            .padding(.all, .spacing(.medium))
        }
    }
}

#Preview("Complete") {
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
                menuOptions: []
            )
            .padding(.all, .spacing(.medium))
        }
    }
}

#Preview("Reactions Loading") {
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
                menuOptions: []
            )
            .padding(.all, .spacing(.medium))
        }
    }
}

#Preview("Reactions Error") {
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
                retryLoadReactionsAction: {}
            )
            .padding(.all, .spacing(.medium))
        }
    }
}
