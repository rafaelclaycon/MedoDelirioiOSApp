//
//  AuthorsGrid.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/05/22.
//

import SwiftUI

struct AuthorsGrid: View {

    @State private var viewModel: ViewModel

    private let containerWidth: CGFloat

    // Dynamic Type
    @ScaledMetric private var authorCountTopPadding = 10
    @ScaledMetric private var authorCountPadBottomPadding = 22

    // MARK: - Environment

    @Environment(\.push) var push
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // MARK: - Initializer

    init(
        viewModel: AuthorsGrid.ViewModel,
        containerWidth: CGFloat
    ) {
        self.viewModel = viewModel
        self.containerWidth = containerWidth
    }

    // MARK: - View Body

    var body: some View {
        VStack {
            switch viewModel.state {
            case .loading:
                BasicLoadingView(text: "Carregando Autores...")

            case .loaded(let authors):
                VStack {
                    LazyVGrid(columns: viewModel.columns, spacing: .spacing(.large)) {
                        ForEach(authors) { author in
                            HorizontalAuthorView(author: author)
                                .onTapGesture {
                                    push(GeneralNavigationDestination.authorDetail(author))
                                }
                        }
                    }
                    .padding(.top, .spacing(.xxSmall))
                    .onChange(of: containerWidth) {
                        viewModel.onContainerWidthChanged(newWidth: containerWidth, horizontalSizeClass: hSizeClass)
                    }
                    .onChange(of: viewModel.sortOption) {
                        viewModel.onAuthorSortingChanged()
                    }

                    Text("\(authors.count) AUTORES")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, authorCountTopPadding)
                        .padding(.bottom, authorCountPadBottomPadding)
                }

            case .error(let errorMessage):
                VStack {
                    Text("Erro ao carregar os Autores. Informe o desenvolvedor.\n\nDetalhes: \(errorMessage)")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            viewModel.onViewAppeared(viewWidth: containerWidth, horizontalSizeClass: hSizeClass)
        }
    }
}

// MARK: - Preview

#Preview {
    AuthorsGrid(
        viewModel: AuthorsGrid.ViewModel(
            authorService: FakeAuthorService(),
            userSettings: UserSettings(),
            sortOption: AuthorSortOption.nameAscending.rawValue
        ),
        containerWidth: 390
    )
}
