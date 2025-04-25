//
//  SoundListRouter.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 20/07/24.
//

import SwiftUI

enum GeneralNavigationDestination: Hashable {

    case authorDetail(Author)
    case reactionDetail(Reaction)
    case episodeDetail(Episode)
}

struct GeneralRouter: View {

    let destination: GeneralNavigationDestination

    @State private var currentSoundListMode: SoundsListMode = .regular

    var body: some View {
        switch destination {
        case .authorDetail(let author):
            AuthorDetailView(
                author: author,
                currentSoundsListMode: $currentSoundListMode
            )
        case .reactionDetail(let reaction):
            ReactionDetailView(
                reaction: reaction,
                currentSoundsListMode: $currentSoundListMode
            )
        case .episodeDetail(let episode):
            EpisodeDetailView(episode: episode)
        }
    }
}
