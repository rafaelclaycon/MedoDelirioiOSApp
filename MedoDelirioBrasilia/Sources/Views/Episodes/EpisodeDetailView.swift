//
//  EpisodeDetailView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import LinkPresentation
import SwiftUI
import Kingfisher

struct EpisodeDetailView: View {

    let episode: PodcastEpisode
    @Environment(EpisodePlayer.self) private var episodePlayer
    @Environment(EpisodeFavoritesStore.self) private var favoritesStore
    @Environment(EpisodeProgressStore.self) private var progressStore
    @Environment(EpisodePlayedStore.self) private var playedStore
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore

    @Environment(\.openURL) private var openURL

    @State private var editingBookmark: EpisodeBookmark?
    @State private var bookmarksSortAscending: Bool = true
    @State private var showDeleteConfirmation: Bool = false
    @State private var chapterProvider = ChapterProvider()
    @State private var pendingChapterID: Int?

    // Share
    @State private var isPreparingShare: Bool = false
    @State private var shareLinkMetadata: LPLinkMetadata?
    @State private var showShareSheet: Bool = false

    private var isPlayed: Bool {
        playedStore.isPlayed(episode.id)
    }

    private var episodeProgress: EpisodeProgressStore.EpisodeProgress? {
        progressStore.progress(for: episode.id)
    }

    private var hasProgress: Bool {
        guard let episodeProgress else { return false }
        return episodeProgress.currentTime > 0 && episodeProgress.duration > 0
    }

    private var downloadedFileSize: String? {
        let fileURL = EpisodePlayer.localFileURL(for: episode)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let bytes = attrs[.size] as? Int64, bytes > 0 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                header

                Divider()

                if let plainText = episode.plainTextDescription {
                    Text(plainText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                linksSection

                chaptersSection

                bookmarkSection
            }
            .padding(.horizontal, .spacing(.medium))
            .padding(.vertical, .spacing(.small))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingBookmark) { bookmark in
            BookmarkEditView(bookmark: bookmark)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: prepareShare) {
                    if isPreparingShare {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isPreparingShare)
                .accessibilityLabel("Compartilhar episódio")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesStore.toggle(episode.id)
                } label: {
                    Image(systemName: favoritesStore.isFavorite(episode.id) ? "star.fill" : "star")
                        .foregroundStyle(favoritesStore.isFavorite(episode.id) ? .yellow : .primary)
                }
                .accessibilityLabel(favoritesStore.isFavorite(episode.id) ? "Remover dos favoritos" : "Adicionar aos favoritos")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let metadata = shareLinkMetadata {
                LinkMetadataShareSheet(metadata: metadata)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Apagar Download", isPresented: $showDeleteConfirmation) {
            Button("Apagar", role: .destructive) {
                try? FileManager.default.removeItem(at: EpisodePlayer.localFileURL(for: episode))
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O arquivo local deste episódio será removido. Você poderá baixá-lo novamente.")
        }
        .background(EpisodeDetailPlayerAlerts(player: episodePlayer))
        .onAppear {
            if ChapterPreferences.isEnabled {
                chapterProvider.load(episodeId: episode.id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ChapterDownloadService.chaptersDidUpdate)) { _ in
            if ChapterPreferences.isEnabled {
                chapterProvider.load(episodeId: episode.id)
            }
        }
    }

    // MARK: - Share

    private func prepareShare() {
        guard !isPreparingShare else { return }
        guard let shareURL = URL(string: APIConfig.baseLinkURL + "episodio/\(episode.id)") else {
            return
        }
        isPreparingShare = true
        Task { await AnalyticsService().send(originatingScreen: "EpisodeDetail", action: "didTapShare(\(episode.id))") }

        Task {
            let meta = LPLinkMetadata()
            meta.url = shareURL
            meta.title = episode.title

            // Download the episode thumbnail ourselves so iOS never falls back
            // to the server's apple-touch-icon.
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
            HStack(spacing: .spacing(.xxxSmall)) {
                Text(episode.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if CommandLine.arguments.contains("-SHOW_MORE_DEV_OPTIONS") {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(episode.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if favoritesStore.isFavorite(episode.id) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            Text(episode.title)
                .font(.title)
                .fontDesign(.serif)

            HStack(spacing: .spacing(.medium)) {
                EpisodeDetailPlaybackControls(episode: episode)

                if isPlayed {
                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.5))
                } else if hasProgress, let episodeProgress {
                    Text(Self.formatTimeRemaining(episodeProgress.duration - episodeProgress.currentTime))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let formattedDuration = episode.formattedDuration {
                    Text(formattedDuration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let fileSize = downloadedFileSize {
                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(fileSize)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if isPlayed {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline)
                        }
                        .accessibilityLabel("Apagar download")
                    }
                }
            }
            .padding(.top, .spacing(.xxxSmall))

            if hasProgress, let episodeProgress {
                ProgressView(value: episodeProgress.currentTime, total: episodeProgress.duration)
                    .tint(.primary)
            }
        }
    }

    private static func formatTimeRemaining(_ remaining: TimeInterval) -> String {
        let totalMinutes = Int(max(remaining, 0)) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours) hr \(minutes) min restantes"
        } else if hours > 0 {
            return "\(hours) hr restantes"
        } else if minutes > 0 {
            return "\(minutes) min restantes"
        } else {
            return "< 1 min restante"
        }
    }

    // MARK: - Links

    @ViewBuilder
    private var linksSection: some View {
        let links = episode.extractedLinks
        if !links.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text("Links")
                    .font(.headline)
                    .padding(.bottom, .spacing(.small))

                ForEach(Array(links.enumerated()), id: \.element) { index, url in
                    linkRow(url)

                    if index < links.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func linkRow(_ url: URL) -> some View {
        let isMailto = url.scheme == "mailto"
        let displayText: String = {
            if isMailto {
                return url.absoluteString
                    .replacingOccurrences(of: "mailto:", with: "")
            }
            var text = url.host ?? url.absoluteString
            let path = url.path
            if !path.isEmpty, path != "/" {
                text += path
            }
            return text
        }()

        return Button {
            openURL(url)
        } label: {
            HStack(spacing: .spacing(.medium)) {
                if isMailto {
                    Image(systemName: "envelope")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 28, height: 28)
                } else {
                    faviconImage(for: url)
                }

                Text(displayText)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, .spacing(.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func faviconImage(for url: URL) -> some View {
        let faviconURL: URL? = {
            guard let host = url.host else { return nil }
            return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
        }()

        return KFImage(faviconURL)
            .placeholder {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .onFailure { _ in }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Chapters

    @ViewBuilder
    private var chaptersSection: some View {
        if case .loaded(let chapters) = chapterProvider.state {
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text("Capítulos")
                    .font(.headline)
                    .padding(.bottom, .spacing(.small))

                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    detailChapterRow(number: index + 1, chapter: chapter, length: chapterLength(at: index, in: chapters))

                    if index < chapters.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    /// How long a chapter runs — the gap to the next one, or to the end of the
    /// episode for the last chapter. Returns nil when the episode duration isn't
    /// known, so the row simply omits the length.
    private func chapterLength(at index: Int, in chapters: [EpisodeChapter]) -> TimeInterval? {
        let end: TimeInterval
        if index < chapters.count - 1 {
            end = chapters[index + 1].start
        } else {
            guard let duration = episode.duration, duration > 0 else { return nil }
            end = duration
        }

        let length = end - chapters[index].start
        return length > 0 ? length : nil
    }

    private func detailChapterRow(number: Int, chapter: EpisodeChapter, length: TimeInterval?) -> some View {
        // `isPendingRow` is driven solely by local state set synchronously on tap,
        // not by `episodePlayer`'s busy flags — those live on a separate
        // `@Observable` object and can update a render late relative to `@State`,
        // which previously left every row showing neither the spinner nor a
        // resolved idle state. Blocking other rows only needs to know *something*
        // is in flight, which `pendingChapterID != nil` already tells us.
        let isPendingRow = pendingChapterID == chapter.id
        let isBlocked = pendingChapterID != nil && !isPendingRow

        return Button {
            guard pendingChapterID == nil else { return }
            pendingChapterID = chapter.id
            Task {
                await episodePlayer.play(episode: episode)
                episodePlayer.seek(to: chapter.start)
                if pendingChapterID == chapter.id {
                    pendingChapterID = nil
                }
            }
        } label: {
            HStack(alignment: .center, spacing: .spacing(.medium)) {
                chapterLeadingIndicator(number: number, isPendingRow: isPendingRow)

                Text(chapter.title)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let length {
                    Text(Self.formattedChapterLength(length))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, .spacing(.small))
            .contentShape(Rectangle())
            .opacity(isBlocked ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
        .accessibilityLabel("Capítulo \(number): \(chapter.title), começa em \(chapter.formattedStart)")
    }

    @ViewBuilder
    private func chapterLeadingIndicator(number: Int, isPendingRow: Bool) -> some View {
        if isPendingRow && episodePlayer.isDownloading(episode) {
            ProgressView(value: episodePlayer.downloadProgress[episode.id] ?? 0)
                .progressViewStyle(.circular)
                .tint(.primary)
                .frame(width: 28, alignment: .leading)
        } else if isPendingRow && (episodePlayer.isPreparing(episode) || !episodePlayer.isCurrentEpisode(episode)) {
            // Covers the preparing phase and the gap between tap and the
            // player's flags updating — an in-flight row always shows *some*
            // indicator rather than briefly looking untapped.
            ProgressView()
                .frame(width: 28, alignment: .leading)
        } else {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
        }
    }

    /// Rounded to the nearest minute — chapter lengths are a glanceable signal of
    /// pacing, not something worth reading to the second.
    private static func formattedChapterLength(_ length: TimeInterval) -> String {
        let minutes = Int((length / 60).rounded())
        return minutes < 1 ? "<1 min" : "\(minutes) min"
    }

    // MARK: - Bookmarks

    private var episodeBookmarks: [EpisodeBookmark] {
        bookmarkStore.bookmarks(for: episode.id)
    }

    private var sortedBookmarks: [EpisodeBookmark] {
        let bookmarks = episodeBookmarks
        return bookmarksSortAscending
            ? bookmarks.sorted { $0.timestamp < $1.timestamp }
            : bookmarks.sorted { $0.timestamp > $1.timestamp }
    }

    @ViewBuilder
    private var bookmarkSection: some View {
        let bookmarks = sortedBookmarks
        if !bookmarks.isEmpty {
            Divider()

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
                    .accessibilityLabel("Ordenar marcadores")
                }
                .padding(.bottom, .spacing(.small))

                ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                    detailBookmarkRow(bookmark)

                    if index < bookmarks.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func detailBookmarkRow(_ bookmark: EpisodeBookmark) -> some View {
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
                Task {
                    await episodePlayer.play(episode: episode)
                    episodePlayer.seek(to: bookmark.timestamp)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.body)
                    .foregroundStyle(Color.rubyRed)
                    .padding(.spacing(.xxxSmall))
            }
            .if_iOS26GlassElsePlain()
            .accessibilityLabel("Reproduzir a partir do marcador")
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
}

private struct EpisodeDetailPlaybackControls: View {
    @Environment(EpisodePlayer.self) private var episodePlayer

    let episode: PodcastEpisode

    private var isThisEpisodePlaying: Bool {
        episodePlayer.isCurrentEpisode(episode) && episodePlayer.isPlaying
    }

    var body: some View {
        if episodePlayer.isDownloading(episode) {
            downloadProgressIndicator
        } else {
            Button {
                Task {
                    await episodePlayer.play(episode: episode)
                }
            } label: {
                Label(
                    isThisEpisodePlaying ? "Pausar" : "Ouvir",
                    systemImage: isThisEpisodePlaying ? "pause.fill" : "play.fill"
                )
                .font(.subheadline)
                .fontWeight(.semibold)
            }
            .if_iOS26GlassElseBorderedProminent()
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
                .accessibilityLabel("Cancelar download")
            }
            .frame(width: 32, height: 32)

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct EpisodeDetailPlayerAlerts: View {
    let player: EpisodePlayer

    var body: some View {
        Color.clear
            .alert(
                "Download Grande",
                isPresented: Binding(
                    get: { player.pendingCellularDownload != nil },
                    set: { _ in }
                )
            ) {
                Button("Baixar Mesmo Assim") {
                    Task { await player.confirmCellularDownload() }
                }
                Button("Cancelar", role: .cancel) {
                    player.dismissCellularDownload()
                }
            } message: {
                Text("Você está usando dados móveis e este episódio tem aproximadamente \(player.pendingDownloadSizeMB) MB. Deseja continuar com o download?")
            }
            .alert("Erro", isPresented: Binding(
                get: { player.playerError != nil },
                set: { if !$0 { player.playerError = nil } }
            )) {
                Button("OK") { player.playerError = nil }
            } message: {
                Text(player.playerError ?? "")
            }
    }
}

// MARK: - Liquid Glass Helper

private extension View {

    @ViewBuilder
    func if_iOS26GlassElseBorderedProminent() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func if_iOS26GlassElsePlain() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.plain)
        }
    }
}
