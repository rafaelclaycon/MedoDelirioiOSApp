//
//  StorageSettingsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/03/26.
//

import SwiftUI
import Kingfisher

struct StorageSettingsView: View {

    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService

    @State private var episodesBytes: UInt64 = 0
    @State private var soundsBytes: UInt64 = 0
    @State private var songsBytes: UInt64 = 0
    @State private var transcriptsBytes: UInt64 = 0
    @State private var imageCacheBytes: UInt64 = 0

    @State private var episodesCount: Int = 0

    @State private var autoDeletePlayed: Bool = UserSettings().getAutoDeletePlayedEpisodes()

    @State private var showDeletePlayedConfirmation = false
    @State private var showDeletePlayedSuccess = false
    @State private var deletedPlayedCount = 0

    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteAllSuccess = false
    @State private var showClearImageCacheSuccess = false

    @State private var showDeleteTranscriptsConfirmation = false
    @State private var showDeleteTranscriptsSuccess = false
    @State private var showDeleteTranscriptsError = false
    @State private var deleteTranscriptsErrorMessage = ""

    @State private var isLoading = true

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var body: some View {
        Form {
            StorageBarView(
                episodesBytes: episodesBytes,
                soundsBytes: soundsBytes,
                songsBytes: songsBytes,
                transcriptsBytes: transcriptsBytes,
                imageCacheBytes: imageCacheBytes,
                isLoading: isLoading
            )

            Section {
                Toggle("Apagar episódios ouvidos automaticamente", isOn: $autoDeletePlayed)
                    .onChange(of: autoDeletePlayed) {
                        UserSettings().setAutoDeletePlayedEpisodes(to: autoDeletePlayed)
                    }
            } header: {
                Text("Episódios baixados")
            } footer: {
                Text("Quando ativado, o arquivo de cada episódio será apagado automaticamente após ser ouvido por completo.")
            }

            Section {
                HStack {
                    Text("Tamanho")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(sizeWithCount(bytes: episodesBytes, count: episodesCount))
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Apagar episódios já ouvidos", role: .destructive) {
                    showDeletePlayedConfirmation = true
                }
                .alert(
                    "Apagar episódios já ouvidos?",
                    isPresented: $showDeletePlayedConfirmation
                ) {
                    Button("Apagar", role: .destructive) {
                        deletePlayedEpisodes()
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Os episódios já marcados como ouvidos serão removidos. Você poderá baixá-los novamente.")
                }
                .alert(
                    "\(deletedPlayedCount) episódio(s) apagado(s)",
                    isPresented: $showDeletePlayedSuccess
                ) {
                    Button("OK") {}
                }

                Button("Apagar todos os episódios baixados", role: .destructive) {
                    showDeleteAllConfirmation = true
                }
                .alert(
                    "Apagar todos os episódios baixados?",
                    isPresented: $showDeleteAllConfirmation
                ) {
                    Button("Apagar todos", role: .destructive) {
                        deleteAllEpisodes()
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Todos os episódios baixados serão removidos. Você poderá baixá-los novamente.")
                }
                .alert("Episódios apagados com sucesso", isPresented: $showDeleteAllSuccess) {
                    Button("OK") {}
                }
            }

            Section {
                HStack {
                    Text("Vírgulas")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(StorageHelper.formattedSize(soundsBytes))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Músicas")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(StorageHelper.formattedSize(songsBytes))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Conteúdo do app")
            } footer: {
                Text("Esses arquivos são essenciais para o funcionamento do app e não podem ser removidos.")
            }

            if FeatureFlag.isEnabled(.projectEleDisseIssoMesmo) {
                Section("Transcrições") {
                    HStack {
                        Text("Tamanho")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(StorageHelper.formattedSize(transcriptsBytes))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Apagar todas as transcrições", role: .destructive) {
                        showDeleteTranscriptsConfirmation = true
                    }
                    .disabled(transcriptsBytes == 0)
                    .alert(
                        "Apagar todas as transcrições?",
                        isPresented: $showDeleteTranscriptsConfirmation
                    ) {
                        Button("Apagar", role: .destructive) {
                            deleteAllTranscripts()
                        }
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("As transcrições baixadas serão removidas. Para pesquisar dentro dos episódios, será necessário baixá-las novamente.")
                    }
                    .alert("Transcrições apagadas com sucesso", isPresented: $showDeleteTranscriptsSuccess) {
                        Button("OK") {}
                    }
                    .alert("Erro ao apagar transcrições", isPresented: $showDeleteTranscriptsError) {
                        Button("OK") {}
                    } message: {
                        Text(deleteTranscriptsErrorMessage)
                    }
                }
            }

            Section("Cache de imagens") {
                HStack {
                    Text("Tamanho")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(StorageHelper.formattedSize(imageCacheBytes))
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Limpar cache de imagens", role: .destructive) {
                    ImageCache.default.clearMemoryCache()
                    ImageCache.default.clearDiskCache {
                        updateImageCacheBytes()
                        showClearImageCacheSuccess = true
                    }
                }
                .alert("Cache de imagens limpado com sucesso", isPresented: $showClearImageCacheSuccess) {
                    Button("OK") {}
                }
            }
        }
        .navigationTitle("Armazenamento")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadAllSizes()
        }
    }

    // MARK: - Functions

    private func loadAllSizes() {
        isLoading = true

        let episodes = documentsURL.appendingPathComponent(InternalFolderNames.downloadedEpisodes)
        let sounds = documentsURL.appendingPathComponent(InternalFolderNames.downloadedSounds)
        let songs = documentsURL.appendingPathComponent(InternalFolderNames.downloadedSongs)
        let transcripts = documentsURL.appendingPathComponent(InternalFolderNames.transcripts)

        episodesBytes = (try? StorageHelper.sizeOfDirectory(at: episodes)) ?? 0
        soundsBytes = (try? StorageHelper.sizeOfDirectory(at: sounds)) ?? 0
        songsBytes = (try? StorageHelper.sizeOfDirectory(at: songs)) ?? 0
        transcriptsBytes = (try? StorageHelper.sizeOfDirectory(at: transcripts)) ?? 0

        episodesCount = StorageHelper.fileCount(in: episodes)

        updateImageCacheBytes()

        isLoading = false
    }

    private func refreshEpisodeStats() {
        let episodes = documentsURL.appendingPathComponent(InternalFolderNames.downloadedEpisodes)
        episodesBytes = (try? StorageHelper.sizeOfDirectory(at: episodes)) ?? 0
        episodesCount = StorageHelper.fileCount(in: episodes)
    }

    private func sizeWithCount(bytes: UInt64, count: Int) -> String {
        let size = StorageHelper.formattedSize(bytes)
        if count == 1 {
            return "\(size) (1 arquivo)"
        }
        return "\(size) (\(count) arquivos)"
    }

    private func deletePlayedEpisodes() {
        let episodesURL = documentsURL.appendingPathComponent(InternalFolderNames.downloadedEpisodes)
        let playedIDs = (try? LocalDatabase.shared.allEpisodePlayedIDs()) ?? []
        deletedPlayedCount = StorageHelper.removeFiles(forEpisodeIDs: playedIDs, in: episodesURL)
        refreshEpisodeStats()
        showDeletePlayedSuccess = true
    }

    private func deleteAllEpisodes() {
        let episodesURL = documentsURL.appendingPathComponent(InternalFolderNames.downloadedEpisodes)
        do {
            try StorageHelper.removeAllFiles(in: episodesURL)
            refreshEpisodeStats()
            showDeleteAllSuccess = true
        } catch {
            // Size will reflect whatever was partially deleted
            refreshEpisodeStats()
        }
    }

    private func deleteAllTranscripts() {
        do {
            try transcriptDownloadService.deleteAllTranscripts()
            refreshTranscriptStats()
            showDeleteTranscriptsSuccess = true
        } catch {
            refreshTranscriptStats()
            deleteTranscriptsErrorMessage = error.localizedDescription
            showDeleteTranscriptsError = true
        }
    }

    private func refreshTranscriptStats() {
        let transcripts = documentsURL.appendingPathComponent(InternalFolderNames.transcripts)
        transcriptsBytes = (try? StorageHelper.sizeOfDirectory(at: transcripts)) ?? 0
    }

    private func updateImageCacheBytes() {
        ImageCache.default.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                imageCacheBytes = UInt64(size)
            case .failure:
                imageCacheBytes = 0
            }
        }
    }
}

// MARK: - Storage Bar

struct StorageBarView: View {

    let episodesBytes: UInt64
    let soundsBytes: UInt64
    let songsBytes: UInt64
    let transcriptsBytes: UInt64
    let imageCacheBytes: UInt64
    let isLoading: Bool

    private var totalBytes: UInt64 {
        segments.reduce(0) { $0 + $1.1 }
    }

    private var segments: [(String, UInt64, Color)] {
        var result: [(String, UInt64, Color)] = [
            ("Episódios", episodesBytes, .blue),
            ("Vírgulas", soundsBytes, .green),
            ("Músicas", songsBytes, .purple),
        ]
        if FeatureFlag.isEnabled(.projectEleDisseIssoMesmo) {
            result.append(("Transcrições", transcriptsBytes, .orange))
        }
        result.append(("Imagens", imageCacheBytes, .yellow))
        return result
    }

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(StorageHelper.formattedSize(totalBytes))
                        .font(.title2.bold())

                    GeometryReader { geometry in
                        HStack(spacing: 2) {
                            if totalBytes == 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.3))
                            } else {
                                ForEach(segments.indices, id: \.self) { index in
                                    let segment = segments[index]
                                    let fraction = CGFloat(segment.1) / CGFloat(totalBytes)
                                    if fraction > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(segment.2)
                                            .frame(width: max(fraction * geometry.size.width - 2, 4))
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 12)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                        ForEach(segments.indices, id: \.self) { index in
                            let segment = segments[index]
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(segment.2)
                                    .frame(width: 8, height: 8)
                                Text(segment.0)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StorageSettingsView()
    }
    .environment(TranscriptDownloadService())
}
