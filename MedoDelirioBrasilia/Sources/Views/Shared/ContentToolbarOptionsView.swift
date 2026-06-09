//
//  ContentToolbarOptionsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 18/04/25.
//

import SwiftUI

struct ContentToolbarOptionsView: ToolbarContent {

    @Binding var contentSortOption: Int
    let contentListMode: ContentGridMode
    let multiSelectAction: () -> Void
    var playRandomSoundAction: (() -> Void)? = nil
    let contentSortChangeAction: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section {
                    Button {
                        multiSelectAction()
                    } label: {
                        Label(
                            contentListMode == .selection ? "Cancelar Seleção" : "Selecionar",
                            systemImage: contentListMode == .selection ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                }

                if let playRandomSoundAction {
                    Section {
                        Button {
                            playRandomSoundAction()
                        } label: {
                            Label("Tocar Som Aleatório", systemImage: "shuffle")
                        }
                    }
                }

                Section {
                    Picker("Ordenação de Sons", selection: $contentSortOption) {
                        Text("Mais Recentes no Topo")
                            .tag(2)

                        Text("Mais Curtos no Topo")
                            .tag(3)

                        Text("Título")
                            .tag(0)

                        Text("Nome do Autor ou Gênero Musical")
                            .tag(1)

                        Text("Mais Longos no Topo")
                            .tag(4)

                        if CommandLine.arguments.contains("-SHOW_MORE_DEV_OPTIONS") {
                            Text("Título Mais Longo no Topo")
                                .tag(5)

                            Text("Título Mais Curto no Topo")
                                .tag(6)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .onChange(of: contentSortOption) {
                contentSortChangeAction()
            }
//            .disabled(
//                viewModel.currentViewMode == .favorites //&& viewModel.favorites?.count == 0 // TODO: Do we need to adapt this?
//            )
        }
    }
}

#Preview {
    VStack {
        Text("View")
    }
    .toolbar {
        ContentToolbarOptionsView(
            contentSortOption: .constant(0),
            contentListMode: .regular,
            multiSelectAction: {},
            contentSortChangeAction: {}
        )
    }
}
