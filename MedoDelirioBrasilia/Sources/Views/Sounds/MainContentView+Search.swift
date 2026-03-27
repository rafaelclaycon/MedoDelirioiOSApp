//
//  MainContentView+Search.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

// MARK: - Search

extension MainContentView {

    @ViewBuilder
    var searchSuggestionsContent: some View {
        if let searchPlayable {
            SearchSuggestionsView(
                recent: searchService.recentSearches(),
                playable: searchPlayable,
                trendsService: TrendsService.shared,
                onRecentSelectedAction: { text in
                    searchText = text
                },
                onReactionSelectedAction: { reaction in
                    push(GeneralNavigationDestination.reactionDetail(reaction))
                },
                containerWidth: UIScreen.main.bounds.width - 32,
                toast: $searchToast,
                onClearSearchesAction: {
                    searchService.clearRecentSearches()
                }
            )
        }
    }

    func onSearchTextChanged(newString: String) {
        transcriptSearchTask?.cancel()
        guard !newString.isEmpty else {
            searchResults.clearAll()
            isSearchingTranscripts = false
            searchService.releaseTranscriptCache()
            return
        }
        searchResults = searchService.results(matching: newString, mode: searchMode)
        if searchMode == .episodios {
            startDebouncedTranscriptSearch(newString)
        }
    }

    func onSearchModeChanged() {
        transcriptSearchTask?.cancel()
        guard !searchText.isEmpty else { return }
        searchResults = searchService.results(matching: searchText, mode: searchMode)
        if searchMode == .episodios {
            startDebouncedTranscriptSearch(searchText)
        } else {
            isSearchingTranscripts = false
        }
    }

    func startDebouncedTranscriptSearch(_ text: String) {
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

    func loadReactions() async {
        reactionsState = .loading
        await searchService.loadReactions()
        reactionsState = searchService.reactionsState
    }
}
