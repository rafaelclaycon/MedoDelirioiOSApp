//
//  EpisodePlaybackControlsColumn.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 22/05/26.
//

import SwiftUI

// MARK: - Reusable Column (button + timestamp)

struct EpisodePlaybackControlsColumn: View {

    let episode: PodcastEpisode
    var progress: EpisodeProgressStore.EpisodeProgress?

    private var hasProgress: Bool {
        guard let progress else { return false }
        return progress.currentTime > 0 && progress.duration > 0
    }

    var body: some View {
        VStack(spacing: .spacing(.small)) {
            EpisodeRowPlaybackControls(episode: episode)

            if hasProgress, let progress {
                Text(formatTimeRemaining(progress.duration - progress.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let duration = episode.duration {
                Text(formatCompactDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 60)
    }
}

// MARK: - Play/Pause/Download Button

struct EpisodeRowPlaybackControls: View {

    @Environment(EpisodePlayer.self) private var episodePlayer

    let episode: PodcastEpisode

    private var isThisEpisodePlaying: Bool {
        episodePlayer.isCurrentEpisode(episode) && episodePlayer.isPlaying
    }

    var body: some View {
        if isThisEpisodePlaying {
            pauseButton
        } else if episodePlayer.isDownloading(episode) {
            downloadProgressIndicator
        } else if episodePlayer.isPreparing(episode) {
            ProgressView()
                .frame(width: 32, height: 32)
        } else {
            playActionButton
        }
    }

    @ViewBuilder
    private var pauseButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                episodePlayer.togglePlayPause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .padding(.spacing(.small))
            .glassEffect(
                .regular.tint(
                    Color.green.opacity(0.3)
                ).interactive()
            )
        } else {
            Button {
                episodePlayer.togglePlayPause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .padding(.vertical, .spacing(.xxxSmall))
            }
            .capsule(colored: .accentColor)
        }
    }

    @ViewBuilder
    private var playActionButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                Task {
                    await episodePlayer.play(episode: episode)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .padding(.spacing(.small))
            .glassEffect(
                .regular.tint(
                    Color.green.opacity(0.3)
                ).interactive()
            )
        } else {
            Button {
                Task {
                    await episodePlayer.play(episode: episode)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .padding(.vertical, .spacing(.xxxSmall))
            }
            .capsule(colored: .accentColor)
        }
    }

    private var downloadProgressIndicator: some View {
        let progress = episodePlayer.downloadProgress[episode.id] ?? 0

        return VStack(spacing: .spacing(.xxxSmall)) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Button {
                    episodePlayer.cancelDownload()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 32, height: 32)

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Helpers

func formatCompactDuration(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(max(seconds, 0)) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)min" }
    if hours > 0 { return "\(hours)h" }
    if minutes > 0 { return "\(minutes)min" }
    return "< 1min"
}

private func formatTimeRemaining(_ remaining: TimeInterval) -> String {
    let totalMinutes = Int(max(remaining, 0)) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)min restantes"
    } else if hours > 0 {
        return "\(hours)h restantes"
    } else if minutes > 0 {
        return "\(minutes)min restantes"
    } else {
        return "< 1min restante"
    }
}
