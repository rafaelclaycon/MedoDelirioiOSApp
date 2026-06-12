//
//  TipView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 04/07/22.
//

import SwiftUI

struct TipView: View {

    let text: String
    @Binding var didTapClose: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: .spacing(.small)) {
            VStack {
                Text("☝️")
                    .font(.system(size: 30))

                Spacer()
            }

            VStack(alignment: .leading, spacing: .spacing(.small)) {
                Text("DICA")
                    .font(.callout)
                    .bold()

                Text(text)
                    .font(.callout)
                    .opacity(0.75)
            }

            Spacer()
        }
        .padding(.leading, .spacing(.small))
        .padding(.vertical, .spacing(.medium))
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray)
                .opacity(colorScheme == .dark ? 0.3 : 0.1)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                didTapClose.toggle()
            } label: {
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15)
                    .foregroundColor(colorScheme == .dark ? .primary : .gray)
            }
            .padding([.top,.trailing], .spacing(.medium))
        }
    }
}

// MARK: - Preview

#Preview {
    TipView(
        text: "Para responder a uma publicação na sua rede social favorita, escolha Salvar Vídeo e depois adicione o vídeo à resposta a partir do app da rede.",
        didTapClose: .constant(false)
    )
}
