//
//  SearchService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/05/25.
//

import Foundation

protocol SearchServiceProtocol {

    var reactionsState: LoadingState<[Reaction]> { get }

    func results(matching searchString: String, mode: SearchMode) -> SearchResults
    func searchTranscripts(matching searchString: String) async -> [EpisodeTranscriptGroup]
    func loadReactions() async

    func save(searchString: String)
    func recentSearches() -> [String]
    func clearRecentSearches()

    func invalidateTranscriptCache()
    func releaseTranscriptCache()
}

@MainActor
final class SearchService: SearchServiceProtocol {

    private let contentRepository: ContentRepositoryProtocol
    private let authorService: AuthorServiceProtocol
    private let appMemory: AppPersistentMemoryProtocol
    private let userFolderRepository: UserFolderRepositoryProtocol
    private let userSettings: UserSettingsProtocol
    private let reactionRepository: ReactionRepositoryProtocol
    private let database: LocalDatabaseProtocol

    private var searches: [String] = []
    private(set) var reactionsState: LoadingState<[Reaction]> = .loading
    private var saveWorkItem: DispatchWorkItem?
    private var reactionsLoadedAt: Date?
    private var cachedEpisodes: [PodcastEpisode]?
    private var cachedTranscriptIndex: [String: [TranscriptIndexEntry]]?

    private let reactionsCacheMaxAge: TimeInterval = 30 * 60 // 30 minutes
    private let maxMatchesPerEpisode = 5
    private var transcriptObserver: Any?

    deinit {
        saveWorkItem?.cancel()
        if let observer = transcriptObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Initializer

    init(
        contentRepository: ContentRepositoryProtocol,
        authorService: AuthorServiceProtocol,
        appMemory: AppPersistentMemoryProtocol,
        userFolderRepository: UserFolderRepositoryProtocol,
        userSettings: UserSettingsProtocol,
        reactionRepository: ReactionRepositoryProtocol,
        database: LocalDatabaseProtocol = LocalDatabase.shared
    ) {
        self.contentRepository = contentRepository
        self.authorService = authorService
        self.appMemory = appMemory
        self.userFolderRepository = userFolderRepository
        self.userSettings = userSettings
        self.reactionRepository = reactionRepository
        self.database = database
        self.searches = appMemory.recentSearches() ?? []

        transcriptObserver = NotificationCenter.default.addObserver(
            forName: TranscriptDownloadService.transcriptsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateTranscriptCache()
        }
    }

    // MARK: - Functions

    func results(matching searchString: String, mode: SearchMode) -> SearchResults {
        save(searchString: searchString)

        switch mode {
        case .virgulas:
            let allowSensitive = userSettings.getShowExplicitContent()
            return SearchResults(
                soundsMatchingTitle: contentRepository.sounds(matchingTitle: searchString, allowSensitive),
                soundsMatchingContent: contentRepository.sounds(matchingDescription: searchString, allowSensitive),
                songsMatchingTitle: contentRepository.songs(matchingTitle: searchString, allowSensitive),
                songsMatchingContent: contentRepository.songs(matchingDescription: searchString, allowSensitive),
                authors: authorService.authors(matchingName: searchString),
                folders: userFolderRepository.folders(matchingName: searchString),
                reactionsMatchingTitle: reactions(matchingTitle: searchString)
            )

        case .episodios:
            let titleMatched = episodes(matchingTitle: searchString)
            let titleIds = Set(titleMatched?.map(\.id) ?? [])
            let descMatched = episodes(matchingDescription: searchString, excludingIds: titleIds)
            return SearchResults(
                episodesMatchingTitle: titleMatched,
                episodesMatchingDescription: descMatched
            )
        }
    }

    func searchTranscripts(matching searchString: String) async -> [EpisodeTranscriptGroup] {
        let index = loadTranscriptIndexIfNeeded()
        guard !index.isEmpty else { return [] }

        let allEpisodes = loadEpisodesIfNeeded()
        let episodeMap = Dictionary(uniqueKeysWithValues: allEpisodes.map { ($0.id, $0) })
        let normalizedSearch = searchString.normalizedForSearch()
        let perEpisodeCap = maxMatchesPerEpisode

        let titleMatched = episodes(matchingTitle: searchString)
        let titleIds = Set(titleMatched?.map(\.id) ?? [])
        let descMatched = episodes(matchingDescription: searchString, excludingIds: titleIds)
        let descIds = Set(descMatched?.map(\.id) ?? [])
        let excludingIds = titleIds.union(descIds)

        let groups: [EpisodeTranscriptGroup] = await Task.detached {
            var result: [EpisodeTranscriptGroup] = []
            for (episodeId, entries) in index {
                if excludingIds.contains(episodeId) { continue }
                guard let episode = episodeMap[episodeId] else { continue }

                let matchingEntries = entries
                    .filter { $0.normalizedText.contains(normalizedSearch) }
                    .prefix(perEpisodeCap)

                if !matchingEntries.isEmpty {
                    result.append(EpisodeTranscriptGroup(
                        episode: episode,
                        matches: matchingEntries.map { entry in
                            TranscriptMatch(cueText: entry.originalText, timestamp: entry.startTime)
                        }
                    ))
                }
            }
            return result.sorted { $0.episode.pubDate > $1.episode.pubDate }
        }.value

        return groups
    }

    func loadReactions() async {
        // Skip if recently loaded and still valid
        if let loadedAt = reactionsLoadedAt,
           Date().timeIntervalSince(loadedAt) < reactionsCacheMaxAge,
           case .loaded = reactionsState {
            return
        }

        reactionsState = .loading
        do {
            let reactions = try await reactionRepository.allReactions()
            reactionsState = .loaded(reactions)
            reactionsLoadedAt = Date()
        } catch {
            reactionsState = .error(error.localizedDescription)
        }
    }

    func save(searchString: String) {
        guard !searchString.isEmpty else { return }

        // Update in-memory array immediately
        if let index = firstIndexOf(searchString: searchString) {
            guard searches[index].count < searchString.count else { return }
            searches.remove(at: index)
            searches.insert(searchString, at: 0)
        } else {
            searches.insert(searchString, at: 0)
        }

        if searches.count > 3 {
            searches.removeLast()
        }

        // Debounce the disk write
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.appMemory.saveRecentSearches(self.searches)
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func recentSearches() -> [String] {
        searches
    }

    func clearRecentSearches() {
        searches = []
        appMemory.saveRecentSearches([])
    }

    func invalidateTranscriptCache() {
        cachedTranscriptIndex = nil
    }

    func releaseTranscriptCache() {
        cachedTranscriptIndex = nil
    }

    /// Immediately executes any pending save operation. Useful for testing.
    func flushPendingSave() {
        saveWorkItem?.perform()
        saveWorkItem = nil
    }
}

// MARK: - Internal Functions

extension SearchService {

    private func firstIndexOf(searchString: String) -> Int? {
        for i in 0..<searches.count {
            if searches[i].starts(with: searchString) ||
               searchString.contains(searches[i]) {
                return i
            }
        }
        return nil
    }

    private func reactions(matchingTitle title: String) -> [Reaction]? {
        guard case .loaded(let reactions) = reactionsState else { return nil }
        let normalizedSearch = title.normalizedForSearch()
        return reactions.filter {
            $0.title.normalizedForSearch().contains(normalizedSearch)
        }
    }

    private func loadEpisodesIfNeeded() -> [PodcastEpisode] {
        if let cached = cachedEpisodes { return cached }
        let loaded = (try? database.allPodcastEpisodes()) ?? []
        cachedEpisodes = loaded
        return loaded
    }

    private func episodes(matchingTitle title: String) -> [PodcastEpisode]? {
        let allEpisodes = loadEpisodesIfNeeded()
        let normalizedSearch = title.normalizedForSearch()
        return allEpisodes
            .filter { $0.title.normalizedForSearch().contains(normalizedSearch) }
            .sorted { $0.pubDate > $1.pubDate }
    }

    private func episodes(matchingDescription description: String, excludingIds: Set<String>) -> [PodcastEpisode]? {
        let allEpisodes = loadEpisodesIfNeeded()
        let normalizedSearch = description.normalizedForSearch()
        return allEpisodes
            .filter { !excludingIds.contains($0.id) }
            .filter { ($0.description ?? "").normalizedForSearch().contains(normalizedSearch) }
            .sorted { $0.pubDate > $1.pubDate }
    }

    // MARK: - Transcript Search

    private struct TranscriptIndexEntry {
        let normalizedText: String
        let originalText: String
        let startTime: TimeInterval
    }

    private func loadTranscriptIndexIfNeeded() -> [String: [TranscriptIndexEntry]] {
        if let cached = cachedTranscriptIndex { return cached }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let transcriptsDir = documentsURL.appendingPathComponent(InternalFolderNames.transcripts)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: transcriptsDir,
            includingPropertiesForKeys: nil
        ) else {
            cachedTranscriptIndex = [:]
            return [:]
        }

        var result: [String: [TranscriptIndexEntry]] = [:]
        for file in files where file.pathExtension.lowercased() == "srt" {
            let stem = file.deletingPathExtension().lastPathComponent
            let episodeId = Self.extractEpisodeId(from: stem)
            guard !episodeId.isEmpty,
                  let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let cues = SRTParser.parse(content)
            let entries = cues.map { cue in
                TranscriptIndexEntry(
                    normalizedText: cue.text.normalizedForSearch(),
                    originalText: cue.text,
                    startTime: cue.startTime
                )
            }
            if !entries.isEmpty {
                result[episodeId] = entries
            }
        }

        cachedTranscriptIndex = result
        return result
    }

    /// Extracts the episode ID prefix from a filename stem (e.g., "70791487-2026-19-com-trad" -> "70791487").
    private static func extractEpisodeId(from stem: String) -> String {
        if let dashIndex = stem.firstIndex(of: "-") {
            return String(stem[stem.startIndex..<dashIndex])
        }
        if let underscoreIndex = stem.firstIndex(of: "_") {
            return String(stem[stem.startIndex..<underscoreIndex])
        }
        return stem
    }
}
