//
//  TranscriptDownloadBannerView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/03/26.
//

import SwiftUI

/// Compact horizontal banner that shows transcript download progress or failure.
/// Designed to appear at the top of search suggestions, search results, and the episodes list
/// so the user can track progress without being locked into one screen.
struct TranscriptDownloadBannerView: View {

    @Environment(TranscriptDownloadService.self) private var service
    @Environment(\.colorScheme) private var colorScheme

    @State private var showErrorAlert = false

    private var isDownloading: Bool {
        if case .downloading = service.state { return true }
        return false
    }

    private var isFailed: Bool {
        if case .failed = service.state { return true }
        return false
    }

    private var failedMessage: String {
        if case .failed(let message) = service.state { return message }
        return ""
    }

    private var progress: Double {
        if case .downloading(let p) = service.state { return p }
        return 0
    }

    private var shouldShow: Bool {
        isDownloading || isFailed
    }

    var body: some View {
        if shouldShow {
            VStack(spacing: .spacing(.small)) {
                HStack(spacing: .spacing(.small)) {
                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)

                        Text("Baixando transcrições…")
                            .font(.subheadline)
                            .foregroundStyle(colorScheme == .dark ? .primary : Color.darkestGreen)

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(colorScheme == .dark ? .primary : Color.darkestGreen)
                    } else if isFailed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                            .font(.subheadline)

                        Text("Erro ao baixar transcrições")
                            .font(.subheadline)
                            .foregroundStyle(.white)

                        Spacer()

                        retryButton
                    }
                }

                if isDownloading {
                    ProgressView(value: progress, total: 1.0)
                        .tint(colorScheme == .dark ? .green : Color.darkestGreen)
                        .animation(.default, value: progress)
                }
            }
            .padding(.horizontal, .spacing(.medium))
            .padding(.vertical, .spacing(.small))
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundColor(isFailed ? .red : .green)
                    .opacity(isFailed ? (colorScheme == .dark ? 0.6 : 0.8) : (colorScheme == .dark ? 0.2 : 0.1))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isFailed { showErrorAlert = true }
            }
            .alert("Erro ao Baixar Transcrições", isPresented: $showErrorAlert) {
                Button("Tentar Novamente") {
                    Task { await service.downloadTranscripts() }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(failedMessage)
            }
        }
    }

    @ViewBuilder
    private var retryButton: some View {
        if #available(iOS 26, *) {
            Button {
                Task { await service.downloadTranscripts() }
            } label: {
                Text("Tentar Novamente")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.vertical, .spacing(.xxxSmall))
                    .padding(.horizontal, .spacing(.small))
                    .glassEffect(
                        .regular.tint(
                            Color.white.opacity(0.2)
                        ).interactive()
                    )
            }
        } else {
            Button {
                Task { await service.downloadTranscripts() }
            } label: {
                Text("Tentar Novamente")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }
}

#Preview("Downloading") {
    TranscriptDownloadBannerView()
        .padding()
        .environment(TranscriptDownloadService())
}
