//
//  SearchSuggestionsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 03/05/25.
//

import SwiftUI

struct SearchSuggestionsView: View {

    /// Tracks whether the entrance animations have been shown this session (static to persist across view recreations)
    private static var hasShownEntranceAnimations = false

    /// Locked in once per session; persists across view recreations via the static flag.
    private static var sessionModeDecided = false
    private static var sessionMode: FeaturedSectionMode = .episode

    @State var recent: [String]
    @Bindable var playable: PlayableContentState
    let trendsService: TrendsServiceProtocol
    let onRecentSelectedAction: (String) -> Void
    let onReactionSelectedAction: (Reaction) -> Void
    let containerWidth: CGFloat
    var toast: Binding<Toast?>
    let onClearSearchesAction: () -> Void

    @State private var popularContent: LoadingState<[AnyEquatableMedoContent]> = .loading
    @State private var popularReactions: LoadingState<[Reaction]> = .loading
    @State private var shouldAnimateEntrance: Bool = false
    @State private var featuredMode: FeaturedSectionMode = .episode

    @State private var columns: [GridItem] = []

    private let phoneItemSpacing: CGFloat = .spacing(.small)
    private let padItemSpacing: CGFloat = .spacing(.medium)

    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.push) private var push
    @Environment(TranscriptDownloadService.self) private var transcriptService

    // MARK: - Computed Properties

    private var showFeatureDiscovery: Bool {
        recent.isEmpty && !hasLoadedContent
    }

    private var hasLoadedContent: Bool {
        switch (popularContent, popularReactions) {
        case (.loaded(let content), _) where !content.isEmpty:
            return true
        case (_, .loaded(let reactions)) where !reactions.isEmpty:
            return true
        default:
            return false
        }
    }

    // MARK: - View Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.xLarge)) {
            TranscriptDownloadBannerView()

            if showFeatureDiscovery {
                FeatureDiscoveryView()
            } else {
                // Recent Searches
                if !recent.isEmpty {
                    recentSearchesSection
                }

                // Featured (episode or donation)
                if FeatureFlag.isEnabled(.snowLeopard) {
//                    switch featuredMode {
//                    case .episode: featuredSection
//                    case .donation: featuredDonationSection
//                    }

                    featuredDonationSection
                }

                // Popular Content
                popularContentSection

                // Popular Reactions
                popularReactionsSection
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
            // Only animate entrance on first open of search this session
            shouldAnimateEntrance = !Self.hasShownEntranceAnimations
            if shouldAnimateEntrance {
                Self.hasShownEntranceAnimations = true
            }

            // Decide featured mode once per session
            if !Self.sessionModeDecided {
                Self.sessionMode = Self.decideFeaturedMode()
                Self.sessionModeDecided = true
            }
            featuredMode = Self.sessionMode

            playable.onViewAppeared()
            Task {
                await loadContent()
            }
            updateGridLayout()
        }
        .onChange(of: containerWidth) {
            updateGridLayout()
        }
    }

    // MARK: - Section Views

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: .spacing(.medium)) {
            HStack {
                Text("Pesquisas Recentes")
                    .font(.headline)

                Spacer()

                // TODO: Glass look for Clear button.
//                GlassButton(title: "Limpar", color: .accentColor, compact: true) {
//                    recent.removeAll()
//                    onClearSearchesAction()
//                }

                Button {
                    recent.removeAll()
                    onClearSearchesAction()
                } label: {
                    Text("Limpar")
                }
                .miniButton(colored: .green)
            }

            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                ForEach(recent, id: \.self) { text in
                    RecentSearchView(text: text)
                        .onTapGesture {
                            onRecentSelectedAction(text)
                        }
                }
            }
            .padding(.leading, .spacing(.small))
        }
    }

    // MARK: - Featured Section

    enum FeaturedSectionMode {
        case episode, donation
    }

    private enum FeaturedSectionKeys {
        static let episodeShownCount = "featured_episode_shown_count"
        static let donationShownCount = "featured_donation_shown_count"
    }

    /// Picks the mode that has been shown fewer times this far, increments its counter,
    /// and returns it. Ties go to `.episode` since that's the primary content.
    /// Only call this once per session — the result is frozen in `sessionMode`.
    private static func decideFeaturedMode() -> FeaturedSectionMode {
        let episodeCount = UserDefaults.standard.integer(forKey: FeaturedSectionKeys.episodeShownCount)
        let donationCount = UserDefaults.standard.integer(forKey: FeaturedSectionKeys.donationShownCount)

        let mode: FeaturedSectionMode = donationCount < episodeCount ? .donation : .episode

        switch mode {
        case .episode:
            UserDefaults.standard.set(episodeCount + 1, forKey: FeaturedSectionKeys.episodeShownCount)
        case .donation:
            UserDefaults.standard.set(donationCount + 1, forKey: FeaturedSectionKeys.donationShownCount)
        }

        return mode
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: .spacing(.medium)) {
            HStack {
                Text("Em Destaque")
                    .font(.headline)

                Spacer()

                Button {
                    NotificationCenter.default.post(
                        name: .navigateToTab,
                        object: nil,
                        userInfo: [NavigateToTabKey.phoneTab: PhoneTab.episodes]
                    )
                } label: {
                    HStack(spacing: 4) {
                        Text("Ver Episódios")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
            }

            FeaturedEpisodeCard()
        }
    }

    private var featuredDonationSection: some View {
        VStack(alignment: .leading, spacing: .spacing(.medium)) {
            HStack {
                Text("Em Destaque")
                    .font(.headline)

                Spacer()
            }

            FeaturedDonationView()
        }
    }

    private var popularContentHeader: some View {
        HStack {
            Text("🔥 Em Alta Hoje")
                .font(.headline)

            Spacer()

            // TODO: Glass look for See More button.
//            GlassButton(symbol: "chevron.right", title: "Ver Mais", color: .accentColor, compact: true) {
//                push(SearchNavigationDestination.trends)
//            }

            Button {
                push(SearchNavigationDestination.trends)
            } label: {
                HStack(spacing: 4) {
                    Text("Ver Mais")
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var popularContentSection: some View {
        switch popularContent {
        case .loading:
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                popularContentHeader

                LazyVGrid(columns: columns, spacing: UIDevice.deviceType == .iPhone ? phoneItemSpacing : padItemSpacing) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonContentView()
                    }
                }
            }

        case .loaded(let content) where !content.isEmpty:
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                popularContentHeader

                PopularContentGrid(
                    content: content,
                    playable: playable,
                    columns: columns,
                    phoneItemSpacing: phoneItemSpacing,
                    padItemSpacing: padItemSpacing
                )
                .if(shouldAnimateEntrance) { view in
                    view.transition(.slideFromLeading)
                }
            }

        case .error:
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                popularContentHeader

                ErrorRetryView(
                    message: "Não foi possível carregar",
                    retryAction: {
                        Task {
                            popularContent = .loading
                            await loadPopularContent()
                        }
                    }
                )
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var popularReactionsSection: some View {
        switch popularReactions {
        case .loading:
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                Text("Reações Populares")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: UIDevice.deviceType == .iPhone ? phoneItemSpacing : padItemSpacing) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonReactionView()
                    }
                }
            }

        case .loaded(let reactions) where !reactions.isEmpty:
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                Text("Reações Populares")
                    .font(.headline)

                PopularReactionsGrid(
                    reactions: reactions,
                    onReactionSelectedAction: onReactionSelectedAction,
                    columns: columns,
                    phoneItemSpacing: phoneItemSpacing,
                    padItemSpacing: padItemSpacing
                )
                .if(shouldAnimateEntrance) { view in
                    view.transition(.slideFromLeading)
                }
            }

        case .error:
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                Text("Reações Populares")
                    .font(.headline)

                ErrorRetryView(
                    message: "Não foi possível carregar",
                    retryAction: {
                        Task {
                            popularReactions = .loading
                            await loadPopularReactions()
                        }
                    }
                )
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Functions

    private func loadContent() async {
        await loadPopularContent()
        await loadPopularReactions()
    }

    private func loadPopularContent() async {
        do {
            let content = try await trendsService.top3Content()
            withAnimation(.easeOut(duration: 0.3)) {
                popularContent = .loaded(content)
            }
        } catch {
            withAnimation {
                popularContent = .error(error.localizedDescription)
            }
            debugPrint(error)
        }
    }

    private func loadPopularReactions() async {
        do {
            let reactions = try await trendsService.top3Reactions()
            withAnimation(.easeOut(duration: 0.3)) {
                popularReactions = .loaded(reactions)
            }
        } catch {
            withAnimation {
                popularReactions = .error(error.localizedDescription)
            }
            debugPrint(error)
        }
    }

    private func updateGridLayout() {
        columns = GridHelper.adaptableColumns(
            listWidth: containerWidth,
            sizeCategory: sizeCategory,
            spacing: UIDevice.deviceType == .iPhone ? phoneItemSpacing : padItemSpacing,
            deviceType: UIDevice.deviceType
        )
    }
}

// MARK: - Subviews

extension SearchSuggestionsView {

    struct RecentSearchView: View {

        let text: String

        var body: some View {
            HStack(spacing: .spacing(.xSmall)) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")

                Text(text)

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, .spacing(.xSmall))
        }
    }

    struct PopularContentGrid: View {

        let content: [AnyEquatableMedoContent]
        @Bindable var playable: PlayableContentState
        let columns: [GridItem]
        let phoneItemSpacing: CGFloat
        let padItemSpacing: CGFloat

        var body: some View {
            LazyVGrid(columns: columns, spacing: UIDevice.deviceType == .iPhone ? phoneItemSpacing : padItemSpacing) {
                ForEach(content) { item in
                    ModernContent.Button(
                        content: item,
                        favorites: playable.favoritesKeeper,
                        highlighted: Set<String>(),
                        nowPlaying: playable.nowPlayingKeeper,
                        selectedItems: Set<String>(),
                        currentContentListMode: .constant(.regular)
                    )
                    .contentShape(
                        .contextMenuPreview,
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .onTapGesture {
                        if playable.nowPlayingKeeper.contains(item.id) {
                            AudioPlayer.shared?.togglePlay()
                            playable.nowPlayingKeeper.removeAll()
                        } else {
                            playable.play(item)
                        }
                    }
                    .contextMenu {
                        // Sharing
                        Section {
                            Button {
                                playable.share(content: item)
                            } label: {
                                Label(Shared.shareSoundButtonText, systemImage: "square.and.arrow.up")
                            }

                            Button {
                                playable.openShareAsVideoModal(for: item)
                            } label: {
                                Label(Shared.shareAsVideoButtonText, systemImage: "film")
                            }
                        }

                        // Organizing
                        Section {
                            Button {
                                playable.toggleFavorite(item.id)
                            } label: {
                                Label(
                                    playable.favoritesKeeper.contains(item.id) ? Shared.removeFromFavorites : Shared.addToFavorites,
                                    systemImage: playable.favoritesKeeper.contains(item.id) ? "heart.slash" : "heart"
                                )
                            }

                            Button {
                                playable.addToFolder(item)
                            } label: {
                                Label(Shared.addToFolderButtonText, systemImage: "folder.badge.plus")
                            }
                        }

                        // Details
                        Section {
                            Button {
                                playable.showDetails(for: item)
                            } label: {
                                Label("Ver Detalhes", systemImage: "info.circle")
                            }
                        }
                    } preview: {
                        ModernContent.MenuPreview(
                            content: item,
                            isFavorite: playable.favoritesKeeper.contains(item.id)
                        )
                    }
                }
            }
        }
    }

    struct PopularReactionsGrid: View {

        let reactions: [Reaction]
        let onReactionSelectedAction: (Reaction) -> Void
        let columns: [GridItem]
        let phoneItemSpacing: CGFloat
        let padItemSpacing: CGFloat

        var body: some View {
            LazyVGrid(columns: columns, spacing: UIDevice.deviceType == .iPhone ? phoneItemSpacing : padItemSpacing) {
                ForEach(reactions) { reaction in
                    ReactionItem(reaction: reaction)
                        .onTapGesture {
                            onReactionSelectedAction(reaction)
                        }
                }
            }
        }
    }

    struct FeaturedEpisodeCard: View {

        var body: some View {
            HStack(spacing: .spacing(.xSmall)) {
                VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                    Text("II - 2026.31 - Donald Loves Lula")
                        .font(.title3)
                        .fontDesign(.serif)
                        .lineLimit(2)

                    Text("8 DE MAIO DE 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text("8 reproduções na última semana")
                        .font(.caption)
                }

                Spacer(minLength: 0)

                VStack(spacing: .spacing(.small)) {
                    Button {} label: {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .padding(.vertical, .spacing(.xxxSmall))
                    }
                    .capsule(colored: .accentColor)

                    Text("1:23:45")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 60)
            }
            .padding(.vertical, .spacing(.small))
        }
    }

    struct FeaturedDonationView: View {

        var body: some View {
            HStack(alignment: .center, spacing: .spacing(.medium)) {
                Image("puss-in-boots-donation")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: .spacing(.medium), style: .continuous))

                VStack(spacing: .spacing(.small)) {
                    DonationTierCard(
                        emoji: "☕",
                        title: "Café",
                        price: "R$ 9,90",
                        gradient: LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.72, blue: 0.25),
                                Color(red: 0.82, green: 0.38, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    DonationTierCard(
                        emoji: "❤️",
                        title: "Mensal",
                        price: "R$ 19,90",
                        gradient: LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.30, blue: 0.54),
                                Color(red: 0.50, green: 0.18, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }

        struct DonationTierCard: View {

            let emoji: String
            let title: String
            let price: String
            let gradient: LinearGradient

            var body: some View {
                Button {} label: {
                    HStack(spacing: .spacing(.small)) {
                        Text(emoji)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)

                            Text(price)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, .spacing(.medium))
                    .padding(.vertical, .spacing(.small))
                    .background(gradient)
                    .clipShape(RoundedRectangle(cornerRadius: .spacing(.medium), style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    struct FeatureDiscoveryView: View {

        private let searchableTypes: [(icon: String, name: String)] = [
            ("quote.bubble", "Vírgulas"),
            ("music.quarternote.3", "Músicas"),
            ("person.2", "Autores"),
            ("folder", "Pastas"),
            ("theatermasks", "Reações")
        ]

        var body: some View {
            VStack(spacing: .spacing(.large)) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(spacing: .spacing(.small)) {
                    Text("O que você quer encontrar?")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Use a busca para encontrar:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: .spacing(.medium)) {
                    ForEach(searchableTypes, id: \.name) { type in
                        VStack(spacing: .spacing(.xSmall)) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)

                            Text(type.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, .spacing(.small))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spacing(.xxxLarge))
        }
    }

    struct ErrorRetryView: View {

        let message: String
        let retryAction: () -> Void

        var body: some View {
            VStack(spacing: .spacing(.medium)) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    retryAction()
                } label: {
                    Label("Tentar novamente", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
        }
    }

    struct SkeletonContentView: View {

        @State private var isAnimating = false

        private let itemHeight: CGFloat = 100

        var body: some View {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray.opacity(0.2))
                .frame(height: itemHeight)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 16)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.25))
                            .frame(width: 80, height: 12)
                    }
                    .padding(.leading, 20)
                }
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear { isAnimating = true }
        }
    }

    struct SkeletonReactionView: View {

        @State private var isAnimating = false

        private var itemHeight: CGFloat {
            UIDevice.deviceType == .iPhone ? 100 : 120
        }

        var body: some View {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray.opacity(0.2))
                .frame(height: itemHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 20)
                }
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear { isAnimating = true }
        }
    }
}

// MARK: - Preview

#Preview("Featured Donation Section") {
    VStack(alignment: .leading, spacing: .spacing(.medium)) {
        HStack {
            Text("Em Destaque")
                .font(.headline)
            Spacer()
        }
        SearchSuggestionsView.FeaturedDonationView()
    }
    .padding(.spacing(.medium))
}

#Preview {
    GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    SearchSuggestionsView(
                        recent: [],
                        playable: PlayableContentState(
                            contentRepository: FakeContentRepository(),
                            contentFileManager: ContentFileManager(),
                            analyticsService: FakeAnalyticsService(),
                            screen: .searchResultsView,
                            toast: .constant(nil)
                        ),
                        trendsService: TrendsService(
                            database: FakeLocalDatabase(),
                            apiClient: FakeAPIClient(),
                            contentRepository: FakeContentRepository()
                        ),
                        onRecentSelectedAction: { _ in },
                        onReactionSelectedAction: { _ in },
                        containerWidth: geometry.size.width,
                        toast: .constant(nil),
                        onClearSearchesAction: {}
                    )

                    Spacer()
                }
            }
            .padding(.spacing(.medium))
        }
    }
    .environment(TranscriptDownloadService())
}
