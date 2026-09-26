//
//  NowPlayingView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import LinkPresentation
import SwiftUI

/// Full now-playing screen presented as a sheet from the bottom accessory.
///
/// This type is the shell: it owns the sheet/toast state, the canvas picker, and
/// the provider lifecycle. The screen's actual content lives in siblings —
/// `NowPlaying*Canvas` for the switchable upper half, `NowPlayingBottomControls`
/// for the fixed lower half, and `NowPlayingActions` for the bar buttons.
struct NowPlayingView: View {

    /// Case order is load-bearing — the raw values are persisted in `@AppStorage`,
    /// so new modes go on the end. Display order is `displayedCanvasModes`.
    enum CanvasMode: Int {
        case coverArt, transcription, bookmarks, chapters, details

        var title: String {
            switch self {
            case .coverArt: "Capa"
            case .transcription: "Transcrição"
            case .bookmarks: "Marcadores"
            case .chapters: "Capítulos"
            case .details: "Detalhes"
            }
        }
    }

    @Environment(EpisodePlayer.self) private var player
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService

    @State private var toast: Toast?
    /// Where the current toast came from, so the split layout can show it on that side of
    /// the crease instead of across it.
    @State private var toastOrigin: ToastOrigin = .toolbar
    /// The edge the system put the toolbar on as a vertical bar, or nil while it's
    /// horizontal. Decides which split pane the toolbar's toasts land in.
    @State private var toolbarVerticalEdge: HorizontalEdge?
    @State private var editingBookmark: EpisodeBookmark?
    /// Held here rather than in `NowPlayingBookmarksCanvas` so it survives the
    /// canvas being rebuilt when the user switches tabs.
    @State private var bookmarksSortAscending: Bool = true
    /// Drives the clip sheet. `Identifiable` via a fresh `UUID` per presentation so
    /// `.sheet(item:)` always builds `ShareClipView` from this exact payload —
    /// tying the chapter selection to the trigger atomically avoids the sheet
    /// ever picking up a stale/missing selection from a preceding presentation.
    @State private var shareClipPresentation: ShareClipPresentation?
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
    /// Dev option (see `ShareClipConfirmView`): simulated shares skip the analytics event.
    @AppStorage("devMockShareClipGeneration") private var mockShareClipGeneration: Bool = false
    /// A display crease runs vertically through the screen (unfolded iPhone Duo in
    /// landscape): the cover and transport get the pane on one side of it, the tabs the other.
    @State private var isSplitLayout: Bool = false

    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.dismiss) private var dismiss

    /// Whether the presenter chose a full-screen cover over a sheet. Passed in rather
    /// than inferred, so the chrome below always matches how this was actually presented.
    private let isFullScreen: Bool

    init(isFullScreen: Bool = false, transcriptProvider: TranscriptProvider = TranscriptProvider()) {
        self.isFullScreen = isFullScreen
        _transcriptProvider = State(initialValue: transcriptProvider)
    }

    /// In compact vertical layouts (iPhone landscape, folded iPhone Duo) the bottom
    /// controls sit beside the canvas at a fixed width that fits the transport row, so the
    /// canvas — chapter titles, transcript lines — gets the rest instead of half the
    /// screen. Otherwise they span the sheet below the canvas.
    private var bottomControlsWidth: CGFloat? {
        vSizeClass == .compact ? Self.landscapeControlsWidth : nil
    }

    /// Room for the speed button beside the tightest transport row in
    /// `NowPlayingBottomControls`, plus its horizontal padding.
    private static let landscapeControlsWidth: CGFloat = 320

    /// Chapters can be switched off by the user from the chapter list.
    private var chaptersEnabled: Bool {
        !chaptersHidden
    }

    /// How long to wait between rechecks for a transcript still being generated.
    /// Generation takes hours, so this is about not making the user reopen the screen
    /// rather than about catching the file the second it appears.
    private static let transcriptRecheckInterval: TimeInterval = 5 * 60

    /// The episode whose transcript is worth waiting for, or nil when there's nothing to
    /// wait on. `isComingSoon` is already the provider's answer to "recent enough that
    /// generation is plausibly still pending", which also bounds how long this can run.
    private var awaitedTranscriptEpisodeId: String? {
        guard transcriptDownloadService.transcriptsDownloaded else { return nil }
        guard case .notAvailable(_, let isComingSoon) = transcriptProvider.state, isComingSoon else {
            return nil
        }
        return player.currentEpisode?.id
    }

    /// Falls back when the stored mode is no longer selectable — `@AppStorage` remembers
    /// the chapters canvas even after the user hides chapters, and the split layout shows
    /// the cover in its own pane, so its canvas pane starts on the first tab instead. The
    /// stored mode is left alone, so folding back returns to it.
    private var effectiveCanvasMode: CanvasMode {
        var mode = currentCanvasMode
        if mode == .chapters, !chaptersEnabled {
            mode = .coverArt
        }
        if mode == .coverArt, isSplitLayout {
            mode = displayedCanvasModes.first ?? .transcription
        }
        return mode
    }

    /// Modes offered in the picker, in the order they're shown. Capa is left out of the
    /// split layout, where the cover is always on screen.
    private var displayedCanvasModes: [CanvasMode] {
        var modes: [CanvasMode] = isSplitLayout ? [] : [.coverArt]
        if chaptersEnabled {
            modes.append(.chapters)
        }
        modes.append(contentsOf: [.transcription, .bookmarks, .details])
        return modes
    }

    /// Canvases that lay out a list from the top rather than centring their content.
    private var canvasIsTopAligned: Bool {
        effectiveCanvasMode == .bookmarks || effectiveCanvasMode == .chapters || effectiveCanvasMode == .details
    }

    var body: some View {
        NavigationStack {
            layout
                .onVerticalCreaseChange { isSplitLayout = $0 }
                .onToolbarVerticalEdgeChange { toolbarVerticalEdge = $0 }
                .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showFullTranscript) {
                TranscriptFullView(transcriptProvider: transcriptProvider)
                    .environment(player)
            }
            // The toast is attached inside `layout` (per pane in the split layout), which
            // keeps it before `.toolbar`: its safe-area inset is established inside the
            // content the bottom-bar toolbar already makes room for — otherwise the toast
            // overlaps the bottom bar.
            .toolbar {
                toolbarControls
            }
            // iOS 18's native `.bottomBar` renders plain and accent-tinted;
            // `NowPlayingLegacyBottomBar` replaces it there. Attached after
            // `.toolbar` (which is a no-op bottom bar-wise pre-26, see
            // `toolbarControls`) so it reserves the same bottom space a native
            // bar would, and `.toast` above stays nested above it.
            .safeAreaInset(edge: .bottom) {
                if !UIDevice.isIOS26OrLater {
                    NowPlayingLegacyBottomBar(
                        isPreparingShare: isPreparingShare,
                        onAddBookmark: addBookmark,
                        onShareClip: startShareClip,
                        onShare: prepareShare,
                        onOpenTranscript: { showFullTranscript = true }
                    )
                }
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
        .sheet(item: $shareClipPresentation) { presentation in
            if let episode = player.currentEpisode {
                ShareClipView(episode: episode, initialChapterSelection: presentation.chapterSelection) { includesTranscript in
                    shareClipPresentation = nil
                    showToast(Toast(message: Shared.videoSharedSuccessfullyMessage, type: .success), from: presentation.toastOrigin)
                    if !mockShareClipGeneration {
                        Task {
                            await AnalyticsService().send(
                                originatingScreen: "ShareClip",
                                action: "clip_shared(transcript=\(includesTranscript))"
                            )
                        }
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
                // No button started this one (it came from the lock screen); it shows
                // beside the bookmark button, like the ones that did.
                showToast(Toast(message: "Marcador Adicionado", type: .success), from: .toolbar)
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
        .onReceive(NotificationCenter.default.publisher(for: TranscriptDownloadService.transcriptsDidUpdate)) { _ in
            guard transcriptDownloadService.transcriptsDownloaded else { return }
            // A sync usually brings in *other* episodes' files, which can't change one
            // that's already parsed — and reparsing re-reads the SRT and rebuilds every
            // cue, tens of milliseconds on a long episode. Only reload when there's
            // actually something to gain.
            if case .loaded = transcriptProvider.state { return }
            transcriptProvider.load(episodeId: player.currentEpisode?.id, pubDate: player.currentEpisode?.pubDate)
            transcriptProvider.update(currentTime: player.currentTime)
        }
        // Rechecks while the "a caminho" notice is on screen, so a transcript finishing
        // generation mid-episode appears without the user having to leave and come back.
        .task(id: awaitedTranscriptEpisodeId) {
            guard let episodeId = awaitedTranscriptEpisodeId else { return }

            while !Task.isCancelled {
                // Checked before the first wait, not after: what the provider read was the
                // local folder, last filled at launch — possibly before this episode's
                // transcript existed. It also makes closing and reopening this screen a
                // way to ask again, rather than a way to restart the wait.
                //
                // A hit posts `transcriptsDidUpdate`, which the observer above turns into
                // a reload — that flips the state off `.notAvailable` and cancels this.
                if await transcriptDownloadService.fetchTranscriptIfReady(episodeId: episodeId) {
                    return
                }

                try? await Task.sleep(for: .seconds(Self.transcriptRecheckInterval))
            }
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

    @ViewBuilder
    private var layout: some View {
        // `ArrangementView` is an iOS 27.1 SDK symbol, so it only compiles with the Xcode
        // that bundles that SDK (same guard as `MainView`). `isSplitLayout` is never true
        // before 27.1 anyway, since the crease can't be read there.
        #if compiler(>=6.4)
        if isSplitLayout, #available(iOS 27.1, *) {
            splitLayout
        } else {
            standardLayout
        }
        #else
        standardLayout
        #endif
    }

    /// Tabs across the top, then the canvas and the controls — stacked, or side by side
    /// in compact vertical layouts (iPhone landscape).
    private var standardLayout: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: !isFullScreen ? .spacing(.xxLarge) : 0)

            // Sits above the adaptive stack so it spans the full sheet width in
            // every layout, rather than riding along one column in landscape.
            toggleRow
                .padding(.horizontal, .spacing(.xLarge))

            Spacer()
                .frame(height: .spacing(.small))

            AdaptiveStack(spacing: 0) {
                canvasArea

                bottomControls(width: bottomControlsWidth)
            }
        }
        .toast($toast)
    }

    #if compiler(>=6.4)
    /// Unfolded iPhone Duo in landscape: the cover with the transport under it on one side
    /// of the crease, the tabs and their canvas on the other. `.split` puts the divider on
    /// the crease, so nothing here has to know where it is.
    @available(iOS 27.1, *)
    private var splitLayout: some View {
        ArrangementView {
            VStack(spacing: 0) {
                NowPlayingArtworkCanvas()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, .spacing(.xLarge))

                bottomControls(width: nil)
            }
            .toast(toastBinding(for: .primary))
        } secondary: {
            VStack(spacing: 0) {
                toggleRow
                    .padding(.horizontal, .spacing(.xLarge))

                Spacer()
                    .frame(height: .spacing(.small))

                canvasArea
            }
            .toast(toastBinding(for: .secondary))
        }
        .arrangementViewStyle(.split)
    }
    #endif

    // MARK: - Toast

    /// Where a toast came from. In the split layout it shows in the pane on that side of
    /// the crease; elsewhere there's one pane and it doesn't matter.
    enum ToastOrigin {
        /// The action bar (bookmark, clip). Its side is wherever the system put the bar.
        case toolbar
        /// The tabbed canvas (chapter menu), which the split layout keeps on the trailing side.
        case canvas
    }

    private enum SplitPane {
        case primary, secondary
    }

    private var toastPane: SplitPane {
        switch toastOrigin {
        case .canvas:
            .secondary
        case .toolbar:
            // A horizontal bar (nil) spans the bottom of both panes; the trailing pane
            // reads as its end, like the vertical bar's usual edge.
            toolbarVerticalEdge == .leading ? .primary : .secondary
        }
    }

    private func showToast(_ newToast: Toast, from origin: ToastOrigin) {
        toastOrigin = origin
        toast = newToast
    }

    /// The shared toast, visible only to the pane it belongs in. Clearing it from either
    /// pane clears it for good.
    private func toastBinding(for pane: SplitPane) -> Binding<Toast?> {
        Binding(
            get: { toastPane == pane ? toast : nil },
            set: { toast = $0 }
        )
    }

    private var canvasArea: some View {
        GeometryReader { geometry in
            if effectiveCanvasMode == .coverArt {
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    canvas
                        .frame(
                            minHeight: geometry.size.height,
                            alignment: canvasIsTopAligned ? .top : .center
                        )
                }
                // Without this, switching canvases reuses the same
                // ScrollView instance and keeps whatever offset the
                // previous canvas (e.g. a long-scrolled Capítulos
                // list) was left at, instead of starting at the top.
                .id(effectiveCanvasMode)
                .scrollBounceBehavior(.basedOnSize)
                // Lets rows use `.swipeActions` outside a `List` (Marcadores).
                .if_swipeActionsContainer()
            }
        }
    }

    private func bottomControls(width: CGFloat?) -> some View {
        NowPlayingBottomControls(
            chapterProvider: chapterProvider,
            chaptersEnabled: chaptersEnabled,
            onTapChapterTitle: { currentCanvasMode = .chapters }
        )
        .frame(width: width)
        .padding(.bottom, !isFullScreen ? 0 : .spacing(.medium))
    }

    // MARK: - Canvas

    @ViewBuilder
    private var canvas: some View {
        Group {
            switch effectiveCanvasMode {
            case .coverArt:
                NowPlayingArtworkCanvas()
            case .transcription:
                NowPlayingTranscriptCanvas(transcriptProvider: transcriptProvider)
            case .bookmarks:
                NowPlayingBookmarksCanvas(
                    sortAscending: $bookmarksSortAscending,
                    onEdit: { editingBookmark = $0 }
                )
            case .details:
                NowPlayingDetailsCanvas()
            case .chapters:
                ChapterCanvas(
                    chapterProvider: chapterProvider,
                    onHideChapters: hideChapters,
                    onReportIssue: reportChapterIssue,
                    onShareChapterClip: shareChapterClip
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .spacing(.xLarge))
    }

    // MARK: - Canvas Picker

    private var toggleRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: .spacing(.xSmall)) {
                    ForEach(displayedCanvasModes, id: \.self) { mode in
                        canvasPill(mode)
                            .id(mode)
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
            .onAppear {
                // The persisted mode (e.g. Detalhes, scrolled off-screen) needs
                // to be brought into view on first appearance — without a delay
                // this runs before the ScrollView has its content laid out and
                // silently does nothing.
                DispatchQueue.main.async {
                    proxy.scrollTo(effectiveCanvasMode, anchor: .center)
                }
            }
        }
    }

    private func canvasPill(_ mode: CanvasMode) -> some View {
        EpisodePillTab(title: mode.title, isSelected: effectiveCanvasMode == mode) {
            currentCanvasMode = mode
        }
    }

    // MARK: - Toolbar

    /// A single, structurally-stable toolbar tree. The view's `body` re-evaluates
    /// on every playback tick (the scrubber observes `player.currentTime`), so this
    /// content is rebuilt ~twice a second. Explicit `id`s keep each item's identity
    /// stable across those rebuilds — without them the glass toolbar group can drop
    /// or misalign items when the labels change (star ⇄ star.fill, share enable/disable).
    @ToolbarContentBuilder
    private var toolbarControls: some ToolbarContent {
        // Full screen has no swipe-to-dismiss, so it needs an explicit close button.
        // The sheet keeps drag-to-dismiss.
        if isFullScreen {
            ToolbarItem(id: "close", placement: .cancellationAction) {
                NowPlayingActions.Close(onClose: { dismiss() })
            }
        }

        // iOS 26 gets the native Liquid Glass bottom bar; iOS 18 renders
        // `NowPlayingLegacyBottomBar` instead, since the plain, tinted pre-26
        // `.bottomBar` chrome doesn't fit the rest of the screen.
        if UIDevice.isIOS26OrLater {
            ToolbarItem(id: "bookmark", placement: .bottomBar) {
                NowPlayingActions.Bookmark(onAdd: addBookmark)
            }

            ToolbarItem(id: "shareClip", placement: .bottomBar) {
                NowPlayingActions.ShareClip(onShare: startShareClip)
            }

            ToolbarItem(id: "favorite", placement: .bottomBar) {
                NowPlayingActions.Favorite()
            }

            ToolbarItem(id: "share", placement: .bottomBar) {
                NowPlayingActions.Share(isPreparing: isPreparingShare, onShare: prepareShare)
            }

            if FeatureFlag.isEnabled(.transcriptFullView) {
                ToolbarItem(id: "transcript", placement: .bottomBar) {
                    NowPlayingActions.Transcript(onOpen: { showFullTranscript = true })
                }
            }
        }
    }

    // MARK: - Actions

    private func addBookmark() {
        guard let episodeId = player.currentEpisode?.id else { return }
        bookmarkStore.addBookmark(episodeId: episodeId, timestamp: player.currentTime)
        showToast(Toast(message: "Marcador Adicionado", type: .success), from: .toolbar)
    }

    private func startShareClip() {
        if player.isPlaying {
            player.togglePlayPause()
        }
        shareClipPresentation = .init(chapterSelection: nil, toastOrigin: .toolbar)
        Task { await AnalyticsService().send(originatingScreen: "NowPlaying", action: "didTapShareClip") }
    }

    /// Opens the clip sheet already covering `chapter`, from its long-press menu.
    private func shareChapterClip(_ chapter: EpisodeChapter, end: TimeInterval?) {
        if player.isPlaying {
            player.togglePlayPause()
        }
        shareClipPresentation = .init(chapterSelection: .init(start: chapter.start, end: end), toastOrigin: .canvas)
        Task {
            await AnalyticsService().send(
                originatingScreen: "NowPlaying",
                action: "didTapShareChapterClip(\(chapter.id), \(chapter.title))"
            )
        }
    }

    private func hideChapters() {
        chaptersHidden = true
        currentCanvasMode = .coverArt
        showToast(Toast(message: "Capítulos ocultados. Reative nos Ajustes.", type: .success), from: .canvas)
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
}

// MARK: - Share Clip Presentation

/// What to open the clip sheet with. A fresh `id` per presentation is what makes
/// `.sheet(item:)` treat each one as a distinct, atomically-delivered payload.
private struct ShareClipPresentation: Identifiable {
    let id = UUID()
    let chapterSelection: ShareClipView.InitialChapterSelection?
    /// The toolbar's clip button or a chapter's menu in the canvas — where the success
    /// toast shows in the split layout.
    let toastOrigin: NowPlayingView.ToastOrigin
}

// MARK: - Playback Time Observer

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


// MARK: - Pill Tab

/// One tab of the pill selector shared by Now Playing and the split episode detail.
struct EpisodePillTab: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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
}
