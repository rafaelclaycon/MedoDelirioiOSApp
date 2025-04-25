//
//  EpisodeDetailView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/24.
//

import SwiftUI

struct EpisodeDetailView: View {

    let episode: Episode

    var body: some View {
        ScrollView {
            VStack {
                HeaderView(title: episode.title)

                Description(description: episode.description ?? "")
            }
            .padding()
        }
    }
}

// MARK: - Subviews

extension EpisodeDetailView {

    struct HeaderView: View {

        let title: String

        var body: some View {
            HStack {
                Text(title)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.leading)

                Spacer()
            }
        }
    }

    struct Description: View {

        let description: String

        var body: some View {
            VStack {
                Text(description)
                    .multilineTextAlignment(.leading)
                    .padding()
            }
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.gray)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EpisodeDetailView(episode: .mock)
}
