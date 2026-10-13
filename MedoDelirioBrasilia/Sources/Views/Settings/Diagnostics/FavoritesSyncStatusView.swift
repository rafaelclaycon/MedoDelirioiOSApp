//
//  FavoritesSyncStatusView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/10/26.
//

import SwiftUI

/// Diagnostics: this device's favorites against the copy in iCloud, with the ones that
/// differ by name. Run it on two devices to see where they part ways.
struct FavoritesSyncStatusView: View {

    let database: LocalDatabaseProtocol

    @State private var report: FavoritesSyncReport?
    @State private var titles: [String: String] = [:]
    @State private var checkedAt: Date?

    private var isSyncOn: Bool {
        UserSettings().getEnableICloudSync()
    }

    var body: some View {
        Form {
            if let report {
                Section {
                    LabeledContent("Guardadas", value: "\(report.localFavorites.count)")
                    LabeledContent("Aparecem na lista", value: "\(report.shownCount)")
                    LabeledContent("Fora do catálogo", value: "\(report.notInCatalog.count)")
                    LabeledContent("Remoções lembradas", value: "\(report.localRemovals)")
                } header: {
                    Text("Neste aparelho")
                } footer: {
                    Text("\"Fora do catálogo\" são favoritas cuja vírgula ou música ainda não está neste aparelho. Elas aparecem depois da próxima atualização de conteúdo.")
                }

                Section {
                    if let cloudFavorites = report.cloudFavorites {
                        LabeledContent("Favoritas", value: "\(cloudFavorites.count)")
                        LabeledContent("Remoções", value: "\(report.cloudRemovals)")
                    } else {
                        Text("Nada recebido do iCloud ainda.")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Sincronização", value: isSyncOn ? "Ligada" : "Desligada")
                } header: {
                    Text("No iCloud")
                } footer: {
                    Text("A cópia do iCloud como este aparelho a recebeu por último.")
                }

                Section {
                    if report.isInStep {
                        Label("Este aparelho e o iCloud estão iguais.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        differences("Só neste aparelho", ids: report.onlyHere)
                        differences("Só no iCloud", ids: report.onlyInCloud)
                        differences("Fora do catálogo", ids: report.notInCatalog)
                    }
                } header: {
                    Text("Diferenças")
                }

                Section {
                    Button("Atualizar") {
                        NSUbiquitousKeyValueStore.default.synchronize()
                        load()
                    }
                } footer: {
                    if let checkedAt {
                        Text("Conferido \(checkedAt.formatted(date: .omitted, time: .standard)).")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Favoritas no iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            load()
        }
        .onReceive(NotificationCenter.default.publisher(for: ContentFavoritesSyncStore.didChangeExternally)) { _ in
            load()
        }
    }

    @ViewBuilder
    private func differences(_ title: String, ids: Set<String>) -> some View {
        if !ids.isEmpty {
            DisclosureGroup("\(title) (\(ids.count))") {
                ForEach(ids.sorted(), id: \.self) { id in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titles[id] ?? "Fora do catálogo")
                        Text(id)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func load() {
        let localDates = (try? database.allFavoriteDates()) ?? [:]
        let cloud: [String: ContentFavoriteRecord]? = CloudStateSync.cloudRecords(forKey: CloudStateSync.contentFavoriteKey)
        let cloudIDs = Set(cloud?.keys.map { $0 } ?? [])
        let allIDs = Array(Set(localDates.keys).union(cloudIDs))
        let content = (try? database.content(withIds: allIDs)) ?? []

        titles = Dictionary(content.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        report = FavoritesSyncReport(
            localDates: localDates,
            localTombstones: (try? database.allFavoriteTombstones()) ?? [:],
            cloudRecords: cloud,
            catalogIDs: Set(content.map(\.id))
        )
        checkedAt = .now
    }
}
