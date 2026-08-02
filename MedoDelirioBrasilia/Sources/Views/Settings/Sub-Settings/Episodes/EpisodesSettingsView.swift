//
//  EpisodesSettingsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 31/07/26.
//

import SwiftUI

struct EpisodesSettingsView: View {

    @AppStorage(ChapterPreferences.hiddenKey) private var chaptersHidden: Bool = false
    /// Synced from `chapters/v1/version.json`; the default covers a fresh install
    /// that hasn't synced yet.
    @AppStorage(ChapterPreferences.coverageStartKey)
    private var coverageStartRaw: String = ChapterPreferences.defaultCoverageStart
    @State private var autoDeletePlayed: Bool = UserSettings().getAutoDeletePlayedEpisodes()

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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EpisodesSettingsView()
    }
}
