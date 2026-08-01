//
//  ChapterProvider.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/07/26.
//

import Foundation

enum ChapterState: Equatable {

    case idle
    case notAvailable(reason: String, showsCoverageNotice: Bool = false)
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

    /// Position of `currentChapter` in the loaded list, for "N de M" displays.
    /// Updates on the same coarse cadence as `currentChapter`.
    private(set) var currentChapterIndex: Int?

    // MARK: - Private

    @ObservationIgnored private var chapters: [EpisodeChapter] = []
    @ObservationIgnored private var lastChapterIndex: Int?

    // MARK: - Loading

    func load(episodeId: String?) {
        chapters = []
        lastChapterIndex = nil
        currentChapter = nil
        currentChapterIndex = nil

        guard let episodeId, !episodeId.isEmpty else {
            state = .notAvailable(reason: "Nenhum episódio selecionado.")
            return
        }

        guard FileManager.default.fileExists(atPath: ChapterDownloadService.chaptersFileURL().path) else {
            state = .notAvailable(reason: "Nenhum capítulo disponível ainda.", showsCoverageNotice: true)
            return
        }

        guard let file = Self.decodedFile() else {
            state = .notAvailable(reason: "Não foi possível ler o arquivo de capítulos.")
            return
        }

        guard let entry = file.episodes[episodeId] else {
            state = .notAvailable(reason: "Esse episódio ainda não tem capítulos.", showsCoverageNotice: true)
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
        currentChapterIndex = index
    }

    /// Whether this episode has usable chapters. Reads `state`, so it only
    /// invalidates on load — safe to check from a parent view's body.
    var hasChapters: Bool {
        if case .loaded = state { return true }
        return false
    }

    // MARK: - Navigation

    /// Where the chapter at `index` ends — the next chapter's start, or the end
    /// of the episode for the last one.
    func end(ofChapterAt index: Int, episodeDuration: TimeInterval) -> TimeInterval? {
        guard chapters.indices.contains(index) else { return nil }

        if index < chapters.count - 1 {
            return chapters[index + 1].start
        }
        return episodeDuration > chapters[index].start ? episodeDuration : nil
    }

    /// Start of the chapter to jump back to from `currentTime`.
    ///
    /// Restarts the current chapter unless playback is still near its beginning,
    /// in which case it steps back one — the familiar track-back behaviour.
    func previousChapterStart(from currentTime: TimeInterval, restartThreshold: TimeInterval = 3) -> TimeInterval? {
        guard let index = lastChapterIndex else { return chapters.first?.start }

        let start = chapters[index].start
        if currentTime - start > restartThreshold {
            return start
        }
        return index > 0 ? chapters[index - 1].start : start
    }

    /// Start of the next chapter, or nil when the last one is playing.
    func nextChapterStart() -> TimeInterval? {
        guard let index = lastChapterIndex, index < chapters.count - 1 else { return nil }
        return chapters[index + 1].start
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

    // MARK: - File Cache

    private struct DecodedFile {
        let modified: Date
        let size: Int
        let file: EpisodeChaptersFile
    }

    /// Shared across provider instances. Chapters ship as one bundled file for the
    /// whole catalog, so decoding it per episode change — or once per provider —
    /// would mean parsing hundreds of KB to look up a single entry.
    ///
    /// Only touched from `load(episodeId:)`, which views call on the main actor.
    nonisolated(unsafe) private static var cached: DecodedFile?

    /// Decodes `chapters.json`, reusing the last decode while the file on disk is
    /// unchanged. Keyed on modification date and size so a sync that replaces the
    /// file invalidates the cache without any notification plumbing.
    private static func decodedFile() -> EpisodeChaptersFile? {
        let url = ChapterDownloadService.chaptersFileURL()

        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let modified = attributes[.modificationDate] as? Date,
            let size = attributes[.size] as? Int
        else {
            return nil
        }

        if let cached, cached.modified == modified, cached.size == size {
            return cached.file
        }

        guard
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(EpisodeChaptersFile.self, from: data)
        else {
            return nil
        }

        cached = DecodedFile(modified: modified, size: size, file: file)
        return file
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
        provider.currentChapterIndex = 1
        provider.lastChapterIndex = 1
        return provider
    }

    static func mockNotAvailable() -> ChapterProvider {
        let provider = ChapterProvider()
        provider.state = .notAvailable(reason: "Esse episódio ainda não tem capítulos.", showsCoverageNotice: true)
        return provider
    }
}
