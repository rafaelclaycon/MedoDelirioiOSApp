//
//  ContentUpdateStatusView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 18/08/23.
//

import SwiftUI

/// Displays a sheet with Content Update status and history.
struct ContentUpdateStatusView: View {

    let lastUpdateAttempt: String
    let lastUpdateDate: String

    @State private var displayKnowMore = false
    @State private var selectedDetent: PresentationDetent = .medium

    @Environment(SyncValues.self) private var syncValues
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                switch syncValues.syncStatus {
                case .updating:
                    UpdatingView()

                case .done:
                    AllOkView(
                        lastUpdateAttempt: lastUpdateAttempt,
                        displayKnowMore: $displayKnowMore,
                        selectedDetent: $selectedDetent
                    )

                case .updateError:
                    UpdateErrorView(lastUpdateDate: lastUpdateDate)

                /*case .pendingFirstUpdate:
                    PendingFirstUpdateView()*/
                }
            }
            .navigationTitle("Atualização de Conteúdos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $displayKnowMore) {
                ContentUpdateStatusView.KnowMoreView()
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }
}

// MARK: - Subviews

extension ContentUpdateStatusView {

    struct UpdatingView: View {

        var body: some View {
            MSTHeroCard(
                status: .updating,
                title: "Atualização de conteúdos em andamento",
                subtitle: "Por favor, aguarde a atualização ser concluída."
            )
            .padding(.horizontal, .spacing(.medium))
        }
    }

    private struct AllOkView: View {

        @State var lastUpdateAttempt: String
        @Binding var displayKnowMore: Bool
        @Binding var selectedDetent: PresentationDetent

        @State private var updates: [SyncLog] = []
        @State private var hiddenUpdates: Int = 0
        @State private var lastUpdateText: String = ""

        private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

        private func updateLastUpdateText() {
            if lastUpdateAttempt == "" {
                lastUpdateText = "A última tentativa de atualização não retornou resultados."
            } else {
                guard let date = lastUpdateAttempt.iso8601withFractionalSeconds else {
                    return lastUpdateText = ""
                }
                guard date.minutesPassed(1) else {
                    return lastUpdateText = "Atualizado agora há pouco."
                }
                lastUpdateText = "Última atualização \(lastUpdateAttempt.asRelativeDateTime ?? "")."
            }
        }

        var body: some View {
            VStack(spacing: .spacing(.xLarge)) {
                MSTHeroCard(
                    status: .done,
                    title: "Conteúdos atualizados",
                    subtitle: lastUpdateText,
                    footnote: "Nenhuma ação é necessária."
                )

                GlassButton(title: "Como o M.S.T. funciona?", color: .mstRed) {
                    selectedDetent = .large
                    displayKnowMore.toggle()
                }

                HistoryView(
                    updates: updates,
                    hiddenUpdatesCount: hiddenUpdates
                )
            }
            .padding(.horizontal, .spacing(.medium))
            .padding(.bottom, .spacing(.xxLarge))
            .onAppear {
                updateLastUpdateText()
                updates = LocalDatabase.shared.lastFewSyncLogs()
                hiddenUpdates = LocalDatabase.shared.totalSyncLogCount()
            }
            .onReceive(timer) { time in
                updateLastUpdateText()
            }
        }
    }

    private struct UpdateErrorView: View {

        let lastUpdateDate: String

        @State private var updates: [SyncLog] = []
        @State private var hiddenUpdates: Int = 0

        private let checkConnection = "Verifique a sua conexão à Internet."

        private var title: String {
            if lastUpdateDate == "all" {
                return "Nunca atualizado"
            } else {
                return "Última atualização com sucesso \(lastUpdateDate.asRelativeDateTime ?? "")"
            }
        }

        private var subtitle: String {
            if lastUpdateDate == "all" {
                return "A última tentativa de atualização não obteve resultados. " + checkConnection
            } else {
                return "Houve um problema na última tentativa de atualização. " + checkConnection
            }
        }

        var body: some View {
            VStack(spacing: .spacing(.xxLarge)) {
                MSTHeroCard(
                    status: .error,
                    title: title,
                    subtitle: subtitle
                )

                HistoryView(
                    updates: updates,
                    hiddenUpdatesCount: hiddenUpdates
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
            .onAppear {
                updates = LocalDatabase.shared.lastFewSyncLogs()
                hiddenUpdates = LocalDatabase.shared.totalSyncLogCount()
            }
        }
    }

    private struct PendingFirstUpdateView: View {

        var body: some View {
            VStack(spacing: 30) {
                Image(systemName: "clock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70)
                    .foregroundColor(.gray)

                Text("Aguardando Primeira Atualização")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Button {

                } label: {
                    Text("Atualizar Agora")
                        .bold()
                        .padding(.horizontal, .spacing(.medium))
                }
                .borderedButton(colored: .accentColor)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private struct HistoryView: View {

        let updates: [SyncLog]
        let hiddenUpdatesCount: Int

        @State private var isSectionExpanded = false

        var body: some View {
            DisclosureGroup(
                isExpanded: $isSectionExpanded,
                content: {
                    LazyVStack(spacing: .spacing(.medium)) {
                        ForEach(updates) { update in
                            SyncInfoCard(
                                imageName: update.logType == .error ? "exclamationmark.triangle" : "checkmark",
                                imageColor: update.logType == .error ? .orange : .green,
                                title: update.description,
                                timestamp: update.dateTime.asRelativeDateTime ?? ""
                            )
                            .onTapGesture {
                                dump(update)
                            }
                        }

                        if hiddenUpdatesCount > 0 {
                            Text("E outras \(hiddenUpdatesCount) atualizações registradas.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, .spacing(.medium))
                },
                label: {
                    Text("Histórico completo")
                }
            )
            .foregroundStyle(.primary)
        }
    }
}

// MARK: - Previews

#Preview("Updating") {
    ScrollView {
        ContentUpdateStatusView.UpdatingView()
    }
}

//#Preview("Update Error") {
//    let syncValuesUpdateError: SyncValues = SyncValues(syncStatus: .updateError)
//    return ContentUpdateStatusView(lastUpdateAttempt: "", lastUpdateDate: "2023-08-11T20:29:46.562Z")
//        .environment(syncValuesUpdateError)
//}
//
//#Preview("First Update Not Allowed") {
//    let syncValuesUpdateError: SyncValues = SyncValues(syncStatus: .pendingFirstUpdate)
//    return ContentUpdateStatusView(lastUpdateAttempt: "", lastUpdateDate: "")
//        .environment(syncValuesUpdateError)
//}
