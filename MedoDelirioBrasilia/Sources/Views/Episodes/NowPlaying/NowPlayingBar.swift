//
//  NowPlayingBar.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 06/12/24.
//

import SwiftUI

struct NowPlayingBar<Content: View>: View {

    var content: Content
    let currentState: PlayerState<Episode>
    let playButtonAction: () -> Void

    let showBar: Bool = true
    @State private var showNowPlayingScreen: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            if showBar {
                VStack {
                    switch currentState {
                    case .stopped:
                        HStack {
                            Spacer()

                            Button(action: {}) {
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                            }

                            Spacer()
                        }

                    case .downloading:
                        HStack {
                            Spacer()

                            ProgressView()

                            Text("Baixando episódio...")
                                .foregroundStyle(.gray)

                            Spacer()
                        }

                    case .playing(let episode):
                        HStack {
                            Spacer()

                            Button(action: {}) {
                                Image(systemName: "pause.circle.fill")
                                    .font(.largeTitle)
                            }

                            Spacer()
                        }

                    case .paused:
                        HStack {
                            Spacer()

                            Button(action: {}) {
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                            }

                            Spacer()
                        }

                    case .error(let errorMessage):
                        HStack {
                            Spacer()

                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)

                            Text("Erro reproduzindo o episódio: \(errorMessage)")
                                .foregroundStyle(.gray)

                            Spacer()
                        }
                    }
                }
                .frame(height: 65)
                .background {
                    Rectangle()
                        .fill(.background)
                        .shadow(radius: 3, x: 0, y: -0.5)
                }
                .onTapGesture {
                    playButtonAction()
                }
                //.fullScreenCover(isPresented: $showNowPlayingScreen, content: NowPlayingView.init)
            }
        }
    }
}

//#Preview {
//    NowPlayingBar()
//}
