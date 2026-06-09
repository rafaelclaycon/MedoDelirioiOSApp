//
//  MainContentView+Toolbar.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

extension MainContentView {

    struct TrailingToolbarControls: ToolbarContent {

        let currentViewMode: ContentModeOption
        let contentListMode: ContentGridMode
        @Binding var contentSortOption: Int
        @Binding var authorSortOption: Int
        let openContentUpdateSheet: () -> Void
        let multiSelectAction: () -> Void
        let playRandomSoundAction: () -> Void
        let contentSortChangeAction: () -> Void
        let authorSortChangeAction: () -> Void
        let matchedTransitionNamespace: Namespace.ID

        var body: some ToolbarContent {
            if currentViewMode != .folders {
                if currentViewMode == .authors {
                    AuthorToolbarOptionsView(
                        authorSortOption: $authorSortOption,
                        onSortingChangedAction: authorSortChangeAction
                    )
                } else {
                    if contentListMode == .regular {
                        if #available(iOS 26.0, *) {
                            ToolbarItem {
                                Button {
                                    openContentUpdateSheet()
                                } label: {
                                    ContentUpdateStatusSymbol()
                                }
                            }
                            .matchedTransitionSource(id: "sync-status-view", in: matchedTransitionNamespace)
                        } else {
                            ToolbarItem {
                                Button {
                                    openContentUpdateSheet()
                                } label: {
                                    ContentUpdateStatusSymbol()
                                }
                            }
                        }
                    }

                    ContentToolbarOptionsView(
                        contentSortOption: $contentSortOption,
                        contentListMode: contentListMode,
                        multiSelectAction: multiSelectAction,
                        playRandomSoundAction: playRandomSoundAction,
                        contentSortChangeAction: contentSortChangeAction
                    )
                }
            }
        }
    }
}
