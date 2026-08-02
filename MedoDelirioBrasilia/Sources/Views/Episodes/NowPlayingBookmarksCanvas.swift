//
//  NowPlayingBookmarksCanvas.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import SwiftUI

/// The now-playing screen's bookmark list, with its own sort order.
struct NowPlayingBookmarksCanvas: View {

    /// Owned by the parent: this canvas is rebuilt from scratch whenever the
    /// user switches tabs, so local state here would reset the sort order every
    /// time they came back.
    @Binding var sortAscending: Bool

    /// Tapping a row opens the edit sheet, which the parent owns because it's
    /// presented over the whole screen rather than over this canvas.
    let onEdit: (EpisodeBookmark) -> Void

    @Environment(EpisodePlayer.self) private var player
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore

    private var sortedBookmarks: [EpisodeBookmark] {
        guard let episodeId = player.currentEpisode?.id else { return [] }
        let bookmarks = bookmarkStore.bookmarks(for: episodeId)
        return sortAscending
            ? bookmarks.sorted { $0.timestamp < $1.timestamp }
            : bookmarks.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        let bookmarks = sortedBookmarks
        if bookmarks.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Meus Marcadores")
                        .font(.headline)

                    Spacer()

                    Button {
                        sortAscending.toggle()
                    } label: {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.rubyRed)
                    }
                }
                .padding(.bottom, .spacing(.small))

                ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                    row(bookmark)

                    if index < bookmarks.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
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

    private func row(_ bookmark: EpisodeBookmark) -> some View {
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
            onEdit(bookmark)
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
