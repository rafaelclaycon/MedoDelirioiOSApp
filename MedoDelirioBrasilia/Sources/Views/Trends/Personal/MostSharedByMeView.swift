//
//  MostSharedByMeView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 11/10/22.
//

import SwiftUI

struct MostSharedByMeView: View {

    @State private var viewModel = MostSharedByMeViewViewModel()

    let columns = [
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: .spacing(.large)) {
            HStack {
                Text("Vírgulas Mais Compartilhadas")
                    .font(.title2)
                Spacer()
            }
            .padding(.horizontal)

            switch viewModel.viewState {
            case .loading:
                LoadingView()

            case .loaded(let items):
                if items.isEmpty {
                    NoDataView()
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(items) { item in
                            TopChartRow(item: item)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)
                }
            case .error(let errorMessage):
                Text(errorMessage)
            }
        }
        .onAppear {
            Task {
                await viewModel.onViewAppeared()
            }
        }
    }
}

extension MostSharedByMeView {

    struct LoadingView: View {

        var body: some View {
            HStack {
                Spacer()

                ProgressView()
                    .padding(.vertical, .spacing(.xxxLarge))

                Spacer()
            }
        }
    }

    struct NoDataView: View {

        var body: some View {
            VStack(spacing: .spacing(.large)) {
                Spacer()

                Text("☹️")
                    .font(.system(size: 64))

                Text("Nenhum Dado")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Compartilhe sons na aba Sons para ver o seu ranking pessoal.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MostSharedByMeView()
}
