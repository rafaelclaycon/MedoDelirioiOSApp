//
//  YouCardLabel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// A tappable card in Você that leads somewhere: symbol, title, a line of detail and a
/// chevron. Used as a `NavigationLink` label.
struct YouCardLabel: View {

    let systemImage: String
    var symbolColor: Color = .accentColor
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: .spacing(.medium)) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(symbolColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.spacing(.medium))
        .background(
            RoundedRectangle(cornerRadius: .spacing(.medium), style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    YouCardLabel(
        systemImage: "chart.line.uptrend.xyaxis",
        title: "Suas Tendências",
        detail: "Suas vírgulas mais compartilhadas e seus números nos episódios."
    )
    .padding()
}
