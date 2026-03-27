//
//  SearchAwareContentView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

/// A view that reads `isSearching` environment and shows the appropriate content.
/// This must be a child of a view with `.searchable()` for the environment to work.
struct SearchAwareContentView<SuggestionsContent: View, GridContent: View>: View {

    let searchText: String
    let searchResults: SearchResults
    let reactionsState: LoadingState<[Reaction]>
    @Binding var searchToast: Toast?
    @Binding var isInSearchMode: Bool
    @Binding var searchMode: SearchMode
    let isSearchingTranscripts: Bool
    let searchSuggestionsContent: SuggestionsContent
    let playable: PlayableContentState?
    let containerWidth: CGFloat
    var retryLoadReactionsAction: (() async -> Void)? = nil
    @ViewBuilder let gridContent: () -> GridContent

    @Environment(\.isSearching) private var isSearching

    private var shouldShowSearchUI: Bool {
        !UIDevice.isIOS26OrLater && isSearching
    }

    var body: some View {
        Group {
            if shouldShowSearchUI && searchText.isEmpty {
                searchSuggestionsContent
            } else if shouldShowSearchUI && !searchText.isEmpty {
                if let playable {
                    SearchResultsView(
                        playable: playable,
                        searchString: searchText,
                        results: searchResults,
                        reactionsState: reactionsState,
                        containerWidth: containerWidth,
                        toast: $searchToast,
                        menuOptions: [.sharingOptions(), .organizingOptions(), .detailsOptions()],
                        searchMode: $searchMode,
                        isSearchingTranscripts: isSearchingTranscripts,
                        retryLoadReactionsAction: retryLoadReactionsAction
                    )
                }
            } else {
                gridContent()
            }
        }
        .onChange(of: isSearching) {
            isInSearchMode = shouldShowSearchUI
        }
        .onAppear {
            isInSearchMode = shouldShowSearchUI
        }
    }
}
