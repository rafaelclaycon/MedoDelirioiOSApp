//
//  FakeSearchService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 06/05/25.
//

import Foundation

final class FakeSearchService: SearchServiceProtocol {

    var reactionsState: LoadingState<[Reaction]> = .loaded([])

    func results(matching searchString: String, mode: SearchMode) -> SearchResults {
        SearchResults()
    }

    func searchTranscripts(matching searchString: String) async -> [EpisodeTranscriptGroup] {
        []
    }

    func loadReactions() async {
        reactionsState = .loaded([])
    }

    func save(searchString: String) {
        //
    }

    func recentSearches() -> [String] {
        []
    }

    func clearRecentSearches() {
        //
    }

    func invalidateTranscriptCache() {
        //
    }

    func releaseTranscriptCache() {
        //
    }
}
