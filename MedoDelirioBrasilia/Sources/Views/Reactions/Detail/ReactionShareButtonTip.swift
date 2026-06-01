//
//  ReactionShareButtonTip.swift
//  MedoDelirioBrasilia
//

import SwiftUI
import TipKit

struct ReactionShareButtonTip: Tip {

    var title: Text {
        Text("Novidade")
    }

    var message: Text? {
        Text("Conhece alguém que vai amar essa Reação? Compartilha o link.")
    }

    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }
}

struct PrimaryImageTipViewStyle: TipViewStyle {

    var tip: any Tip

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let image = configuration.image {
                image
                    .foregroundStyle(.primary)
                    .font(.title2)
            }
            VStack(alignment: .leading, spacing: 4) {
                configuration.title
                    .font(.headline)
                if let message = configuration.message {
                    message
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                tip.invalidate(reason: .actionPerformed)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}
