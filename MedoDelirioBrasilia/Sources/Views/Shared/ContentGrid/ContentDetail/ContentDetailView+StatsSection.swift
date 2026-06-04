//
//  ContentDetailView+StatsSection.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 23/11/24.
//

import SwiftUI

extension ContentDetailView {

    struct StatsSection: View {

        let stats: ContentStatisticsState<ContentShareCountStats>
        let retryAction: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Estatísticas")
                    .font(.title3)
                    .bold()

                switch stats {
                case .loading:
                    PodiumPair.LoadingView()
                case .loaded(let stats):
                    PodiumPair.LoadedView(stats: stats)
                case .noDataYet:
                    PodiumPair.NoDataView()
                case .error(_):
                    PodiumPair.LoadingErrorView(
                        retryAction: retryAction
                    )
                }
            }
        }
    }

    struct PodiumItem: View {

        let highlight: String
        let description: String

        var body: some View {
            VStack(spacing: 5) {
                Text(highlight)
                    .font(.title)
                    .bold()

                Text(description)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    struct PodiumPair {

        struct LoadingView: View {
            var body: some View {
                VStack(spacing: 15) {
                    ProgressView()

                    Text("Carregando estatísticas de compartilhamento...")
                        .foregroundStyle(.gray)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }

        struct LoadedView: View {

            let stats: ContentShareCountStats

            var body: some View {
                VStack(spacing: .spacing(.xLarge)) {
                    HStack(spacing: 10) {
                        PodiumItem(
                            highlight: String.localizedStringWithFormat("%.0f", Double(stats.totalShareCount)),
                            description: "total de compartilhamentos"
                        )
                        .frame(minWidth: 0, maxWidth: .infinity)

                        Divider()

                        PodiumItem(
                            highlight: "\(stats.lastWeekShareCount)",
                            description: "compart. na última semana"
                        )
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }

                    if !stats.topMonth.isEmpty && !stats.topYear.isEmpty {
                        PodiumItem(
                            highlight: "\(monthDescription(stats.topMonth))/\(stats.topYear)",
                            description: "mês com mais compartilhamentos"
                        )
                    }
                }
            }

            private func monthDescription(_ input: String) -> String {
                switch input {
                case "01": return "jan"
                case "02": return "fev"
                case "03": return "mar"
                case "04": return "abr"
                case "05": return "mai"
                case "06": return "jun"
                case "07": return "jul"
                case "08": return "ago"
                case "09": return "set"
                case "10": return "out"
                case "11": return "nov"
                case "12": return "dez"
                default: return "-"
                }
            }
        }

        struct NoDataView: View {

            var body: some View {
                VStack(spacing: 15) {
                    Text("Ainda não existem estatísticas de compartilhamento para esse conteúdo.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)
                        .padding(.all, 20)
                }
                .frame(maxWidth: .infinity)
            }
        }

        struct LoadingErrorView: View {

            let retryAction: () -> Void

            var body: some View {
                VStack(spacing: 24) {
                    Text("Não foi possível carregar as estatísticas de compartilhamento.")
                        .multilineTextAlignment(.center)

                    Button {
                        retryAction()
                    } label: {
                        Label("TENTAR NOVAMENTE", systemImage: "arrow.clockwise")
                            .font(.footnote)
                    }
                    .borderedButton(colored: .blue)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
