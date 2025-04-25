//
//  EpisodesView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/10/22.
//

import SwiftUI

struct EpisodesView: View {

    let viewModel: ViewModel

    @Environment(\.push) var push

    var body: some View {
        GeometryReader { geometry in
            switch viewModel.state {
            case .loading:
                LoadingView(
                    width: geometry.size.width,
                    height: geometry.size.height
                )

            case .loaded(let episodes):
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(episodes) { episode in
                            EpisodeItem(
                                episode: episode,
                                playAction: { episode in
                                    Task {
                                        await viewModel.onPlayEpisodeSelected(episode: episode)
                                    }
                                }
                            )
                            .onTapGesture {
                                push(GeneralNavigationDestination.episodeDetail(episode))
                            }
                        }
                    }
                    .navigationTitle("Episódios")
                    .padding()
                }

            case .error(let errorMessage):
                VStack {
                    Text("Erro: \(errorMessage)")
                }
            }
        }
        .oneTimeTask {
            await viewModel.onViewLoaded()
        }
    }
}

// MARK: - Subviews

extension EpisodesView {

    struct LoadingView: View {

        let width: CGFloat
        let height: CGFloat

        var body: some View {
            VStack(spacing: 50) {
                ProgressView()
                    .scaleEffect(2.0)

                Text("Carregando Episódios...")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.gray)
            }
            .frame(width: width)
            .frame(minHeight: height)
        }
    }

    struct NotAPlayerBanner: View {

        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            VStack(alignment: .center, spacing: 8) {
                Text("Medo e Delírio não é um tocador de podcasts")
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Acesse o episódio no seu tocador favorito. Marque episódios favoritos para mais tarde. Confira quais sons aparecem em quais episódio. Recebe uma notificação quando um novo episódio sair.")
                    //.foregroundColor(.blue)
                    .opacity(0.8)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
            .padding(.all, 20)
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .foregroundColor(.gray)
                    .opacity(colorScheme == .dark ? 0.3 : 0.15)
            }
        }
    }
}

// MARK: - Preview

//#Preview {
//    EpisodesView()
//}
