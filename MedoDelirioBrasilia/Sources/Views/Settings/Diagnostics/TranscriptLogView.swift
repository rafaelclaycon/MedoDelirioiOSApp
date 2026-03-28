//
//  TranscriptLogView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/03/26.
//

import SwiftUI

struct TranscriptLogView: View {

    @Environment(TranscriptDownloadService.self) private var service

    private var entries: [TranscriptLogEntry] {
        service.operationLog.reversed()
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Nenhum registro",
                    systemImage: "doc.text",
                    description: Text("Operações de transcrição aparecerão aqui.")
                )
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.message)
                            .font(.subheadline)

                        Text(entry.date, format: .dateTime.day().month().year().hour().minute().second())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Log de Operações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar", role: .destructive) {
                        service.clearLog()
                    }
                }
            }
        }
    }
}
