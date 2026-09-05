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
    /// Set when the sheet is opened from a chapter's "Compartilhar Trecho", which
    /// preselects that chapter's range and opens on the transcript tab.
    var initialChapterSelection: InitialChapterSelection? = nil
    var onExportComplete: (Bool) -> Void = { _ in }

    /// A chapter's span, as handed over by the chapter list. `end` is nil while
    /// the episode duration is still unknown, in which case only the cap applies.
    struct InitialChapterSelection: Equatable {
        let start: TimeInterval
        let end: TimeInterval?
    }

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
    @State private var chapters: [EpisodeChapter] = []
    /// Persisted so the sheet always opens on the user's preferred pick mode.
    @AppStorage("shareClipSelectionSource") private var storedSelectionSource: SelectionSource = .waveform
    /// Forces the transcript tab for a chapter-launched presentation without
    /// touching the stored preference — arriving here from a chapter shouldn't
    /// silently rewrite which tab the share button opens next time.
    @State private var selectionSourceOverride: SelectionSource?
    @State private var startCueIndex: Int?
    @State private var endCueIndex: Int?
    /// The one transient bottom toast the transcript picker can show at a time —
    /// either an over-limit warning from tap-to-extend, or the chapter-cap
    /// confirmation. They share a slot since both are momentary, self-dismissing
    /// call-outs about the same cap.
    @State private var activeToast: TranscriptToast?
    @State private var showLimitsInfo: Bool = false
    @State private var toastTask: Task<Void, Never>?
    @State private var transcriptUnavailableReason: String?
    @State private var transcriptComingSoon: Bool = false
    /// The transcript grouped by chapter, for the pinned titles in the list.
    /// Built once when both lists land rather than derived in `body`, which
    /// re-runs on every selection change.
    @State private var chapterSections: [TranscriptChapterSection] = []

    private enum SelectionSource: String {
        case waveform
        case transcript
    }

    private enum TranscriptToast {
        /// A tap-to-extend would have pushed the range past the cap, so it was
        /// clamped short of where the user tapped.
        case maxLengthExceeded
        /// A whole-chapter selection — from opening the sheet on a chapter or
        /// tapping its header — fit entirely within the cap. Only fires when the
        /// *whole* chapter made it in; a partial, capped selection says nothing.
        case chapterFullySelected
    }

    /// The tab actually on screen. Everything reads this; only the picker writes,
    /// and writing clears the override so a manual switch sticks as the preference.
    private var selectionSource: SelectionSource {
        selectionSourceOverride ?? storedSelectionSource
    }

    private var selectionSourceBinding: Binding<SelectionSource> {
        Binding(
            get: { selectionSource },
            set: { newValue in
                selectionSourceOverride = nil
                storedSelectionSource = newValue
            }
        )
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
            .alert(SocialVideoLimit.alertTitle, isPresented: $showLimitsInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(SocialVideoLimit.alertMessage)
            }
        }
        .task {
            // Clip range and transcript preselection are ready before the
            // (slower) waveform generation, so the user can switch to the
            // Transcrição tab as soon as the sheet opens.
            setInitialClipRange()
            loadTranscript()
            loadChapters()
            preselectInitialCue()
            applyChapterTabOverride()
            if let initialChapterSelection, chapterFullyFitsCap(initialChapterSelection) {
                flashToast(.chapterFullySelected)
            }
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
                // The initial `.task` may have landed on the waveform tab because
                // the transcript wasn't ready yet — now that it is, give the
                // chapter-launched case its shot at the transcript tab too.
                applyChapterTabOverride()
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
        switch selectionSource {
        case .waveform: return loadError == nil && samples != nil
        case .transcript: return startCueIndex != nil && endCueIndex != nil
        }
    }

    private var clipConfiguration: ShareClipGenerator.Configuration {
        .init(
            episode: episode,
            audioFileURL: EpisodePlayer.localFileURL(for: episode),
            clipStart: activeClipStart,
            clipEnd: activeClipEnd,
            transcriptCues: transcriptCues.filter { $0.endTime > activeClipStart && $0.startTime < activeClipEnd }
        )
    }

    // MARK: - Selection Source

    private var selectionSourceHeader: some View {
        VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
            Text("Selecionar trecho usando:")
                .font(.footnote)
                .foregroundStyle(.gray)

            Picker("Selecionar trecho usando", selection: selectionSourceBinding) {
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
                chapterSections: chapterSections,
                onTap: handleCueTap,
                onTapChapterHeader: selectChapterSection
            )
            .overlay(alignment: .bottom) {
                switch activeToast {
                case .maxLengthExceeded: maxLengthWarning
                case .chapterFullySelected: chapterFullySelectedToast
                case nil: EmptyView()
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

    /// Only shown when the *whole* chapter made it into the selection — a
    /// partial, capped selection doesn't get this confirmation, since claiming
    /// the chapter "fit" would be misleading when part of it was cut off.
    private var chapterFullySelectedToast: some View {
        Label(
            "Corte de capítulo coube no limite máximo de tempo (\(Self.maxLengthText)).",
            systemImage: "checkmark.circle.fill"
        )
        .font(.footnote.weight(.medium))
        .foregroundStyle(.green)
        .padding(.horizontal, .spacing(.medium))
        .padding(.vertical, .spacing(.small))
        .background(Capsule().fill(.thinMaterial))
        .padding(.bottom, .spacing(.small))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private static let maxLengthText = SocialVideoLimit.formatted(WaveformView.maxClipLength)

    /// Shows one of the transcript toasts for a few seconds, restarting the
    /// timer — and swapping the message — on repeated triggers.
    private func flashToast(_ toast: TranscriptToast) {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            activeToast = toast
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                activeToast = nil
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
                if clamped != index { flashToast(.maxLengthExceeded) }
            } else if index > end {
                let clamped = clampedEndIndex(tapped: index, start: start)
                endCueIndex = clamped
                if clamped != index { flashToast(.maxLengthExceeded) }
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

    /// Selects a chapter header's whole range in one tap: the full chapter when
    /// it's shorter than the cap, or just its first `maxClipLength` when it
    /// isn't. `lastCueIndex` alone isn't enough here — its walk only stops at the
    /// cap, not at the chapter's own end, so a short chapter would otherwise
    /// keep absorbing cues from the *next* chapter until it reached the cap too.
    private func selectChapterSection(_ section: TranscriptChapterSection) {
        guard let start = section.cueIndices.first, transcriptCues.indices.contains(start) else { return }
        let chapterEnd = section.cueIndices.upperBound - 1
        let limit = transcriptCues[start].startTime + WaveformView.maxClipLength
        let cappedEnd = lastCueIndex(endingBy: limit, notBefore: start)
        startCueIndex = start
        endCueIndex = min(cappedEnd, chapterEnd)
        // Only confirms when the *whole* chapter made it in — a capped, partial
        // selection doesn't get this toast, since it didn't actually fit.
        if cappedEnd >= chapterEnd {
            flashToast(.chapterFullySelected)
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
    ///
    /// Opened from a chapter, it instead covers the whole preselected range —
    /// `setInitialClipRange()` has already capped it — so the user lands on the
    /// chapter fully selected rather than on a single line.
    private func preselectInitialCue() {
        guard let index = transcriptCues.firstIndex(where: { $0.endTime > clipStart }) else { return }
        startCueIndex = index
        endCueIndex = initialChapterSelection == nil ? index : lastCueIndex(endingBy: clipEnd, notBefore: index)
    }

    /// Last cue that still ends within `limit`, never earlier than `start`.
    private func lastCueIndex(endingBy limit: TimeInterval, notBefore start: Int) -> Int {
        var index = start
        while index + 1 < transcriptCues.count, transcriptCues[index + 1].endTime <= limit {
            index += 1
        }
        return index
    }

    /// Opening from a chapter lands on the transcript tab — but only when
    /// `preselectInitialCue()` actually found something to select there. A
    /// chapter can legitimately fall outside the transcript (an outro past the
    /// last spoken line, a timing mismatch between the two sources); forcing the
    /// tab in that case would strand the user on an empty selection with
    /// "Próximo" disabled and no obvious reason why. The waveform tab, already
    /// positioned on the chapter by `setInitialClipRange()`, is the safe landing
    /// spot whenever the transcript side comes up empty.
    private func applyChapterTabOverride() {
        guard initialChapterSelection != nil, startCueIndex != nil, endCueIndex != nil else { return }
        selectionSourceOverride = .transcript
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
        VStack(spacing: .spacing(.xSmall)) {
            previewControlsRow

            if let hint = SocialVideoLimit.hint(for: max(activeClipEnd - activeClipStart, 0)) {
                HStack(spacing: .spacing(.xSmall)) {
                    Text(hint)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.2), value: hint)

                    Button {
                        showLimitsInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ver limites de cada rede")
                }
                .font(.footnote)
                .foregroundStyle(.gray)
            }
        }
    }

    private var previewControlsRow: some View {
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
                activeClipStart.asPlaybackTime,
                systemImage: "scissors"
            )

            Text("–")

            Text(activeClipEnd.asPlaybackTime)

            Text("·")

            Label(
                (max(activeClipEnd - activeClipStart, 0)).asPlaybackTime,
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

    /// Centers a 30-second window on the player's current position — or covers the
    /// chapter the user picked, when the sheet was opened from one.
    private func setInitialClipRange() {
        if let initialChapterSelection {
            clipStart = max(initialChapterSelection.start, 0)
            clipEnd = cappedChapterEnd(for: initialChapterSelection)
            previewCurrentTime = clipStart
            return
        }

        let initialLength = min(30, player.duration)
        let maxStart = max(player.duration - initialLength, 0)
        clipStart = min(max(player.currentTime - initialLength / 2, 0), maxStart)
        clipEnd = clipStart + initialLength
        previewCurrentTime = clipStart
    }

    /// A chapter shorter than the cap selects only itself; a longer one stops at
    /// the cap rather than spilling into the chapter that follows.
    private func cappedChapterEnd(for selection: InitialChapterSelection) -> TimeInterval {
        let cap = selection.start + WaveformView.maxClipLength
        let end = min(selection.end ?? cap, cap)
        return player.duration > 0 ? min(end, player.duration) : end
    }

    /// Whether the chapter itself — not just its transcript cues — fits entirely
    /// within the cap, i.e. the selection covers the whole chapter rather than
    /// just its first `maxClipLength`. A nil `end` means the chapter's true
    /// length was unknown at the trigger, so it's treated as not confirmed.
    private func chapterFullyFitsCap(_ selection: InitialChapterSelection) -> Bool {
        guard let end = selection.end else { return false }
        return end <= selection.start + WaveformView.maxClipLength
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
        rebuildChapterSections()
    }

    /// Loads this episode's chapters purely to label the transcript list. Honours
    /// the same preference as Now Playing, so someone who hid chapters doesn't
    /// get them back here.
    private func loadChapters() {
        guard ChapterPreferences.isEnabled else { return }
        let provider = ChapterProvider()
        provider.load(episodeId: episode.id)
        guard case .loaded(let loaded) = provider.state else { return }
        chapters = loaded
        rebuildChapterSections()
    }

    /// Anchors each chapter to the first cue that is still playing when the
    /// chapter starts, then slices the transcript at those points. Chapters
    /// landing on a cue already claimed by the previous one are skipped, so a
    /// section never ends up empty.
    private func rebuildChapterSections() {
        guard !chapters.isEmpty, !transcriptCues.isEmpty else {
            chapterSections = []
            return
        }

        var boundaries: [(index: Int, title: String)] = []
        var searchStart = 0

        for chapter in chapters {
            guard
                let index = transcriptCues[searchStart...].firstIndex(where: { $0.endTime > chapter.start })
            else { break }

            boundaries.append((index, chapter.title))
            searchStart = index + 1
        }

        guard !boundaries.isEmpty else {
            chapterSections = []
            return
        }

        var sections: [TranscriptChapterSection] = []

        // Lines before the first chapter starts get a titleless section rather
        // than being dropped from the list.
        if boundaries[0].index > 0 {
            sections.append(.init(id: 0, title: nil, cueIndices: 0..<boundaries[0].index))
        }

        for (offset, boundary) in boundaries.enumerated() {
            let end = offset + 1 < boundaries.count ? boundaries[offset + 1].index : transcriptCues.count
            sections.append(.init(id: boundary.index, title: boundary.title, cueIndices: boundary.index..<end))
        }

        chapterSections = sections
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
