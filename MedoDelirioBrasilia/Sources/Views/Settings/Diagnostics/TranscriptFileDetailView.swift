//
//  TranscriptFileDetailView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/03/26.
//

import SwiftUI

struct TranscriptFileDetailView: View {

    let file: TranscriptFileInfo

    @State private var content: String = ""

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(file.episodeId + ".srt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: file.url)
            }
        }
        .onAppear {
            content = (try? String(contentsOf: file.url, encoding: .utf8)) ?? "Não foi possível ler o arquivo."
        }
    }
}
