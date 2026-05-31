//
//  HowReactionsWorkView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 10/11/24.
//

import SwiftUI

struct HowReactionsWorkView: View {

    @Environment(\.dismiss) var dismiss

    private var showNovidadeBadge: Bool {
        let expiry = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        return Date.now < expiry
    }

    private var exampleReaction: Reaction {
        var choque = Reaction.choqueMock
        choque.type = .pinnedExisting
        return choque
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing(.xxLarge)) {
                    HStack {
                        Spacer()
                        Text("Reações?")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.clear)
                            .overlay(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .mask(
                                    Text("Reações")
                                        .font(.largeTitle)
                                        .bold()
                                )
                            )
                        Spacer()
                    }

                    Text("O que são?")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)

                    Text("As Reações são um jeito diferente de descubrir as vírgulas sonoras.\n\nDesde o começo do app, a quantidade de sons e músicas disponíveis aumentou consideravelmente. Com o aumento da quantidade, muitos conteúdos acabam escondidos. As reações facilitam a descoberta: escolha uma categoria e responda rápido com a vírgula perfeita.")
                        .multilineTextAlignment(.leading)

                    Text("Como adicionar?")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)

                    Text("Esse é um recurso colaborativo e online, as categorias são as mesmas para todos os usuários.\n\nPensou numa categoria nova diferente? Acha que uma vírgula não está na categoria certa ou que faltam vírgulas? Envie um e-mail.")
                        .multilineTextAlignment(.leading)

                    GlassButton(title: "Entrar em contato", color: .accentColor, fullWidth: true) {
                        Task {
                            await Mailman.openDefaultEmailApp(
                                subject: Shared.Email.Reactions.suggestChangesSubject,
                                body: Shared.Email.Reactions.suggestChangesBody
                            )
                        }
                    }

                    Text("Fixe as suas favoritas")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.primary)

                    HStack {
                        Spacer()
                        ReactionItem(reaction: exampleReaction)
                            .frame(width: 180)
                        Spacer()
                    }

                    Text("Segure nas reações que você usa bastante e escolha **Fixar no Topo** para acessá-las facilmente.")
                        .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: .spacing(.xxSmall)) {
                        if showNovidadeBadge {
                            Text("NOVIDADE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.blue)
                                .clipShape(Capsule())
                        }

                        Text("Compartilhe com os amigos")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Spacer()
                        WhatsAppLinkBubble(
                            reaction: .classicsMock,
                            subtitle: "20 sons nesta reação",
                            time: "09:41"
                        )
                        Spacer()
                    }

                    (
                        Text("Toque em ") +
                        Text(Image(systemName: "square.and.arrow.up")) +
                        Text(" em uma reação para compartilhar um link que vai levar os seus amigos àquela tela específica do app Medo e Delírio iOS.\n\nAo invés de prints ou as vírgulas por si só, deixe seu amigo explorar a reação no seu próprio tempo.\n\nDisponível apenas nas plataformas Apple.")
                    )
                    .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, .spacing(.xxLarge))
                .padding(.bottom, .spacing(.medium))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HowReactionsWorkView()
}
