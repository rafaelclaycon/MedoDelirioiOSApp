//
//  LargeCreatorView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/06/22.
//

import SwiftUI

extension HelpTheAppView {

    static let pixKey: String = "contato@medodelirioios.com"
}

struct HelpTheAppView: View {

    let donors: [Donor]?
    @Binding var toast: Toast?
    let apiClient: APIClientProtocol

    @State private var moneyInfo: [MoneyInfo]?
    @State private var showDonorInfoView: Bool = false

    var body: some View {
        Section("Ajude o app") {
            VStack(alignment: .center, spacing: .spacing(.large)) {
                VStack(alignment: .leading, spacing: .spacing(.xLarge)) {
                    VStack(alignment: .leading, spacing: .spacing(.medium)) {
                        HStack {
                            Spacer()
                            Text("Se isso aqui tá de pé é por causa de gente como *você*")
                                .font(.title2)
                                .bold()
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding(.vertical, .spacing(.small))

                        if let donors {
                            let apoiaseDonors = donors.filter { $0.isSpecial }
                            let pixDonors = donors.filter { !$0.isSpecial }

                            VStack(alignment: .center, spacing: .spacing(.large)) {
                                DonorsView(donors: apoiaseDonors)
                                    .marquee(speedBasis: .velocity(35))

                                DonorsView(donors: pixDonors)
                                    .marquee(speedBasis: .velocity(40))

                                Button {
                                    showDonorInfoView.toggle()
                                } label: {
                                    HStack(spacing: .spacing(.small)) {
                                        Text("ÚLTIMAS DOAÇÕES")
                                            .font(.footnote)

                                        Image(systemName: "info.circle")
                                    }
                                    .foregroundStyle(.gray)
                                }
                            }
                        }

                        Text("Esse projeto é mantido através de doações dos usuários. Essas doações cobrem os custos de operação (mensalidades de servidor, anuidade da Apple) e me incentivam a seguir melhorando o app todos os anos. Gosto muito da nossa parceria, bora manter ela?")
                            .padding(.top, .spacing(.xxxSmall))
                    }

                    if let moneyInfo {
                        MoneyInfoView(info: moneyInfo)
                            .padding(.top, -4)
                    }

                    DonateButtons(toast: $toast)
                }
            }
            .padding(.bottom, .spacing(.xxSmall))
        }
        .task {
            await loadMoneyInfo()
        }
        .sheet(isPresented: $showDonorInfoView) {
            NavigationStack {
                DonorTypeInfoView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            CloseButton {
                                showDonorInfoView.toggle()
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func loadMoneyInfo() async {
        guard moneyInfo == nil else { return }
        do {
            moneyInfo = try await apiClient.moneyInfo()
        } catch {
            debugPrint(error)
        }
    }
}

// MARK: - Subviews

extension HelpTheAppView {

    struct MoneyInfoView: View {

        let info: [MoneyInfo]

        var body: some View {
            VStack(alignment: .leading, spacing: .spacing(.xLarge)) {
                ForEach(info, id: \.title) { info in
                    ProgressView(value: info.currentValue, total: info.totalValue) {
                        Text(info.title)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.gray)
                    } currentValueLabel: {
                        Text(info.subtitle)
                    }
                    .tint(info.barColor)
                }
            }
        }
    }

    struct DonateButtons: View {

        @Binding var toast: Toast?
        var showSectionDivider: Bool = false
        var showHeader: Bool = true
        @State private var pixAlertAmount: Int?

        // MARK: - Tier Data

        struct Tier: Identifiable {
            let emoji: String
            let amount: Int
            let isPopular: Bool
            var id: Int { amount }
        }

        static let monthlyTiers: [Tier] = [
            Tier(emoji: "☕", amount: 5, isPopular: false),
            Tier(emoji: "🍕", amount: 10, isPopular: true),
            Tier(emoji: "🍖", amount: 20, isPopular: false),
        ]

        static let pixTiers: [Tier] = [
            Tier(emoji: "☕", amount: 5, isPopular: false),
            Tier(emoji: "🍕", amount: 10, isPopular: false),
            Tier(emoji: "🍖", amount: 20, isPopular: false),
            Tier(emoji: "🎉", amount: 50, isPopular: false),
        ]

        // MARK: - Body

        var body: some View {
            VStack(alignment: .center, spacing: .spacing(.xLarge)) {
                if showHeader {
                    Text("🚀 Junte-se aos apoiadores do app")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: .spacing(.medium)) {
                    Text("Apoio Mensal (Apoia.se)")
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack(spacing: .spacing(.small)) {
                        ForEach(Self.monthlyTiers) { tier in
                            TierCard(tier: tier, showPeriod: true) {
                                Task { await apoiaseAction(amount: tier.amount) }
                            }
                        }
                    }
                }

                if showSectionDivider {
                    Divider()
                }

                VStack(alignment: .leading, spacing: .spacing(.medium)) {
                    Text("Doação Única (Pix)")
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack(spacing: .spacing(.small)) {
                        ForEach(Self.pixTiers) { tier in
                            TierCard(tier: tier, showPeriod: false) {
                                Task { await pixAction(amount: tier.amount) }
                            }
                        }
                    }

                    Text("Toque para copiar chave Pix")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, .spacing(.xxxSmall))
                }
            }
            .alert(
                "Pix de R$ \(pixAlertAmount ?? 0) Copiado! ✓",
                isPresented: Binding(
                    get: { pixAlertAmount != nil },
                    set: { if !$0 { pixAlertAmount = nil } }
                )
            ) {
                Button("OK") { pixAlertAmount = nil }
            } message: {
                Text("Cole no app do seu banco para enviar R$ \(pixAlertAmount ?? 0).\n\nObrigado! 💚")
            }
        }

        // MARK: - Actions

        private func apoiaseAction(amount: Int) async {
            OpenUtility.open(link: "https://apoia.se/app-medo-delirio-ios")
            await Self.sendAnalytics(for: "didTapApoiase_R$\(amount)")
        }

        private func pixAction(amount: Int) async {
            UIPasteboard.general.string = pixKey
            pixAlertAmount = amount
            await Self.sendAnalytics(for: "didTapPix_R$\(amount)")
        }

        private static func sendAnalytics(for action: String) async {
            await AnalyticsService().send(
                originatingScreen: "SettingsView",
                action: action
            )
        }

        // MARK: - Tier Card

        struct TierCard: View {

            let tier: Tier
            let showPeriod: Bool
            let action: () -> Void

            var body: some View {
                Button(action: action) {
                    VStack(spacing: .spacing(.xxxSmall)) {
                        Text(tier.emoji)
                            .font(.title)

                        Text("R$ \(tier.amount)")
                            .font(.subheadline)
                            .fontWeight(.bold)

                        if showPeriod {
                            Text("/mês")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.spacing(.small))
                    .background(
                        Color.gray.opacity(0.2),
                        in: RoundedRectangle(cornerRadius: .spacing(.small))
                    )
                    .overlay(alignment: .top) {
                        if tier.isPopular {
                            Text("POPULAR")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, .spacing(.xxSmall))
                                .padding(.vertical, .spacing(.nano))
                                .background(Color.green, in: RoundedRectangle(cornerRadius: .spacing(.xxxSmall)))
                                .offset(y: -.spacing(.xSmall))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    showPeriod
                        ? "Apoiar R$ \(tier.amount) por mês"
                        : "Doar R$ \(tier.amount) via Pix"
                )
            }
        }
    }

    struct DonorTypeInfoView: View {

        @ViewBuilder
        private func row(donor: Donor, text: String) -> some View {
            VStack(alignment: .center, spacing: .spacing(.medium)) {
                DonorView(donor: donor)

                Text(text)
                    .multilineTextAlignment(.center)
            }
        }

        @Environment(\.dismiss) var dismiss

        var body: some View {
            ScrollView {
                VStack(alignment: .center, spacing: .spacing(.large)) {
                    row(
                        donor: Donor(name: "Cristiano B."),
                        text: "Usuário fez uma doação única via Pix."
                    )

                    Divider()

                    row(
                        donor: Donor(name: "Pedro D.", hasDonatedBefore: true),
                        text: "O mesmo usuário fez uma nova doação única via Pix, independente do valor."
                    )

                    Divider()

                    row(
                        donor: Donor(name: "Jair B.", isRecurringDonorBelow30: true),
                        text: "Usuário doa até R$ 29 todos os meses pelo Apoia.se."
                    )

                    Divider()

                    row(
                        donor: Donor(name: "Alexandre M.", isRecurringDonor30OrOver: true),
                        text: "Usuário doa R$ 30 ou mais todos os meses pelo Apoia.se."
                    )
                }
                .padding(.horizontal, .spacing(.large))
                .padding(.vertical, .spacing(.small))
            }
            .navigationTitle("Tipos de Doação")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        HelpTheAppView(
            donors: [
                Donor(name: "Bruno P. G. P."),
                Donor(name: "Clarissa P. S.", hasDonatedBefore: true),
                Donor(name: "Pedro Henrique B. P.")
            ],
            toast: .constant(nil),
            apiClient: APIClient(serverPath: "")
        )
    }
}

#Preview("Donate Buttons") {
    HelpTheAppView.DonateButtons(toast: .constant(nil))
        .padding()
}
