//
//  NoSearchResultsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/02/23.
//

import SwiftUI

struct NoSearchResultsView: View {

    let searchText: String
    var showSuggestionButton: Bool = true

    @State private var showSuggestionAlert: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Spacer()

            VStack(alignment: .center, spacing: .spacing(.medium)) {
                Spacer(minLength: .spacing(.xxxLarge))

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)

                Text("Nenhum Resultado para \"\(searchText)\"")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Verifique a ortografia ou tente uma nova busca.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if showSuggestionButton {
                    suggestionButton
                        .padding(.top, .spacing(.large))
                }

                Spacer(minLength: .spacing(.xxxLarge))
            }

            Spacer()
        }
        .alert(
            "Sugerir Conteúdo",
            isPresented: $showSuggestionAlert
        ) {
            Button("Cancelar", role: .cancel) { }
            Button("Continuar") {
                Task {
                    await Mailman.openDefaultEmailApp(
                        subject: "Sugestão de Conteúdo para o App v\(Versioneer.appVersion)",
                        body: "Olá! Eu estava procurando por \"\(searchText)\" e não encontrei. Gostaria de sugerir:\n\n"
                    )
                }
            }
        } message: {
            Text("Você será redirecionado para o app de e-mail para enviar sua sugestão.")
        }
    }

    @ViewBuilder
    private var suggestionButton: some View {
        if #available(iOS 26, *) {
            HStack(spacing: .spacing(.small)) {
                Image(systemName: "lightbulb")
                Text("Não encontrou? Sugira uma adição")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(colorScheme == .dark ? .primary : Color.darkestGreen)
            .padding(.vertical, .spacing(.small))
            .padding(.horizontal, .spacing(.medium))
            .glassEffect(
                .regular.tint(
                    .accentColor.opacity(0.3)
                ).interactive()
            )
            .contentShape(Rectangle())
            .onTapGesture {
                showSuggestionAlert = true
            }
        } else {
            Button {
                showSuggestionAlert = true
            } label: {
                HStack(spacing: .spacing(.small)) {
                    Image(systemName: "lightbulb")
                    Text("Não encontrou? Sugira uma adição")
                }
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
    }
}

#Preview {
    NoSearchResultsView(searchText: "Testeeee")
}
