//
//  TranscriptFilesBrowserView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/03/26.
//

import SwiftUI

struct TranscriptFilesBrowserView: View {

    @State private var files: [TranscriptFileInfo] = []
    @State private var searchText = ""

    private var filtered: [TranscriptFileInfo] {
        guard !searchText.isEmpty else { return files }
        let query = searchText.lowercased()
        return files.filter { $0.episodeId.lowercased().contains(query) }
    }

    var body: some View {
        List {
            Section {
                ForEach(filtered) { file in
                    NavigationLink {
                        TranscriptFileDetailView(file: file)
                    } label: {
                        HStack {
                            Text(file.episodeId)
                                .font(.body.monospaced())
                                .lineLimit(1)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(file.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(file.formattedDate)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } footer: {
                if searchText.isEmpty {
                    Text("\(files.count) arquivo(s)")
                } else {
                    Text("\(filtered.count) de \(files.count) arquivo(s)")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Buscar por ID do episódio")
        .autocorrectionDisabled()
        .navigationTitle("Transcrições")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFiles() }
    }

    private func loadFiles() {
        let dir = TranscriptDownloadService.transcriptsDirectory()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        files = urls
            .filter { $0.pathExtension == "srt" }
            .compactMap { url -> TranscriptFileInfo? in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                return TranscriptFileInfo(
                    url: url,
                    episodeId: url.deletingPathExtension().lastPathComponent,
                    size: values?.fileSize ?? 0,
                    modificationDate: values?.contentModificationDate
                )
            }
            .sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
    }
}

struct TranscriptFileInfo: Identifiable {

    let url: URL
    let episodeId: String
    let size: Int
    let modificationDate: Date?

    var id: String { episodeId }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var formattedDate: String {
        guard let date = modificationDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
