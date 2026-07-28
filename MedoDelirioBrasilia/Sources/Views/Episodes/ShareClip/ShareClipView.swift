//
//  ShareClipView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/02/26.
//

import AVFoundation
import SwiftUI

struct ShareClipView: View {

    let episode: PodcastEpisode
    var onExportComplete: () -> Void = {}

    @Environment(EpisodePlayer.self) private var player
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService
    @Environment(\.dismiss) private var dismiss

    @State private var samples: [Float]?
    @State private var clipStart: TimeInterval = 0
    @State private var clipEnd: TimeInterval = 0
    @State private var loadError: String?
    @State private var previewPlayer: AVAudioPlayer?
    @State private var isPreviewPlaying: Bool = false
    @State private var previewCurrentTime: TimeInterval = 0
    @State private var previewTask: Task<Void, Never>?
    @State private var showPreview: Bool = false
    @State private var transcriptCues: [SRTCue] = []
    /// Persisted so the sheet always opens on the user's preferred pick mode.
    @AppStorage("shareClipSelectionSource") private var selectionSource: SelectionSource = .waveform
    @State private var startCueIndex: Int?
    @State private var endCueIndex: Int?
    @State private var showMaxLengthWarning: Bool = false
    @State private var warningTask: Task<Void, Never>?
    @State private var transcriptUnavailableReason: String?
    @State private var transcriptComingSoon: Bool = false

    private enum SelectionSource: String {
        case waveform
        case transcript
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: .spacing(.medium)) {
                selectionSourceHeader

                if selectionSource == .waveform {
                    waveformPane
                } else {
                    transcriptPane
                }
            }
            .navigationTitle("Criar Clipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Próximo") {
                        pausePreview()
                        showPreview = true
                    }
                    .fontWeight(.semibold)
                    .tint(.orange)
                    .disabled(!canProceed)
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                ShareClipConfirmView(config: clipConfiguration, onExportComplete: onExportComplete)
            }
        }
        .task {
            // Clip range and transcript preselection are ready before the
            // (slower) waveform generation, so the user can switch to the
            // Transcrição tab as soon as the sheet opens.
            setInitialClipRange()
            loadTranscript()
            preselectInitialCue()
            await loadWaveform()
        }
        .onChange(of: clipStart) { resetPreviewToActiveStart() }
        .onChange(of: clipEnd) { resetPreviewToActiveStart() }
        .onChange(of: startCueIndex) { resetPreviewToActiveStart() }
        .onChange(of: endCueIndex) { resetPreviewToActiveStart() }
        .onChange(of: selectionSource) { resetPreviewToActiveStart() }
        .onChange(of: transcriptDownloadService.transcriptsDownloaded) {
            // Fires as soon as the priority download lands this episode's SRT
            // (before the rest finish), so opting in feels instant.
            guard transcriptDownloadService.transcriptsDownloaded else { return }
            loadTranscript()
            if startCueIndex == nil {
                preselectInitialCue()
            }
        }
        .onDisappear {
            pausePreview()
            previewPlayer = nil
            ShareClipGenerator.cleanupOutputDirectory()
        }
    }

    // MARK: - Active Clip Range

    /// Each tab keeps its own selection: the waveform edits `clipStart`/`clipEnd`
    /// directly, while the transcript's range is derived from the selected cues.
    /// Everything downstream (timestamps, preview playback, export) reads the
    /// active tab's range, so the two never contaminate each other.
    private var activeClipStart: TimeInterval {
        guard
            selectionSource == .transcript,
            let start = startCueIndex, transcriptCues.indices.contains(start)
        else { return clipStart }
        return max(transcriptCues[start].startTime, 0)
    }

    private var activeClipEnd: TimeInterval {
        guard
            selectionSource == .transcript,
            let end = endCueIndex, transcriptCues.indices.contains(end)
        else { return clipEnd }
        let cueEnd = transcriptCues[end].endTime
        return player.duration > 0 ? min(cueEnd, player.duration) : cueEnd
    }

    /// The waveform tab needs its samples loaded; the transcript tab only
    /// needs a picked range — it must not wait on waveform generation.
    private var canProceed: Bool {
        guard loadError == nil else { return false }
        switch selectionSource {
        case .waveform: return samples != nil
        case .transcript: return startCueIndex != nil && endCueIndex != nil
        }
    }

    private var clipConfiguration: ShareClipGenerator.Configuration {
        .init(
            episode: episode,
            audioFileURL: EpisodePlayer.localFileURL(for: episode),
            clipStart: activeClipStart,
            clipEnd: activeClipEnd,
            shareMode: .square,
            transcriptCues: transcriptCues.filter { $0.endTime > activeClipStart && $0.startTime < activeClipEnd }
        )
    }

    // MARK: - Selection Source

    private var selectionSourceHeader: some View {
        VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
            Text("Selecionar trecho usando:")
                .font(.footnote)
                .foregroundStyle(.gray)

            Picker("Selecionar trecho usando", selection: $selectionSource) {
                Text("Forma de Onda").tag(SelectionSource.waveform)
                Text("Transcrição").tag(SelectionSource.transcript)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, .spacing(.xLarge))
        .padding(.top, .spacing(.small))
    }

    // MARK: - Waveform Pane

    private var waveformPane: some View {
        ScrollView {
            VStack(spacing: .spacing(.xxLarge)) {
                waveformSection

                previewControls

                Text("Selecione o trecho que você quer compartilhar.\n\nArraste a forma de onda para os lados para acessar outras partes do episódio.")
                    .font(.callout)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, .spacing(.xLarge))
            .padding(.vertical, .spacing(.large))
        }
    }

    // MARK: - Transcript Pane

    /// Routes between the opt-in prompt, download progress, an unavailable
    /// notice, and the actual line-picking list.
    @ViewBuilder
    private var transcriptPane: some View {
        if !transcriptDownloadService.transcriptsDownloaded {
            if case .downloading = transcriptDownloadService.state {
                TranscriptDownloadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    TranscriptDownloadPromptView(
                        icon: "text.quote",
                        title: "Selecione trechos pelo texto",
                        subtitle: "Baixe as transcrições para escolher o trecho do clipe lendo o que foi dito. É rápido e usa poucos dados.",
                        priorityEpisodeId: episode.id,
                        analyticsSource: "ShareClip"
                    )
                    .padding(.top, .spacing(.xxLarge))
                }
            }
        } else if transcriptCues.isEmpty {
            TranscriptNotAvailableView(
                reason: transcriptUnavailableReason ?? "Transcrição não encontrada para esse episódio.",
                isComingSoon: transcriptComingSoon
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            transcriptSelectionContent
        }
    }

    private var transcriptSelectionContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: .spacing(.medium)) {
                Text("Toque na primeira e na última linha do trecho que você quer compartilhar.")
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                clearSelectionButton
            }
            .padding(.horizontal, .spacing(.xLarge))
            .padding(.bottom, .spacing(.small))

            TranscriptCueSelectionList(
                cues: transcriptCues,
                startIndex: startCueIndex,
                endIndex: endCueIndex,
                onTap: handleCueTap
            )
            .overlay(alignment: .bottom) {
                if showMaxLengthWarning {
                    maxLengthWarning
                }
            }

            previewControls
                .padding(.vertical, .spacing(.medium))
        }
    }

    /// Red trash button that clears the picked range, with the Liquid Glass
    /// look on iOS 26 and a plain bordered fallback elsewhere.
    @ViewBuilder
    private var clearSelectionButton: some View {
        let button = Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                startCueIndex = nil
                endCueIndex = nil
            }
        } label: {
            Image(systemName: "trash")
        }
        .tint(.red)
        .disabled(startCueIndex == nil)
        .accessibilityLabel("Limpar seleção")

        if #available(iOS 26, *) {
            button.buttonStyle(.glass)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var maxLengthWarning: some View {
        Label("Um clipe pode ter no máximo \(Self.maxLengthText).", systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, .spacing(.medium))
            .padding(.vertical, .spacing(.small))
            .background(Capsule().fill(.thinMaterial))
            .padding(.bottom, .spacing(.small))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private static let maxLengthText: String = {
        let total = Int(WaveformView.maxClipLength)
        return "\(total / 60)min\(String(format: "%02d", total % 60))s"
    }()

    /// Shows the max-length warning for a few seconds, restarting the timer on
    /// repeated triggers.
    private func flashMaxLengthWarning() {
        warningTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showMaxLengthWarning = true
        }
        warningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showMaxLengthWarning = false
            }
        }
    }

    /// First tap selects a single line; taps outside the range extend it, taps
    /// inside move the nearest endpoint, so any range remains reachable.
    /// Extensions are clamped so the range never exceeds the same maximum clip
    /// length the waveform enforces.
    private func handleCueTap(_ index: Int) {
        if let start = startCueIndex, let end = endCueIndex {
            if index < start {
                let clamped = clampedStartIndex(tapped: index, end: end)
                startCueIndex = clamped
                if clamped != index { flashMaxLengthWarning() }
            } else if index > end {
                let clamped = clampedEndIndex(tapped: index, start: start)
                endCueIndex = clamped
                if clamped != index { flashMaxLengthWarning() }
            } else if index == start, index == end {
                return
            } else if (index - start) <= (end - index) {
                startCueIndex = index
            } else {
                endCueIndex = index
            }
        } else {
            startCueIndex = index
            endCueIndex = index
        }
    }

    /// Walks the tapped start line back down until the range fits the cap.
    private func clampedStartIndex(tapped: Int, end: Int) -> Int {
        var index = tapped
        while index < end,
              transcriptCues[end].endTime - transcriptCues[index].startTime > WaveformView.maxClipLength {
            index += 1
        }
        return index
    }

    /// Walks the tapped end line back up until the range fits the cap.
    private func clampedEndIndex(tapped: Int, start: Int) -> Int {
        var index = tapped
        while index > start,
              transcriptCues[index].endTime - transcriptCues[start].startTime > WaveformView.maxClipLength {
            index -= 1
        }
        return index
    }

    /// Pre-picks the single line at the waveform's preselected spot, so the
    /// transcript tab opens with a starting line already chosen and scrolled
    /// to. The waveform's own range is untouched.
    private func preselectInitialCue() {
        guard let index = transcriptCues.firstIndex(where: { $0.endTime > clipStart }) else { return }
        startCueIndex = index
        endCueIndex = index
    }

    // MARK: - Waveform

    @ViewBuilder
    private var waveformSection: some View {
        if let samples {
            WaveformView(
                samples: samples,
                duration: player.duration,
                clipStart: $clipStart,
                clipEnd: $clipEnd,
                playheadTime: previewCurrentTime,
                showPlayhead: previewPlayer != nil,
                onPlayheadDrag: { time in
                    if isPreviewPlaying { pausePreview() }
                    previewCurrentTime = time
                    previewPlayer?.currentTime = time
                }
            )
        } else if loadError != nil {
            ContentUnavailableView(
                "Não foi possível carregar o áudio",
                systemImage: "waveform.slash",
                description: Text(loadError ?? "")
            )
            .frame(height: 100)
        } else {
            ProgressView("Carregando forma de onda…")
                .frame(height: 100)
                .frame(maxWidth: .infinity)
        }
    }

    private var previewControls: some View {
        HStack(spacing: .spacing(.small)) {
            Button {
                if isPreviewPlaying {
                    pausePreview()
                } else {
                    playPreview()
                }
            } label: {
                Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.orange, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(previewPlayer == nil)

            Label(
                NowPlayingView.formatTime(activeClipStart),
                systemImage: "scissors"
            )

            Text("–")

            Text(NowPlayingView.formatTime(activeClipEnd))

            Text("·")

            Label(
                NowPlayingView.formatTime(max(activeClipEnd - activeClipStart, 0)),
                systemImage: "timer"
            )
        }
        .font(.subheadline)
        .monospacedDigit()
        .foregroundStyle(.orange)
    }

    // MARK: - Preview Playback

    private func playPreview() {
        guard let previewPlayer else { return }
        if player.isPlaying {
            player.togglePlayPause()
        }
        if previewCurrentTime < activeClipStart || previewCurrentTime >= activeClipEnd {
            previewCurrentTime = activeClipStart
        }
        previewPlayer.currentTime = previewCurrentTime
        previewPlayer.play()
        isPreviewPlaying = true
        startPlayheadUpdates()
    }

    private func resetPreviewToActiveStart() {
        if isPreviewPlaying { pausePreview() }
        previewCurrentTime = activeClipStart
    }

    private func pausePreview() {
        if let p = previewPlayer {
            previewCurrentTime = p.currentTime
        }
        previewPlayer?.pause()
        isPreviewPlaying = false
        previewTask?.cancel()
        previewTask = nil
    }

    private func startPlayheadUpdates() {
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            while !Task.isCancelled {
                guard let p = previewPlayer, p.isPlaying else { break }
                previewCurrentTime = p.currentTime
                if p.currentTime >= activeClipEnd {
                    previewPlayer?.pause()
                    isPreviewPlaying = false
                    previewCurrentTime = activeClipStart
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    // MARK: - Data Loading

    /// Centers a 30-second window on the player's current position.
    private func setInitialClipRange() {
        let initialLength = min(30, player.duration)
        let maxStart = max(player.duration - initialLength, 0)
        clipStart = min(max(player.currentTime - initialLength / 2, 0), maxStart)
        clipEnd = clipStart + initialLength
        previewCurrentTime = clipStart
    }

    private func loadWaveform() async {
        let fileURL = EpisodePlayer.localFileURL(for: episode)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            loadError = "Episódio não baixado."
            return
        }
        do {
            let barCount = min(2000, max(200, Int(player.duration * 0.4)))
            let bars = try await AudioWaveformGenerator.generate(from: fileURL, barCount: barCount)
            samples = bars
            previewCurrentTime = clipStart
            previewPlayer = try? AVAudioPlayer(contentsOf: fileURL)
            previewPlayer?.prepareToPlay()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Loads the episode's SRT transcript, if one has been downloaded, reusing
    /// `TranscriptProvider`'s state machine so unavailable/coming-soon reasons
    /// match Now Playing.
    private func loadTranscript() {
        let provider = TranscriptProvider()
        provider.load(episodeId: episode.id, pubDate: episode.pubDate)
        switch provider.state {
        case .loaded(let cues):
            transcriptCues = cues
            transcriptUnavailableReason = nil
            transcriptComingSoon = false
        case .notAvailable(let reason, let isComingSoon):
            transcriptCues = []
            transcriptUnavailableReason = reason
            transcriptComingSoon = isComingSoon
        case .idle:
            break
        }
    }
}

// MARK: - Subviews

extension ShareClipView {

    struct ShareModeButton: View {

        let mode: ShareClipShareMode
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            if #available(iOS 26, *) {
                buttonContent
                    .padding(.vertical, .spacing(.small))
                    .padding(.horizontal, .spacing(.small))
                    .glassEffect(
                        .regular.tint(
                            isSelected ? Color.orange.opacity(colorScheme == .dark ? 0.3 : 0.5) : nil
                        ).interactive()
                    )
                    .onTapGesture { action() }
            } else {
                Button(action: action) {
                    buttonContent
                        .padding(.vertical, .spacing(.small))
                        .padding(.horizontal, .spacing(.small))
                        .background {
                            RoundedRectangle(cornerRadius: .spacing(.huge))
                                .fill(isSelected ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
            }
        }

        private var buttonContent: some View {
            Image(systemName: mode.symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? .orange : .secondary)
                .frame(maxWidth: .infinity)
        }
    }

    struct BrandingButton: View {

        let branding: ShareClipBranding
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            if #available(iOS 26, *) {
                Button { action() } label: {
                    buttonContent
                        .padding(.vertical, .spacing(.small))
                        .padding(.horizontal, .spacing(.small))
                        .glassEffect(
                            .regular.tint(
                                isSelected ? Color.orange.opacity(colorScheme == .dark ? 0.3 : 0.5) : nil
                            ).interactive()
                        )
//                        .onTapGesture { action() }
                }
            } else {
                Button(action: action) {
                    buttonContent
                        .padding(.vertical, .spacing(.small))
                        .padding(.horizontal, .spacing(.small))
                        .background {
                            RoundedRectangle(cornerRadius: .spacing(.huge))
                                .fill(isSelected ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
            }
        }

        private var buttonContent: some View {
            Image(systemName: branding.symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? .orange : .secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    ShareClipView(episode: .mockRecent)
        .environment({
            let p = EpisodePlayer()
            p.currentEpisode = .mockRecent
            p.duration = PodcastEpisode.mockRecent.duration ?? 3945
            p.currentTime = 620
            return p
        }())
        .environment(TranscriptDownloadService())
}
