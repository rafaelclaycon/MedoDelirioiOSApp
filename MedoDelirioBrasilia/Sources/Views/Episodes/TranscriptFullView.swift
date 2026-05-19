//
//  TranscriptFullView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/05/26.
//

import SwiftUI

struct TranscriptFullView: View {

    @Environment(EpisodePlayer.self) private var player
    let transcriptProvider: TranscriptProvider

    @State private var searchText: String = ""
    @State private var isScrubbing: Bool = false
    @State private var scrubValue: TimeInterval = 0

    private var allCues: [SRTCue] {
        if case .loaded(let cues) = transcriptProvider.state { return cues }
        return []
    }

    private var filteredCues: [SRTCue] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return allCues }
        return allCues.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            cueList
            Divider()
            bottomBar
        }
        .navigationTitle("Transcrição")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Buscar na transcrição"
        )
    }

    // MARK: - Cue List

    private var cueList: some View {
        Group {
            if allCues.isEmpty {
                ContentUnavailableView(
                    "Transcrição indisponível",
                    systemImage: "text.quote",
                    description: Text("A transcrição deste episódio não foi carregada.")
                )
            } else if filteredCues.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredCues) { cue in
                    cueRow(cue)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }

    private func cueRow(_ cue: SRTCue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                player.seek(to: cue.startTime)
            } label: {
                Text(Self.formatTime(cue.startTime))
                    .font(.caption)
                    .foregroundStyle(Color.darkerGreen)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text(cue.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: .spacing(.xSmall)) {
            scrubberTrack
                .padding(.horizontal, .spacing(.xLarge))

            HStack {
                Text(Self.formatTime(isScrubbing ? scrubValue : player.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text("-" + Self.formatTime(player.duration - (isScrubbing ? scrubValue : player.currentTime)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, .spacing(.xLarge))

            playbackControls
                .padding(.horizontal, .spacing(.xLarge))
                .padding(.bottom, .spacing(.medium))
        }
        .padding(.top, .spacing(.small))
        .background(.bar)
    }

    // MARK: - Scrubber

    private static let trackHeight: CGFloat = 4
    private static let thumbSize: CGFloat = 14
    private static let trackColor = Color.darkerGreen
    private static let trackBgColor = Color(.systemGray4)

    private var scrubberTrack: some View {
        GeometryReader { geometry in
            let totalDuration = max(player.duration, 1)
            let currentValue = isScrubbing ? scrubValue : player.currentTime
            let fraction = CGFloat(currentValue / totalDuration)
            let thumbX = fraction * geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Self.trackBgColor)
                    .frame(height: Self.trackHeight)

                Capsule()
                    .fill(Self.trackColor)
                    .frame(width: max(thumbX, 0), height: Self.trackHeight)

                Circle()
                    .fill(Self.trackColor)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .offset(x: thumbX - Self.thumbSize / 2)
            }
            .frame(height: Self.thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing { isScrubbing = true }
                        let clamped = min(max(value.location.x, 0), geometry.size.width)
                        scrubValue = TimeInterval(clamped / geometry.size.width) * totalDuration
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        player.seek(to: scrubValue)
                    }
            )
        }
        .frame(height: Self.thumbSize)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        ZStack {
            HStack(spacing: .spacing(.xLarge)) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.all, .spacing(.xSmall))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .contentTransition(.symbolEffect(.replace.wholeSymbol))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.all, .spacing(.xSmall))
                }
                .buttonStyle(.plain)
            }

            HStack {
                speedButton
                Spacer()
            }
        }
        .foregroundStyle(.primary)
    }

    private var speedButton: some View {
        Menu {
            ForEach(EpisodePlayer.availableSpeeds, id: \.self) { speed in
                Button {
                    player.setSpeed(speed)
                } label: {
                    if speed == player.playbackSpeed {
                        Label(EpisodePlayer.formattedSpeed(speed), systemImage: "checkmark")
                    } else {
                        Text(EpisodePlayer.formattedSpeed(speed))
                    }
                }
            }
        } label: {
            Text(EpisodePlayer.formattedSpeed(player.playbackSpeed))
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .padding(.vertical, .spacing(.xSmall))
                .padding(.trailing, .spacing(.small))
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Helpers

    static func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = max(Int(time), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Preview

#Preview {
    struct Host: View {
        let player: EpisodePlayer = {
            let p = EpisodePlayer()
            p.currentEpisode = .mockRecent
            p.duration = PodcastEpisode.mockRecent.duration ?? 3945
            p.currentTime = 620
            return p
        }()

        var body: some View {
            NavigationStack {
                TranscriptFullView(transcriptProvider: .mockLoaded())
                    .environment(player)
            }
        }
    }
    return Host()
}
