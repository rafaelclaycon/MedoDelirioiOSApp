//
//  StandaloneSearchView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 03/05/25.
//

import SwiftUI

struct StandaloneSearchView: View {

    let searchService: SearchServiceProtocol
    let trendsService: TrendsServiceProtocol
    let contentRepository: ContentRepositoryProtocol
    let userFolderRepository: UserFolderRepositoryProtocol
    let analyticsService: AnalyticsServiceProtocol

    @State private var searchText: String = ""
    @State private var searchResults = SearchResults()
    @State private var toast: Toast? = nil
    @State private var playable: PlayableContentState?
    @State private var reactionsState: LoadingState<[Reaction]> = .loading
    @State private var showFeedbackAlert: Bool = false
    @State private var searchMode: SearchMode = .virgulas
    @State private var searchTask: Task<Void, Never>?
    @State private var transcriptSearchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var isSearchingTranscripts = false

    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService
    @Environment(\.push) private var push

    private var searchPrompt: String {
        switch searchMode {
        case .virgulas:
            Shared.Search.searchPrompt
        case .episodios:
            Shared.Search.episodeSearchPrompt
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: .spacing(.xSmall)) {
                    if let playable {
                        if searchText.isEmpty {
                            SearchSuggestionsView(
                                recent: searchService.recentSearches(),
                                playable: playable,
                                trendsService: trendsService,
                                onRecentSelectedAction: {
                                    searchText = $0
                                },
                                onReactionSelectedAction: { push(GeneralNavigationDestination.reactionDetail($0)) },
                                containerWidth: geometry.size.width,
                                toast: $toast,
                                onClearSearchesAction: searchService.clearRecentSearches
                            )
                            .padding(.horizontal, .spacing(.medium))
                        } else {
                            SearchResultsView(
                                playable: playable,
                                searchString: searchText,
                                results: searchResults,
                                reactionsState: reactionsState,
                                containerWidth: geometry.size.width,
                                toast: $toast,
                                menuOptions: [.sharingOptions(), .organizingOptions(), .detailsOptions()],
                                searchMode: $searchMode,
                                isSearching: isSearching,
                                isSearchingTranscripts: isSearchingTranscripts,
                                retryLoadReactionsAction: loadReactions
                            )
                            .padding(.horizontal, UIDevice.isiPhone ? .spacing(.xSmall) : 0)
                        }
                    }
                }
                .padding(.all, UIDevice.isiPad ? .spacing(.medium) : .spacing(.xSmall))
                .navigationTitle(Text("Buscar"))
                .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: searchPrompt)
                .autocorrectionDisabled()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showFeedbackAlert = true
                        } label: {
                            Image(systemName: "bubble.left.and.text.bubble.right")
                        }
                    }
                }
                .alert(
                    Shared.Search.Feedback.alertTitle,
                    isPresented: $showFeedbackAlert
                ) {
                    Button("Cancelar", role: .cancel) { }
                    Button("Continuar") {
                        Task {
                            await Mailman.openDefaultEmailApp(
                                subject: Shared.Search.Feedback.emailSubject,
                                body: Shared.Search.Feedback.emailBody
                            )
                        }
                    }
                } message: {
                    Text(Shared.Search.Feedback.alertMessage)
                }
                .onChange(of: searchText) {
                    onSearchStringChanged(newString: searchText)
                }
                .onChange(of: searchMode) {
                    onSearchModeChanged()
                }
                .onChange(of: transcriptDownloadService.transcriptsDownloaded) {
                    if transcriptDownloadService.transcriptsDownloaded,
                       searchMode == .episodios,
                       !searchText.isEmpty {
                        startDebouncedTranscriptSearch(searchText)
                    }
                }
            }
            .toast($toast)
            .onAppear {
                if playable == nil {
                    playable = PlayableContentState(
                        contentRepository: contentRepository,
                        contentFileManager: ContentFileManager(),
                        analyticsService: analyticsService,
                        screen: .searchResultsView,
                        toast: $toast
                    )
                }
            }
            .task {
                await loadReactions()
            }
        }
    }

    private func loadReactions() async {
        reactionsState = .loading
        await searchService.loadReactions()
        reactionsState = searchService.reactionsState
    }

    private func onSearchStringChanged(newString: String) {
        runSearch(text: newString, mode: searchMode, debounceMs: 250)
    }

    private func onSearchModeChanged() {
        if searchMode != .episodios {
            isSearchingTranscripts = false
        }
        runSearch(text: searchText, mode: searchMode, debounceMs: 0)
    }

    private func runSearch(text: String, mode: SearchMode, debounceMs: Int) {
        searchTask?.cancel()
        transcriptSearchTask?.cancel()
        guard !text.isEmpty else {
            searchResults.clearAll()
            isSearching = false
            isSearchingTranscripts = false
            searchService.releaseTranscriptCache()
            return
        }
        isSearching = true
        searchTask = Task {
            if debounceMs > 0 {
                try? await Task.sleep(for: .milliseconds(debounceMs))
                guard !Task.isCancelled else { return }
            }
            let results = searchService.results(matching: text, mode: mode)
            guard !Task.isCancelled else { return }
            searchResults = results
            isSearching = false
            if mode == .episodios {
                startDebouncedTranscriptSearch(text)
            }
        }
    }

    private func startDebouncedTranscriptSearch(_ text: String) {
        transcriptSearchTask?.cancel()
        isSearchingTranscripts = true
        transcriptSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = await searchService.searchTranscripts(matching: text)
            guard !Task.isCancelled else { return }
            searchResults.episodesMatchingTranscript = results
            isSearchingTranscripts = false
        }
    }
}

// MARK: - Preview

#Preview {
    StandaloneSearchView(
        searchService: SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: FakeAppPersistentMemory(),
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        ),
        trendsService: TrendsService(
            database: FakeLocalDatabase(),
            apiClient: FakeAPIClient(),
            contentRepository: FakeContentRepository()
        ),
        contentRepository: FakeContentRepository(),
        userFolderRepository: FakeUserFolderRepository(),
        analyticsService: FakeAnalyticsService()
    )
}
