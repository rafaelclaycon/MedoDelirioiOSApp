//
//  EpisodeItem.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/10/22.
//

import SwiftUI

struct EpisodeItem: View {

    let episode: Episode
    let playAction: (Episode) -> Void

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text(episode.pubDate?.asLongString().uppercased() ?? "")
                        .font(.footnote)
                        .foregroundStyle(.gray)

                    Text(episode.title)
                        .bold()

                    Text(episode.duration.toDisplayString())
                        .font(.footnote)
                        .foregroundStyle(.gray)
                }
                .padding(.leading, 10)
                
                Spacer()
            }
            
            HStack(spacing: 30) {
                Spacer()

                Button {
                    //Opener.open(link: episode.applePodcastsLink)
                } label: {
                    Image(systemName: "list.triangle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24)
                }
                .foregroundStyle(.primary)

                Button {
                    playAction(episode)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36)
                }
                .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: Preview

#Preview {
    EpisodeItem(
        episode: Episode(
            episodeId: "123",
            title: "Dias 1.390, 1.391 e 1.392 | Bob e Jeff em Comendador Levy Gasparian | Dias 21, 22 e 23/10/22",
            description: "Bob Jeff in the sky with grenades.",
            pubDate: .now,
            duration: 300,
            creationDate: .now
        ),
        playAction: { _ in }
    )
}
