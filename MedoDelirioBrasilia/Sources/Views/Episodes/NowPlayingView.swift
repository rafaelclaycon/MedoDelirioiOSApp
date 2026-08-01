//
//  NowPlayingView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import LinkPresentation
import SwiftUI
import Kingfisher

/// Full now-playing screen presented as a sheet from the bottom accessory.
struct NowPlayingView: View {

    /// Case order is load-bearing — the raw values are persisted in `@AppStorage`,
    /// so new modes go on the end. Display order is `displayedCanvasModes`.
    enum CanvasMode: Int {
        case coverArt, transcription, bookmarks, chapters

        var title: String {
            switch self {
            case .coverArt: "Capa"
            case .transcription: "Transcrição"
            case .bookmarks: "Marcadores"
            case .chapters: "Capítulos"
            }
        }
    }

    @Environment(EpisodePlayer.self) private var player
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService
    @Environment(EpisodeFavoritesStore.self) private var favoritesStore

    @State private var toast: Toast?
    @State private var editingBookmark: EpisodeBookmark?
    @State private var bookmarksSortAscending: Bool = true
    @State private var showShareClip: Bool = false
    @State private var showClipSupportSheet: Bool = false
    @State private var isPreparingShare: Bool = false
    @State private var shareLinkMetadata: LPLinkMetadata?
    @State private var showShareSheet: Bool = false
    @State private var transcriptProvider: TranscriptProvider
    @State private var hasSentTranscriptViewedAnalytics: Bool = false
    @State private var showFullTranscript: Bool = false
    @State private var chapterProvider = ChapterProvider()
    @AppStorage("nowPlayingCanvasMode") private var currentCanvasMode: CanvasMode = .coverArt
    /// Set from the chapter list's "Ocultar capítulos" action.
    @AppStorage(ChapterPreferences.hiddenKey) private var chaptersHidden: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.dismiss) private var dismiss

    init(transcriptProvider: TranscriptProvider = TranscriptProvider()) {
        _transcriptProvider = State(initialValue: transcriptProvider)
    }

    /// In compact vertical layouts (iPhone landscape) the bottom controls sit
    /// beside the canvas, so they fill the available width; otherwise they size
    /// to their content.
    private var bottomControlsMaxWidth: CGFloat? {
        vSizeClass == .compact ? .infinity : nil
    }

    /// Chapters are behind a feature flag and can also be switched off by the user
    /// from the chapter list. Both gates are checked in one place.
    private var chaptersEnabled: Bool {
        FeatureFlag.isEnabled(.episodeChapters) && !chaptersHidden
    }

    /// Falls back to cover art when the stored mode is no longer selectable —
    /// `@AppStorage` remembers the chapters canvas even after the flag is turned
    /// off or the user hides chapters.
    private var effectiveCanvasMode: CanvasMode {
        if currentCanvasMode == .chapters, !chaptersEnabled {
            return .coverArt
        }
        return currentCanvasMode
    }

    /// Modes offered in the picker, in the order they're shown.
    private var displayedCanvasModes: [CanvasMode] {
        var modes: [CanvasMode] = [.coverArt]
        if chaptersEnabled {
            modes.append(.chapters)
        }
        modes.append(contentsOf: [.transcription, .bookmarks])
        return modes
    }

    /// Canvases that lay out a list from the top rather than centring their content.
    private var canvasIsTopAligned: Bool {
        effectiveCanvasMode == .bookmarks || effectiveCanvasMode == .chapters
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: UIDevice.deviceType == .iPhone ? .spacing(.xxLarge) : 0)

                // Sits above the adaptive stack so it spans the full sheet width in
                // every layout, rather than riding along one column in landscape.
                toggleRow
                    .padding(.horizontal, .spacing(.xLarge))

                Spacer()
                    .frame(height: .spacing(.small))

                AdaptiveStack(spacing: 0) {
                    GeometryReader { geometry in
                        if effectiveCanvasMode == .coverArt {
                            content
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                content
                                    .frame(
                                        minHeight: geometry.size.height,
                                        alignment: canvasIsTopAligned ? .top : .center
                                    )
                            }
                            .scrollBounceBehavior(.basedOnSize)
                        }
                    }

                    bottomControls
                        .frame(maxWidth: bottomControlsMaxWidth)
                        .padding(.bottom, UIDevice.deviceType == .iPhone ? 0 : .spacing(.medium))
                        //.border(.red)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showFullTranscript) {
                TranscriptFullView(transcriptProvider: transcriptProvider)
                    .environment(player)
            }
            .toolbar {
                toolbarControls
            }
            // Observe `currentTime` in an isolated child so the toolbar's host view
            // doesn't re-evaluate on every playback tick (which made toolbar items
            // intermittently disappear/misalign).
            .background {
                PlaybackTimeObserver(player: player) { time in
                    // Chapters drive the control under the episode title, which is
                    // visible in every canvas mode — so this can't be gated on the
                    // mode the way the transcript is. It's a binary search that
                    // returns early unless a boundary was crossed.
                    if chaptersEnabled {
                        chapterProvider.update(currentTime: time)
                    }
                    if effectiveCanvasMode == .transcription {
                        transcriptProvider.update(currentTime: time)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .toast($toast)
        .sheet(item: $editingBookmark) { bookmark in
            BookmarkEditView(bookmark: bookmark)
                .environment(bookmarkStore)
        }
        .sheet(isPresented: $showShareSheet) {
            if let metadata = shareLinkMetadata {
                LinkMetadataShareSheet(metadata: metadata)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showShareClip) {
            if let episode = player.currentEpisode {
                ShareClipView(episode: episode) { includesTranscript in
                    showShareClip = false
                    toast = Toast(message: Shared.videoSharedSuccessfullyMessage, type: .success)
                    Task {
                        await AnalyticsService().send(
                            originatingScreen: "ShareClip",
                            action: "clip_shared(transcript=\(includesTranscript))"
                        )
                    }

                    // The user just experienced the app's value end to end —
                    // the moment to ask for support, capped by the shared cooldown.
                    if AppPersistentMemory.shared.shouldShowShareClipSupportPrompt() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            showClipSupportSheet = true
                        }
                    }
                }
                .environment(player)
            }
        }
        .sheet(isPresented: $showClipSupportSheet, onDismiss: {
            AppPersistentMemory.shared.setLastSupportPromptDate(Date())
        }) {
            StandaloneSupportView(context: .shareClip)
                .onAppear {
                    Task {
                        await AnalyticsService().send(
                            originatingScreen: "SupportPrompt",
                            action: "support_sheet_shown(trigger=share_clip)"
                        )
                    }
                }
        }
        .onAppear {
            if player.pendingRemoteBookmark {
                player.pendingRemoteBookmark = false
                toast = Toast(message: "Marcador Adicionado", type: .success)
            }
            if transcriptDownloadService.transcriptsDownloaded, case .idle = transcriptProvider.state {
                transcriptProvider.load(episodeId: player.currentEpisode?.id, pubDate: player.currentEpisode?.pubDate)
            }
            if chaptersEnabled, case .idle = chapterProvider.state {
                chapterProvider.load(episodeId: player.currentEpisode?.id)
                chapterProvider.update(currentTime: player.currentTime)
            }
        }
        .onChange(of: player.currentEpisode?.id) {
            if transcriptDownloadService.transcriptsDownloaded {
                transcriptProvider.load(episodeId: player.currentEpisode?.id, pubDate: player.currentEpisode?.pubDate)
            }
            if chaptersEnabled {
                chapterProvider.load(episodeId: player.currentEpisode?.id)
                chapterProvider.update(currentTime: player.currentTime)
            }
        }
        .onChange(of: transcriptDownloadService.transcriptsDownloaded) {
            if transcriptDownloadService.transcriptsDownloaded {
                transcriptProvider.load(episodeId: player.currentEpisode?.id, pubDate: player.currentEpisode?.pubDate)
            }
        }
        // A sync landing while this screen is open would otherwise go unnoticed
        // until the next episode change.
        .onReceive(NotificationCenter.default.publisher(for: ChapterDownloadService.chaptersDidUpdate)) { _ in
            guard chaptersEnabled else { return }
            chapterProvider.load(episodeId: player.currentEpisode?.id)
            chapterProvider.update(currentTime: player.currentTime)
        }
        .onChange(of: currentCanvasMode) {
            if currentCanvasMode == .chapters {
                chapterProvider.update(currentTime: player.currentTime)
            }
            if currentCanvasMode == .transcription {
                transcriptProvider.update(currentTime: player.currentTime)
                if !hasSentTranscriptViewedAnalytics {
                    hasSentTranscriptViewedAnalytics = true
                    Task { await AnalyticsService().send(originatingScreen: "NowPlaying", action: "transcript_viewed") }
                }
            }
        }
    }

    // MARK: - Layout

    private var content: some View {
        VStack(spacing: 0) {
            topContent
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, .spacing(.xLarge))
    }

    private var bottomControls: some View {
        VStack(spacing: 0) {
            // With chapters available the control stands in for the episode
            // title and date — the chapter name is the more useful label while
            // you're mid-episode.
            if chaptersEnabled, chapterProvider.hasChapters {
                ChapterControlView(
                    player: player,
                    chapterProvider: chapterProvider,
                    onTapTitle: { currentCanvasMode = .chapters }
                )
            } else {
                episodeInfo
            }

            Spacer()
                .frame(height: .spacing(.medium))

            ProgressScrubber(player: player, bookmarks: currentBookmarks)

            Spacer()
                .frame(height: .spacing(.small))

            playbackControls

            Spacer()
                .frame(height: .spacing(.medium))
        }
        .padding(.horizontal, .spacing(.xLarge))
    }

    // MARK: - Enhanced Layout Components

    @ViewBuilder
    private var topContent: some View {
        switch effectiveCanvasMode {
        case .coverArt:
            artwork
        case .transcription:
            transcriptContent
        case .bookmarks:
            bookmarksContent
        case .chapters:
            ChapterCanvas(
                chapterProvider: chapterProvider,
                onHideChapters: hideChapters,
                onReportIssue: reportChapterIssue
            )
            .environment(player)
        }
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if !transcriptDownloadService.transcriptsDownloaded {
            if case .downloading = transcriptDownloadService.state {
                TranscriptDownloadingView()
            } else {
                TranscriptDownloadPromptView(
                    icon: "text.quote",
                    title: "Acompanhe o que está sendo dito",
                    subtitle: "Baixe as transcrições para ler junto enquanto ouve. É rápido e usa poucos dados.",
                    priorityEpisodeId: player.currentEpisode?.id,
                    analyticsSource: "NowPlaying"
                )
                .frame(minHeight: 280, maxHeight: 400)
            }
        } else {
            switch transcriptProvider.state {
            case .idle:
                artwork
            case .notAvailable(let reason, let isComingSoon):
                TranscriptNotAvailableView(reason: reason, isComingSoon: isComingSoon)
            case .loaded:
                // Reads the live cues in its own view so the parent (and the toolbar)
                // isn't invalidated every tick as the highlighted cue advances.
                TranscriptLoadedOverlay(transcriptProvider: transcriptProvider)
            }
        }
    }

    @ViewBuilder
    private var bookmarksContent: some View {
        let bookmarks = sortedBookmarks
        if bookmarks.isEmpty {
            emptyBookmarksView
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Meus Marcadores")
                        .font(.headline)

                    Spacer()

                    Button {
                        bookmarksSortAscending.toggle()
                    } label: {
                        Image(systemName: bookmarksSortAscending ? "arrow.up" : "arrow.down")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.rubyRed)
                    }
                }
                .padding(.bottom, .spacing(.small))

                ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                    bookmarkRow(bookmark)

                    if index < bookmarks.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyBookmarksView: some View {
        VStack(spacing: .spacing(.small)) {
            Image(systemName: "bookmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("Nenhum marcador adicionado")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toggleRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: .spacing(.xSmall)) {
                ForEach(displayedCanvasModes, id: \.self) { mode in
                    canvasPill(mode)
                }
            }
            // Restores the screen inset the negative padding below strips off, so
            // pills sit correctly at rest but can scroll edge to edge.
            .padding(.horizontal, .spacing(.xLarge))
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .padding(.horizontal, -.spacing(.xLarge))
        .animation(.snappy(duration: 0.2), value: currentCanvasMode)
    }

    private func canvasPill(_ mode: CanvasMode) -> some View {
        let isSelected = effectiveCanvasMode == mode

        return Button {
            currentCanvasMode = mode
        } label: {
            Text(mode.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, .spacing(.medium))
                .padding(.vertical, .spacing(.xSmall))
                .background {
                    if isSelected {
                        Capsule().fill(.quaternary)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// A single, structurally-stable toolbar tree. The view's `body` re-evaluates
    /// on every playback tick (the scrubber observes `player.currentTime`), so this
    /// content is rebuilt ~twice a second. Explicit `id`s keep each item's identity
    /// stable across those rebuilds — without them the glass toolbar group can drop
    /// or misalign items when the labels change (star ⇄ star.fill, share enable/disable).
    @ToolbarContentBuilder
    private var toolbarControls: some ToolbarContent {
        // iPad/Mac present this full screen with no swipe-to-dismiss, so they
        // need an explicit close button. iPhone keeps the drag-to-dismiss sheet.
        if UIDevice.deviceType != .iPhone {
            ToolbarItem(id: "close", placement: .cancellationAction) {
                closeButton
            }
        }

        ToolbarItem(id: "bookmark", placement: .bottomBar) {
            Button {
                guard let episodeId = player.currentEpisode?.id else { return }
                bookmarkStore.addBookmark(episodeId: episodeId, timestamp: player.currentTime)
                toast = Toast(message: "Marcador Adicionado", type: .success)
            } label: {
                Image(systemName: "bookmark")
            }
        }

        ToolbarItem(id: "shareClip", placement: .bottomBar) {
            Button {
                if player.isPlaying {
                    player.togglePlayPause()
                }
                showShareClip = true
                Task { await AnalyticsService().send(originatingScreen: "NowPlaying", action: "didTapShareClip") }
            } label: {
                Image(systemName: "scissors")
            }
        }

        ToolbarItem(id: "favorite", placement: .bottomBar) {
            favoriteButton
        }

        ToolbarItem(id: "share", placement: .bottomBar) {
            shareButton
        }

        if FeatureFlag.isEnabled(.transcriptFullView) {
            ToolbarItem(id: "transcript", placement: .bottomBar) {
                transcriptButton
            }
        }
    }

    // MARK: - Chapter Actions

    private func hideChapters() {
        chaptersHidden = true
        currentCanvasMode = .coverArt
        toast = Toast(message: "Capítulos ocultados. Reative nos Ajustes.", type: .success)
        Task {
            await AnalyticsService().send(originatingScreen: "NowPlaying", action: "chapters_hidden")
        }
    }

    private func reportChapterIssue() {
        let episodeTitle = player.currentEpisode?.title ?? "(episódio desconhecido)"
        Task {
            await Mailman.openDefaultEmailApp(
                subject: Shared.Email.ChapterIssue.subject,
                body: String(format: Shared.Email.ChapterIssue.body, episodeTitle)
            )
            await AnalyticsService().send(originatingScreen: "NowPlaying", action: "chapter_issue_reported")
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
        }
    }

    private var favoriteButton: some View {
        let isFav = player.currentEpisode.map { favoritesStore.isFavorite($0.id) } ?? false
        return Button {
            guard let episodeId = player.currentEpisode?.id else { return }
            favoritesStore.toggle(episodeId)
        } label: {
            Image(systemName: isFav ? "star.fill" : "star")
                .foregroundStyle(isFav ? .yellow : .primary)
        }
    }

    private var shareButton: some View {
        Button {
            prepareShare()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(isPreparingShare)
    }

    private var transcriptButton: some View {
        Button {
            showFullTranscript = true
        } label: {
            Image(systemName: "magnifyingglass")
        }
    }

    private var actionButtons: some View {
        HStack(spacing: .spacing(.medium)) {
            GlassButton(
                symbol: "bookmark.fill",
                title: "Marcar",
                color: .rubyRed,
                lightModeLabelColor: .rubyRed,
                action: {
                    guard let episodeId = player.currentEpisode?.id else { return }
                    bookmarkStore.addBookmark(episodeId: episodeId, timestamp: player.currentTime)
                    toast = Toast(message: "Marcador Adicionado", type: .success)
                }
            )

            GlassButton(
                symbol: "scissors",
                title: hSizeClass == .compact ? "Compart. Trecho" : "Compartilhar Trecho",
                color: .orange,
                action: {
                    if player.isPlaying {
                        player.togglePlayPause()
                    }
                    showShareClip = true
                    Task { await AnalyticsService().send(originatingScreen: "NowPlaying", action: "didTapShareClip") }
                }
            )
        }
        .padding(.bottom, UIDevice.deviceType == .mac ? .spacing(.medium) : .zero)
    }

    // MARK: - Artwork

    private var artwork: some View {
        KFImage(player.currentEpisode?.imageURL)
            .placeholder {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onFailure { _ in }
            .resizable()
            .aspectRatio(contentMode: .fit)
        .frame(maxWidth: 300, maxHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: player.isPlaying
                ? (colorScheme == .dark ? .green.opacity(0.4) : .black.opacity(0.25))
                : .clear,
            radius: colorScheme == .dark ? 16 : 8,
            y: colorScheme == .dark ? 0 : 4
        )
        .scaleEffect(player.isPlaying ? 1.0 : 0.88)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: player.isPlaying)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: "radio")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Episode Info

    private var episodeInfo: some View {
        VStack(spacing: .spacing(.xxSmall)) {
            Text(player.currentEpisode?.title ?? "")
                .font(.title2)
                .fontDesign(.serif)
                .fontWeight(.semibold)
                .marquee(spacing: 40, delay: 2, speedBasis: .velocity(40), fadeWidth: 16, centersWhenFitting: true)

            if let pubDate = player.currentEpisode?.pubDate {
                Text(pubDate, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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
                        .font(.title)
                        .fontWeight(.medium)
                        .padding(.all, .spacing(.small))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 74))
                        .contentTransition(.symbolEffect(.replace.wholeSymbol))
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.skipForward()
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .fontWeight(.medium)
                        .padding(.all, .spacing(.small))
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

    // MARK: - Speed Control

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
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .padding(.vertical, .spacing(.xSmall))
                .padding(.trailing, .spacing(.medium))
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Bookmark List

    private var currentBookmarks: [EpisodeBookmark] {
        guard let episodeId = player.currentEpisode?.id else { return [] }
        return bookmarkStore.bookmarks(for: episodeId)
    }

    private var sortedBookmarks: [EpisodeBookmark] {
        let bookmarks = currentBookmarks
        return bookmarksSortAscending
            ? bookmarks.sorted { $0.timestamp < $1.timestamp }
            : bookmarks.sorted { $0.timestamp > $1.timestamp }
    }

    @ViewBuilder
    private var bookmarkList: some View {
        let bookmarks = sortedBookmarks
        if !bookmarks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Meus Marcadores")
                        .font(.headline)

                    Spacer()

                    Button {
                        bookmarksSortAscending.toggle()
                    } label: {
                        Image(systemName: bookmarksSortAscending ? "arrow.up" : "arrow.down")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.rubyRed)
                    }
                }
                .padding(.bottom, .spacing(.small))

                ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                    bookmarkRow(bookmark)

                    if index < bookmarks.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.bottom, .spacing(.xLarge))
        }
    }

    private func bookmarkRow(_ bookmark: EpisodeBookmark) -> some View {
        HStack(spacing: .spacing(.small)) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(Color.rubyRed)
                .font(.body)

            Text(bookmark.formattedTimestamp)
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(Color.rubyRed)

            Text(bookmark.title ?? "Sem título")
                .font(.body)
                .foregroundStyle(bookmark.title != nil ? .primary : .secondary)
                .lineLimit(1)

            Spacer()

            Button {
                player.seek(to: bookmark.timestamp)
            } label: {
                Image(systemName: "play.fill")
                    .font(.body)
                    .foregroundStyle(Color.rubyRed)
                    .padding(.spacing(.xxxSmall))
            }
            .if_iOS26GlassElsePlain()
        }
        .padding(.vertical, .spacing(.small))
        .contentShape(Rectangle())
        .onTapGesture {
            editingBookmark = bookmark
        }
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    bookmarkStore.delete(id: bookmark.id, episodeId: bookmark.episodeId)
                }
            } label: {
                Label("Excluir", systemImage: "trash")
            }
        }
    }

    // MARK: - Share

    private func prepareShare() {
        guard !isPreparingShare, let episode = player.currentEpisode else { return }
        guard let shareURL = URL(string: APIConfig.baseLinkURL + "episodio/\(episode.id)") else { return }
        isPreparingShare = true
        Task { await AnalyticsService().send(originatingScreen: "NowPlaying", action: "didTapShare(\(episode.id))") }

        Task {
            let meta = LPLinkMetadata()
            meta.url = shareURL
            meta.title = episode.title

            if let imageURL = episode.imageURL,
               let (data, _) = try? await URLSession.shared.data(from: imageURL),
               let image = UIImage(data: data) {
                meta.imageProvider = NSItemProvider(object: image)
            }

            shareLinkMetadata = meta
            isPreparingShare = false
            showShareSheet = true
        }
    }

    // MARK: - Helpers

    /// Formats a `TimeInterval` to `M:SS` or `H:MM:SS`.
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

// MARK: - Isolated, Time-Driven Subviews

/// The scrubber and elapsed/remaining time labels. Owns its scrubbing gesture state
/// and reads `player.currentTime` itself, so the parent `NowPlayingView` body — which
/// hosts the navigation toolbar — isn't re-evaluated on every playback tick.
private struct ProgressScrubber: View {

    let player: EpisodePlayer
    let bookmarks: [EpisodeBookmark]

    @State private var isScrubbing: Bool = false
    @State private var scrubValue: TimeInterval = 0

    private static let trackHeight: CGFloat = 4
    private static let thumbSize: CGFloat = 14
    private static let trackColor = Color.darkerGreen
    private static let trackBgColor = Color(.systemGray4)

    var body: some View {
        VStack(spacing: .spacing(.xxxSmall)) {
            scrubber

            HStack {
                Text(NowPlayingView.formatTime(isScrubbing ? scrubValue : player.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text("-" + NowPlayingView.formatTime(player.duration - (isScrubbing ? scrubValue : player.currentTime)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var scrubber: some View {
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

                ForEach(bookmarks) { bookmark in
                    let bFraction = bookmark.timestamp / totalDuration
                    let bX = geometry.size.width * bFraction

                    Capsule()
                        .fill(Color.rubyRed)
                        .frame(width: 3, height: Self.trackHeight + 12)
                        .offset(x: bX - 1.5)
                }

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
}

/// An invisible view that observes `player.currentTime` and forwards each change to
/// `onTick`. Keeping this read out of the parent body prevents the toolbar host from
/// invalidating every playback tick.
private struct PlaybackTimeObserver: View {

    let player: EpisodePlayer
    let onTick: (TimeInterval) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: player.currentTime) { _, newValue in
                onTick(newValue)
            }
    }
}

/// The live transcript overlay. Reads the advancing cues in its own view so the
/// parent body (and the toolbar) isn't invalidated as the highlighted cue moves.
private struct TranscriptLoadedOverlay: View {

    let transcriptProvider: TranscriptProvider

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
            TranscriptOverlayView(
                previousCue: transcriptProvider.previousCue,
                currentCue: transcriptProvider.currentCue,
                nextCue: transcriptProvider.nextCue
            )

            Text("Transcrição gerada por IA. Pode conter erros.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Liquid Glass Helper

private extension View {

    @ViewBuilder
    func if_iOS26GlassElsePlain() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    struct SheetHost: View {
        @State private var isPresented = true

        let player: EpisodePlayer = {
            let p = EpisodePlayer()
            p.currentEpisode = .mockRecent
            p.duration = PodcastEpisode.mockRecent.duration ?? 3945
            p.currentTime = 620
            return p
        }()

        var body: some View {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    NowPlayingView()
                        .environment(player)
                        .environment(EpisodeBookmarkStore())
                }
        }
    }

    return SheetHost()
}

#Preview("With Transcript") {
    struct SheetHost: View {
        @State private var isPresented = true

        let player: EpisodePlayer = {
            let p = EpisodePlayer()
            p.currentEpisode = .mockRecent
            p.duration = PodcastEpisode.mockRecent.duration ?? 3945
            p.currentTime = 620
            return p
        }()

        static let previewDefaults: UserDefaults = {
            let defaults = UserDefaults(suiteName: "NowPlayingTranscriptPreview")!
            defaults.set(true, forKey: "showTranscript")
            return defaults
        }()

        var body: some View {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    NowPlayingView(transcriptProvider: .mockLoaded())
                        .environment(player)
                        .environment(EpisodeBookmarkStore())
                        .defaultAppStorage(Self.previewDefaults)
                }
        }
    }

    return SheetHost()
}

#Preview("Transcript – Long Lines") {
    struct SheetHost: View {
        @State private var isPresented = true

        let player: EpisodePlayer = {
            let p = EpisodePlayer()
            p.currentEpisode = .mockRecent
            p.duration = PodcastEpisode.mockRecent.duration ?? 3945
            p.currentTime = 620
            return p
        }()

        static let previewDefaults: UserDefaults = {
            let defaults = UserDefaults(suiteName: "NowPlayingLongLinesPreview")!
            defaults.set(true, forKey: "showTranscript")
            return defaults
        }()

        var body: some View {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    NowPlayingView(transcriptProvider: .mockLoadedLongLines())
                        .environment(player)
                        .environment(EpisodeBookmarkStore())
                        .defaultAppStorage(Self.previewDefaults)
                }
        }
    }

    return SheetHost()
}
