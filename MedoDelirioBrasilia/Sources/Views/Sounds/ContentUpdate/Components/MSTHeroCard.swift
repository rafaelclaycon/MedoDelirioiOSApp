//
//  MSTHeroCard.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 21/10/26.
//

import SwiftUI

/// The content update system goes by M.S.T., Medo Sync Technology, a play on the
/// Movimento dos Trabalhadores Rurais Sem Terra. Its look borrows from the movement's
/// flag: a red field, a white circle and a strip of green.
struct MSTHeroCard: View {

    enum Status {
        case updating, done, error
    }

    let status: Status
    let title: String
    let subtitle: String
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.xLarge)) {
            MSTWordmark()

            HStack(alignment: .top, spacing: .spacing(.medium)) {
                StatusCircle(status: status)

                VStack(alignment: .leading, spacing: .spacing(.xxSmall)) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .opacity(0.85)

                    if let footnote {
                        Text(footnote)
                            .font(.footnote)
                            .opacity(0.7)
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            MSTMotto()
        }
        .mstBanner(isSpinning: status == .updating)
        .animation(.smooth, value: status)
    }
}

extension View {

    /// Sets the content in white on the M.S.T. red field, as a full-width card.
    func mstBanner(isSpinning: Bool = false) -> some View {
        self
            .foregroundStyle(.white)
            .padding(.spacing(.xLarge))
            .padding(.bottom, .spacing(.xSmall))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                MSTBackground(isSpinning: isSpinning)
            }
            .clipShape(.rect(cornerRadius: .spacing(.xLarge)))
    }
}

// MARK: - Pieces

/// "M.S.T." in heavy condensed type, the way it'd be painted on a banner.
struct MSTWordmark: View {

    @ScaledMetric private var size: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Text("M.S.T.")
                .font(.system(size: size, weight: .black).width(.compressed))

            Text("MEDO SYNC TECHNOLOGY")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .opacity(0.85)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("M.S.T., Medo Sync Technology")
        .accessibilityAddTraits(.isHeader)
    }
}

/// A riff on the movement's "Ocupar, resistir, produzir".
struct MSTMotto: View {

    var body: some View {
        Text("Baixar, resistir, reproduzir.")
            .font(.footnote.weight(.semibold))
            .italic()
            .opacity(0.75)
    }
}

/// The red field with a giant sync symbol in the corner and the green strip at the bottom.
/// The symbol turns while an update is under way.
struct MSTBackground: View {

    var isSpinning: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LinearGradient(
            colors: [.mstRed, .mstDeepRed],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 220, weight: .bold))
                .foregroundStyle(.white.opacity(0.1))
                .symbolEffect(.rotate, options: .repeat(.continuous), isActive: isSpinning && !reduceMotion)
                .offset(x: 70, y: 60)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.mstGreen)
                .frame(height: .spacing(.xSmall))
        }
        .accessibilityHidden(true)
    }
}

private struct StatusCircle: View {

    let status: MSTHeroCard.Status

    @ScaledMetric private var diameter: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)

            switch status {
            case .updating:
                ProgressView()
                    .tint(.mstRed)

            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.45, weight: .heavy))
                    .foregroundStyle(Color.darkerGreen)

            case .error:
                Image(systemName: "exclamationmark")
                    .font(.system(size: diameter * 0.5, weight: .heavy))
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: diameter, height: diameter)
        .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - Previews

#Preview("Done") {
    MSTHeroCard(
        status: .done,
        title: "Conteúdos atualizados",
        subtitle: "Última atualização há 2 minutos.",
        footnote: "Nenhuma ação é necessária."
    )
    .padding()
}

#Preview("Updating") {
    MSTHeroCard(
        status: .updating,
        title: "Sincronizando conteúdos",
        subtitle: "Aguarde a atualização ser concluída."
    )
    .padding()
}

#Preview("Error") {
    MSTHeroCard(
        status: .error,
        title: "Última atualização com sucesso há 3 dias",
        subtitle: "Houve um problema na última tentativa de atualização. Verifique a sua conexão à Internet."
    )
    .padding()
}
