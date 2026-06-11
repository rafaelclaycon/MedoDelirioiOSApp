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

    enum CanvasMode: Int {
        case coverArt, transcription, bookmarks
    }

    @Environment(EpisodePlayer.self) private var player
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore
    @Environment(TranscriptDownloadService.self) private var transcriptDownloadService
    @Environment(EpisodeFavoritesStore.self) private var favoritesStore

    @State private var isScrubbing: Bool = false
    @State private var scrubValue: TimeInterval = 0
    @State private var toast: Toast?
    @State private var editingBookmark: EpisodeBookmark?
    @State private var bookmarksSortAscending: Bool = true
    @State private var showSidecastClip: Bool = false
    @State private var isPreparingShare: Bool = false
    @State private var shareLinkMetadata: LPLinkMetadata?
    @State private var showShareSheet: Bool = false
    @State private var transcriptProvider: TranscriptProvider
    @State private var hasSentTranscriptViewedAnalytics: Bool = false
    @State private var showFullTranscript: Bool = false
    @AppStorage("nowPlayingCanvasMode") private var currentCanvasMode: CanvasMode = .coverArt

    @Environment(\.colorScheme) private var colorScheme

    init(transcriptProvider: TranscriptProvider = TranscriptProvider()) {
        _transcriptProvider = State(initialValue: transcriptProvider)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    if currentCanvasMode == .coverArt {
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            content
                                .frame(
                                    minHeight: geometry.size.height,
                                    alignment: currentCanvasMode == .bookmarks ? .top : .center
                                )
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }

                bottomControls
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
        }
        .presentationDragIndicator(.visible)
        .topToast($toast)
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
        .sheet(isPresented: $showSidecastClip) {
            if let episode = player.currentEpisode {
                SidecastClipView(episode: episode)
                    .environment(player)
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
        }
        .onChange(of: player.currentEpisode?.id) {
            if transcriptDownloadService.transcriptsDownloaded {
                transcriptProvider.load(episodeId: player.currentEpisode?.id, pubDate: player.currentEpisode?.pubDate)
            }
        }
        .onChange(of: transcriptDownloadService.transcriptsDownloaded) {
            if transcriptDownloadService.transcriptsDownloaded {
                transcriptProvider.load(episodeId: player.currentEpisode?.id, pubDate: player.currentEpisode?.pubDate)
            }
        }
        .onChange(of: player.currentTime) {
            if currentCanvasMode == .transcription {
                transcriptProvider.update(currentTime: player.currentTime)
            }
        }
        .onChange(of: currentCanvasMode) {
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
            toggleRow
                .padding(.vertical, .spacing(.xLarge))

            episodeInfo

            Spacer()
                .frame(height: .spacing(.medium))

            progressSection

            Spacer()
                .frame(height: .spacing(.small))

            playbackControls

            Spacer()
                .frame(height: .spacing(.xxLarge))

            actionButtons
        }
        .padding(.horizontal, .spacing(.xLarge))
    }

    // MARK: - Enhanced Layout Components

    @ViewBuilder
    private var topContent: some View {
        switch currentCanvasMode {
        case .coverArt:
            artwork
        case .transcription:
            transcriptContent
        case .bookmarks:
            bookmarksContent
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
        Picker("Modo", selection: $currentCanvasMode) {
            Label("Capa", systemImage: "square")
                .tag(CanvasMode.coverArt)
            Label("Transcrição", systemImage: "text.quote")
                .tag(CanvasMode.transcription)
            Label("Marcadores", systemImage: "bookmark")
                .tag(CanvasMode.bookmarks)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 400)
    }

    @ToolbarContentBuilder
    private var toolbarControls: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .primaryAction) {
                let isFav = player.currentEpisode.map { favoritesStore.isFavorite($0.id) } ?? false
                Button {
                    guard let episodeId = player.currentEpisode?.id else { return }
                    favoritesStore.toggle(episodeId)
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .foregroundStyle(isFav ? .yellow : .primary)
                }
            }

            ToolbarSpacer(.fixed)

            ToolbarItem(placement: .primaryAction) {
                Button {
                    prepareShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isPreparingShare)
            }

            if FeatureFlag.isEnabled(.transcriptFullView) {
                ToolbarSpacer(.fixed)

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFullTranscript = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                let isFav = player.currentEpisode.map { favoritesStore.isFavorite($0.id) } ?? false
                Button {
                    guard let episodeId = player.currentEpisode?.id else { return }
                    favoritesStore.toggle(episodeId)
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .foregroundStyle(isFav ? .yellow : .primary)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    prepareShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isPreparingShare)
            }

            if FeatureFlag.isEnabled(.transcriptFullView) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFullTranscript = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
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

            if FeatureFlag.isEnabled(.projectSidecast) {
                GlassButton(
                    symbol: "scissors",
                    title: "Criar Clipe",
                    color: .orange,
                    action: {
                        if player.isPlaying {
                            player.togglePlayPause()
                        }
                        showSidecastClip = true
                    }
                )
            }
        }
        .padding(.bottom, UIDevice.isMac ? .spacing(.medium) : .zero)
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
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let pubDate = player.currentEpisode?.pubDate {
                Text(pubDate, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: .spacing(.xxxSmall)) {
            scrubberWithMarkers

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
        }
    }

    private static let trackHeight: CGFloat = 4
    private static let thumbSize: CGFloat = 14
    private static let trackColor = Color.darkerGreen
    private static let trackBgColor = Color(.systemGray4)

    private var scrubberWithMarkers: some View {
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

                ForEach(currentBookmarks) { bookmark in
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
                        .font(.system(size: 64))
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
