//
//  EpisodesSettingsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 31/07/26.
//

import SwiftUI

struct EpisodesSettingsView: View {

    @AppStorage(ChapterPreferences.hiddenKey) private var chaptersHidden: Bool = false
    @AppStorage(TranscriptPreferences.disabledKey) private var transcriptsDisabled: Bool = false
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService
    /// Synced from `chapters/v1/version.json`; the default covers a fresh install
    /// that hasn't synced yet.
    @AppStorage(ChapterPreferences.coverageStartKey)
    private var coverageStartRaw: String = ChapterPreferences.defaultCoverageStart
    @State private var autoDeletePlayed: Bool = UserSettings().getAutoDeletePlayedEpisodes()

    @State private var isAskingToDisableTranscripts = false
    /// What turning transcripts off would delete, measured when the user asks, for the
    /// confirmation.
    @State private var transcriptBytesToDelete: UInt64 = 0
    @State private var showDisableError = false
    @State private var showAIUsageDetails = false

    /// Parsed from the synced `yyyy-MM-dd` value and rendered in the device's
    /// locale. Falls back to the raw string if the server ever sends something
    /// unparseable, so the row degrades instead of going blank.
    private var formattedCoverage: String {
        guard let date = ChapterPreferences.coverageDate(from: coverageStartRaw) else {
            return "Atualmente estão disponíveis para episódios a partir de \(coverageStartRaw)."
        }
        return "Atualmente estão disponíveis para episódios de \(date.formatted(.dateTime.day().month(.wide).year())) em diante."
    }

    var body: some View {
        Form {
            Section {
                Toggle("Apagar episódios ouvidos automaticamente", isOn: $autoDeletePlayed)
                    .onChange(of: autoDeletePlayed) {
                        UserSettings().setAutoDeletePlayedEpisodes(to: autoDeletePlayed)
                    }
            } footer: {
                Text("Quando ativado, o arquivo de cada episódio será apagado automaticamente após ser ouvido por completo.")
            }

            chaptersSection

            transcriptsSection

            Section {
                // Resolves against the destination declared on the settings stack,
                // so this pushes the same screen as the root-level Notificações row.
                NavigationLink(value: SettingsDestination.notificationSettings) {
                    Label {
                        Text("Notificação de novos episódios")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Episódios")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Desativar transcrições?",
            isPresented: $isAskingToDisableTranscripts
        ) {
            Button("Desativar", role: .destructive) {
                disableTranscripts()
            }

            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(disableMessage)
        }
        .alert("Não deu para apagar as transcrições", isPresented: $showDisableError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Elas foram desativadas, mas alguns arquivos ficaram. Tente apagá-los em Configurações › Armazenamento.")
        }
        .sheet(isPresented: $showAIUsageDetails) {
            AIUsageDetailsView()
        }
    }

    // MARK: - Coverage

    /// States how far back chapters currently reach. Informational only — the
    /// date widens as older episodes are backfilled.
    private var chaptersSection: some View {
        Section {
//            HStack(alignment: .top, spacing: .spacing(.small)) {
//                Image(systemName: "list.bullet.indent")
//                    .foregroundStyle(Color.darkerGreen)
//                    .frame(width: 24)
//            }
//            .padding(.vertical, .spacing(.xxxSmall))

            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                Text("Capítulos são um jeito de visualizar o episódio separado por tópicos. Eles são gerados por IA a partir das transcrições e podem conter erros.")
                    .font(.callout)

                Text(formattedCoverage)
                    .font(.callout)
                    .bold()

                Text("Episódios mais antigos vão ganhar capítulos aos poucos.")
                    .font(.callout)
            }

            Toggle(
                "Mostrar capítulos",
                isOn: Binding(
                    get: { !chaptersHidden },
                    set: { chaptersHidden = !$0 }
                )
            )
        } header: {
            Text("Capítulos")
        }
    }

    // MARK: - Transcripts

    /// Turning transcripts off asks first, since it deletes what's downloaded. Turning
    /// them back on downloads nothing by itself; the invitations to download return.
    private var transcriptsSection: some View {
        Section {
            Text("As transcrições mostram o que está sendo dito enquanto você ouve, permitem pesquisar dentro dos episódios e escolher trechos pelo texto ao compartilhar. Elas são geradas por IA e podem conter erros.")
                .font(.callout)

            Toggle(
                "Usar transcrições",
                isOn: Binding(
                    get: { !transcriptsDisabled },
                    set: { isOn in
                        if isOn {
                            transcriptDownloadService.enableTranscripts()
                        } else {
                            askToDisableTranscripts()
                        }
                    }
                )
            )
        } header: {
            Text("Transcrições")
        } footer: {
            Button("Como usamos IA nos episódios") {
                showAIUsageDetails = true
            }
            .font(.footnote)
        }
    }

    private var disableMessage: String {
        let reactivate = "Você pode reativá-las aqui quando quiser."
        guard transcriptBytesToDelete > 0 else {
            return "As transcrições deixam de ser oferecidas no player e na pesquisa. \(reactivate)"
        }
        let size = StorageHelper.formattedSize(transcriptBytesToDelete)
        return "As transcrições baixadas (\(size)) serão apagadas e deixam de aparecer no player e na pesquisa. \(reactivate)"
    }

    private func askToDisableTranscripts() {
        transcriptBytesToDelete = (try? StorageHelper.sizeOfDirectory(at: TranscriptDownloadService.transcriptsDirectory())) ?? 0
        isAskingToDisableTranscripts = true
    }

    private func disableTranscripts() {
        do {
            try transcriptDownloadService.disableTranscripts()
        } catch {
            showDisableError = true
        }
        Task {
            await AnalyticsService().send(originatingScreen: "EpisodesSettings", action: "transcripts_disabled")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EpisodesSettingsView()
    }
    .environment(TranscriptDownloadService())
}
