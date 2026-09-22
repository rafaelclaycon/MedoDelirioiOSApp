//
//  AIUsageDetailsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 22/09/26.
//

import SwiftUI

/// Half sheet explaining how AI is used to produce chapters and transcripts,
/// reachable from the chapters "..." menu.
struct AIUsageDetailsView: View {

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing(.medium)) {
                    Text("As transcrições dos episódios são geradas com o Whisper.cpp, uma implementação de código aberto dos modelos Whisper da OpenAI. O processamento roda localmente em uma máquina nossa. Nenhum áudio é enviado à OpenAI ou a terceiros.")

                    Text("Os capítulos são gerados a partir dessas transcrições usando a API da Anthropic (Claude). Apenas o texto já transcrito do episódio é enviado para esse fim.")

                    Text("Em ambos os casos, o conteúdo processado é sempre o dos episódios oficiais do podcast. Nenhum dado pessoal seu ou conteúdo criado por você é utilizado.")

                    Text("Não quer usar esses recursos? Você pode desativar os capítulos em Ajustes > Episódios, ou simplesmente não baixar as transcrições.")

                    GlassButton(
                        symbol: "doc.text",
                        title: "Ler a política de privacidade",
                        color: .accentColor,
                        fullWidth: true
                    ) {
                        OpenUtility.open(link: "https://site.medodelirioios.com/#politica-de-privacidade")
                    }
                    .padding(.top, .spacing(.small))
                }
                .font(.callout)
                .padding(.horizontal, .spacing(.large))
                .padding(.top, .spacing(.medium))
            }
            .navigationTitle("Uso de IA no App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    Text("Now Playing")
        .sheet(isPresented: .constant(true)) {
            AIUsageDetailsView()
        }
}
