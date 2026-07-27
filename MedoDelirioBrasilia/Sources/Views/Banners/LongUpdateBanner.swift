//
//  LongUpdateBanner.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 10/12/23.
//

import SwiftUI

struct LongUpdateBanner: View {

    let completedNumber: Int
    let totalUpdateCount: Int
    let estimatedSecondsRemaining: TimeInterval?
    let continuesInBackground: Bool

    @Environment(\.colorScheme) private var colorScheme

    /// Leaving mid-update never loses work — unfinished items are retried — so the version
    /// for systems without background continuation nudges instead of forbidding.
    private var instructionText: LocalizedStringKey {
        if continuesInBackground {
            return "Novidades estão sendo baixadas. Você pode **sair do app**, a atualização continua."
        } else {
            return "Novidades estão sendo baixadas. Deixe o **app aberto** para terminar mais rápido."
        }
    }

    private var percentageText: String {
        guard
            completedNumber > 0,
            totalUpdateCount > 0,
            completedNumber <= totalUpdateCount
        else { return "" }
        let percentage: Int = Int((Double(completedNumber) / Double(totalUpdateCount)) * 100)
        return "\(percentage)%"
    }

    private var timeRemainingText: String? {
        guard let remaining = estimatedSecondsRemaining, remaining > 0 else { return nil }

        if remaining < 60 {
            return "Menos de 1 minuto restante"
        } else {
            let minutes = Int(ceil(remaining / 60))
            if minutes == 1 {
                return "Aproximadamente 1 minuto restante"
            } else {
                return "Aproximadamente \(minutes) minutos restantes"
            }
        }
    }

    // MARK: - View Body

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "icloud.and.arrow.down")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .frame(width: .spacing(.huge))
                .foregroundColor(.green)
                .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 3.0)))

            VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                Text("Atualização Longa Em Andamento")
                    .bold()
                    .multilineTextAlignment(.leading)

                Text(instructionText)
                    .opacity(0.8)
                    .font(.callout)

                ProgressView(
                    percentageText,
                    value: Double(completedNumber),
                    total: Double(totalUpdateCount)
                )
                .padding(.top, .spacing(.xSmall))
                .padding(.bottom, .spacing(.xSmall))

                if let timeText = timeRemainingText {
                    Text(timeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: .spacing(.medium))
                .foregroundColor(.gray)
                .opacity(colorScheme == .dark ? 0.3 : 0.15)
        }
    }
}

// MARK: - Preview

#Preview("Continues In Background") {
    LongUpdateBanner(
        completedNumber: 3,
        totalUpdateCount: 12,
        estimatedSecondsRemaining: 90,
        continuesInBackground: true
    )
    .padding()
}

#Preview("Needs App Open") {
    LongUpdateBanner(
        completedNumber: 3,
        totalUpdateCount: 12,
        estimatedSecondsRemaining: 90,
        continuesInBackground: false
    )
    .padding()
}

#Preview("Partial - No Time Yet") {
    LongUpdateBanner(
        completedNumber: 0,
        totalUpdateCount: 10,
        estimatedSecondsRemaining: nil,
        continuesInBackground: true
    )
    .padding()
}

#Preview("Almost Done") {
    LongUpdateBanner(
        completedNumber: 9,
        totalUpdateCount: 10,
        estimatedSecondsRemaining: 15,
        continuesInBackground: false
    )
    .padding()
}
