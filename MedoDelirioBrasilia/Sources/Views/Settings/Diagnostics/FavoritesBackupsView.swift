//
//  FavoritesBackupsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// The favorites backups `CloudStateSync` takes before syncing, to look through and
/// restore from.
struct FavoritesBackupsView: View {

    let backupStore: FavoritesBackupStore
    let database: LocalDatabaseProtocol

    @State private var backups: [FavoritesBackupFile] = []

    var body: some View {
        List {
            if backups.isEmpty {
                Text("Nenhum backup ainda. O primeiro é feito quando as favoritas sincronizam com o iCloud pela primeira vez.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(backups) { file in
                        NavigationLink {
                            FavoritesBackupDetailView(
                                file: file,
                                backupStore: backupStore,
                                database: database
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                                Text(file.title)
                                Text("\(file.count) favoritas")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Cópias das vírgulas e músicas favoritas, feitas antes de sincronizar com o iCloud. Restaurar só adiciona as que faltam e nunca remove nenhuma.")
                }
            }
        }
        .navigationTitle("Backups das Favoritas")
        .onAppear {
            backups = backupStore.backups()
        }
    }
}

// MARK: - Detail

struct FavoritesBackupDetailView: View {

    let file: FavoritesBackupFile
    let backupStore: FavoritesBackupStore
    let database: LocalDatabaseProtocol

    @State private var backup: FavoritesBackup?
    @State private var titles: [String: String] = [:]
    @State private var missingIds: Set<String> = []
    @State private var showRestoreConfirmation = false
    @State private var restoredCount: Int?

    private var missing: [FavoritesBackup.Entry] {
        backup?.favorites.filter { missingIds.contains($0.contentId) } ?? []
    }

    private var present: [FavoritesBackup.Entry] {
        backup?.favorites.filter { !missingIds.contains($0.contentId) } ?? []
    }

    var body: some View {
        List {
            if backup == nil {
                Text("Não foi possível ler este backup.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    Button("Restaurar \(missing.count) favoritas") {
                        showRestoreConfirmation = true
                    }
                    .disabled(missing.isEmpty)
                } footer: {
                    Text(missing.isEmpty
                         ? "Todas as favoritas deste backup já estão neste aparelho."
                         : "Adiciona de volta as que faltam, sem remover nenhuma. Elas também voltam nos outros aparelhos sincronizados.")
                }

                entriesSection("Faltando neste aparelho", entries: missing)
                entriesSection("Já estão nas favoritas", entries: present)
            }
        }
        .navigationTitle(file.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Restaurar \(missing.count) favoritas?",
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restaurar") {
                guard let backup else { return }
                restoredCount = backupStore.restore(backup)
                load()
            }
        }
        .alert(
            "\(restoredCount ?? 0) favoritas restauradas",
            isPresented: Binding(
                get: { restoredCount != nil },
                set: { if !$0 { restoredCount = nil } }
            )
        ) {
            Button("OK") {}
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func entriesSection(_ title: String, entries: [FavoritesBackup.Entry]) -> some View {
        if !entries.isEmpty {
            Section("\(title) (\(entries.count))") {
                ForEach(entries, id: \.contentId) { entry in
                    VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                        Text(titles[entry.contentId] ?? "Conteúdo não encontrado")
                        Text(entry.contentId)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func load() {
        backup = backupStore.backup(at: file.url)
        guard let backup else { return }

        missingIds = Set(backupStore.missingFavorites(in: backup).map(\.contentId))
        let content = (try? database.content(withIds: backup.favorites.map(\.contentId))) ?? []
        titles = Dictionary(content.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
    }
}

// MARK: - Title

extension FavoritesBackupFile {

    var title: String {
        switch kind {
        case .beforeFirstSync:
            "Antes da primeira sincronização"
        case .daily:
            createdAt.formatted(date: .long, time: .shortened)
        }
    }
}
