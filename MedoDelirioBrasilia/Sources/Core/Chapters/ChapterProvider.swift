//
//  ChapterProvider.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/07/26.
//

import Foundation

enum ChapterState: Equatable {

    case idle
    case notAvailable(reason: String)
    case loaded(chapters: [EpisodeChapter])
}

@Observable
final class ChapterProvider {

    // MARK: - Observable State

    private(set) var state: ChapterState = .idle

    /// The chapter covering the current playback position.
    ///
    /// Deliberately coarse: this only changes when playback crosses a chapter
    /// boundary, so views highlighting the active chapter invalidate a handful of
    /// times per episode instead of on every playback tick.
    private(set) var currentChapter: EpisodeChapter?

    // MARK: - Private

    @ObservationIgnored private var chapters: [EpisodeChapter] = []
    @ObservationIgnored private var lastChapterIndex: Int?

    // MARK: - Loading

    func load(episodeId: String?) {
        chapters = []
        lastChapterIndex = nil
        currentChapter = nil

        guard let episodeId, !episodeId.isEmpty else {
            state = .notAvailable(reason: "Nenhum episódio selecionado.")
            return
        }

        guard let data = try? Data(contentsOf: Self.chaptersFileURL()) else {
            state = .notAvailable(reason: "Nenhum capítulo disponível ainda.")
            return
        }

        guard let file = try? JSONDecoder().decode(EpisodeChaptersFile.self, from: data) else {
            state = .notAvailable(reason: "Não foi possível ler o arquivo de capítulos.")
            return
        }

        guard let entry = file.episodes[episodeId] else {
            state = .notAvailable(reason: "Esse episódio ainda não tem capítulos.")
            return
        }

        let normalized = Self.normalized(entry.chapters)
        guard !normalized.isEmpty else {
            state = .notAvailable(reason: "A lista de capítulos está vazia.")
            return
        }

        chapters = normalized
        state = .loaded(chapters: normalized)
    }

    // MARK: - Time Update

    /// Call this with the current playback time to update the active chapter.
    func update(currentTime: TimeInterval) {
        guard !chapters.isEmpty else { return }

        let index = findChapterIndex(for: currentTime)

        guard index != lastChapterIndex else { return }
        lastChapterIndex = index

        currentChapter = index.map { chapters[$0] }
    }

    // MARK: - Binary Search

    /// Returns the index of the last chapter starting at or before `time`, or nil
    /// when playback sits before the first chapter begins.
    private func findChapterIndex(for time: TimeInterval) -> Int? {
        guard let first = chapters.first, time >= first.start else { return nil }

        var low = 0
        var high = chapters.count - 1
        var match = 0

        while low <= high {
            let mid = (low + high) / 2
            if chapters[mid].start <= time {
                match = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return match
    }

    // MARK: - Helpers

    /// Sorts by start, drops entries with negative starts or blank titles, and
    /// keeps only the first chapter for any given whole second so `id` stays
    /// unique even if a generation pass emits duplicates.
    private static func normalized(_ raw: [EpisodeChapter]) -> [EpisodeChapter] {
        var seenSeconds = Set<Int>()

        return raw
            .filter { $0.start >= 0 && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.start < $1.start }
            .filter { seenSeconds.insert(Int($0.start)).inserted }
    }

    // MARK: - File Path

    static func chaptersFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(InternalFolderNames.chapters)
            .appendingPathComponent("chapters.json")
    }
}

// MARK: - Mocks

extension ChapterProvider {

    static func mockLoaded() -> ChapterProvider {
        let provider = ChapterProvider()
        let mockChapters: [EpisodeChapter] = [
            EpisodeChapter(start: 0, title: "Abertura"),
            EpisodeChapter(start: 184, title: "A sessão do Congresso"),
            EpisodeChapter(start: 902, title: "O relatório da CPI"),
            EpisodeChapter(start: 1740, title: "Cartas dos ouvintes"),
            EpisodeChapter(start: 2510, title: "Recomendações da semana"),
            EpisodeChapter(start: 3120, title: "Encerramento"),
        ]
        provider.chapters = mockChapters
        provider.state = .loaded(chapters: mockChapters)
        provider.currentChapter = mockChapters[1]
        provider.lastChapterIndex = 1
        return provider
    }

    static func mockNotAvailable() -> ChapterProvider {
        let provider = ChapterProvider()
        provider.state = .notAvailable(reason: "Esse episódio ainda não tem capítulos.")
        return provider
    }
}
