//
//  ContentGridDisplaying.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 16/04/24.
//

import SwiftUI

/// This protocol exists to enable the communication between ContextMenuOption and ContentGrid.
@MainActor
protocol ContentGridDisplaying {

    func share(content: AnyEquatableMedoContent)

    func openShareAsVideoModal(for content: AnyEquatableMedoContent)

    func toggleFavorite(_ contentId: String, isFavoritesOnlyView: Bool)

    func addToFolder(_ content: AnyEquatableMedoContent)

    func playFrom(content: AnyEquatableMedoContent, loadedContent: [AnyEquatableMedoContent])

    func removeFromFolder(_ content: AnyEquatableMedoContent)

    func showDetails(for content: AnyEquatableMedoContent)

    func showAuthor(withId authorId: String)

    func suggestOtherAuthorName(for content: AnyEquatableMedoContent) async
}
