//
//  FakeLocalDatabase.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 02/02/23.
//

import Foundation

enum CustomSQLiteError: Error {

    case databaseError(message: String)
    case queryError(message: String)
}

class FakeLocalDatabase: LocalDatabaseProtocol {

    var folders = [UserFolder]()
    var contentInsideFolder = [UserFolderContent]()
    var localUpdates = [UpdateEvent]()
    var errorToThrowOnInsertUpdateEvent: CustomSQLiteError? = nil

    var didCallInsertSound = false
    var didCallUpdateSound = false
    var didCallDeleteSound = false
    var didCallSetIsFromServerOnSoundId = false

    var didCallInsertAuthor = false
    var didCallUpdateAuthor = false
    var didCallDeleteAuthor = false

    var didCallInsertSong = false
    var didCallUpdateSong = false
    var didCallDeleteSong = false
    var didCallSetIsFromServerOnSongId = false

    var didCallInsertGenre = false
    var didCallUpdateGenre = false
    var didCallDeleteGenre = false

    var didCallInsertUpdateEvent = false
    var didCallMarkAsSucceeded = false
    var didCallUnsuccessfulUpdates = false

    var didCallInsertSyncLog = false

    var topSharedSounds: [TopChartItem] = []
    var shareCount: Int = 0
    var shareDates: [Date] = []
    var numberOfTimesInsertUpdateEventWasCalled = 0

    var sounds = [Sound]()
    var pendingShareStats = [PendingShareCountStat]()
    var bundleIdLogs = [ServerShareBundleIdLog]()
    var markedShareLogIds = [String]()

    var didCallDeletePinnedReaction = false

    // Content

    func content(withIds contentIds: [String]) throws -> [AnyEquatableMedoContent] {
        []
    }

    // Favorite

    func isFavorite(contentId: String) throws -> Bool {
        false
    }

    func insert(favorite newFavorite: Favorite) throws {
        //
    }

    func favorites() throws -> [Favorite] {
        []
    }

    func deleteFavorite(withId contentId: String) throws {
        //
    }

    // Sound

    func insert(sound newSound: Sound) throws {
        didCallInsertSound = true
        if sounds.contains(where: { $0.id == newSound.id }) {
            throw CustomSQLiteError.databaseError(message: "A operação não pôde ser concluída. (SQLite.Result erro 0.)")
        }
    }

    func update(sound updatedSound: Sound) throws {
        didCallUpdateSound = true
    }

    func delete(soundId: String) throws {
        didCallDeleteSound = true
    }

    func setIsFromServer(to value: Bool, onSoundId soundId: String) throws {
        didCallSetIsFromServerOnSoundId = true
    }

    func sounds(withIds soundIds: [String]) throws -> [Sound] {
        []
    }

    func sounds(allowSensitive: Bool) throws -> [Sound] {
        []
    }

    func contentExists(withId contentId: String) throws -> Bool {
        sounds.contains(where: { $0.id == contentId })
    }

    func sounds(matchingDescription searchText: String) throws -> [Sound] {
        []
    }

    // Author

    func allAuthors() throws -> [Author] {
        []
    }

    func insert(author newAuthor: Author) throws {
        didCallInsertAuthor = true
    }

    func update(author updatedAuthor: Author) throws {
        didCallUpdateAuthor = true
    }

    func delete(authorId: String) throws {
        didCallDeleteAuthor = true
    }

    func author(withId authorId: String) throws -> Author? {
        nil
    }

    // UserFolder

    func allFolders() throws -> [UserFolder] {
        folders
    }

    func contentsInside(userFolder userFolderId: String) throws -> [UserFolderContent] {
        contentInsideFolder.filter { $0.userFolderId == userFolderId }
    }

    func contentExistsInsideUserFolder(withId folderId: String, contentId: String) throws -> Bool {
        contentInsideFolder.contains(where: { $0.contentId == contentId })
    }

    func insert(contentId: String, intoUserFolder userFolderId: String) throws {
        //
    }

    func contentIdsInside(userFolder userFolderId: String) throws -> [String] {
        contentInsideFolder.compactMap {
            guard $0.userFolderId == userFolderId else { return nil }
            return $0.contentId
        }
    }

    func folderHashes() throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.changeHash ?? "") })
    }

    func folders(withIds folderIds: [String]) throws -> [UserFolder] {
        folders.filter { folderIds.contains($0.id) }
    }

    func update(userSortPreference: Int, forFolderId userFolderId: String) throws {
        //
    }

    func insert(_ userFolder: UserFolder) throws {
        //
    }

    func update(_ userFolder: UserFolder) throws {
        //
    }

    func deleteUserFolder(withId folderId: String) throws {
        //
    }

    func deleteUserContentFromFolder(withId folderId: String, contentId: String) throws {
        //
    }

    // Song

    func insert(song newSong: Song) throws {
        didCallInsertSong = true
    }

    func update(song updatedSong: Song) throws {
        didCallUpdateSong = true
    }

    func delete(songId: String) throws {
        didCallDeleteSong = true
    }

    func setIsFromServer(to value: Bool, onSongId songId: String) throws {
        didCallSetIsFromServerOnSongId = true
    }

    func songs(withIds songIds: [String]) throws -> [Song] {
        []
    }

    func songs(allowSensitive: Bool) throws -> [Song] {
        []
    }

    // MusicGenre

    func insert(genre newGenre: MusicGenre) throws {
        didCallInsertGenre = true
    }

    func update(genre updatedGenre: MusicGenre) throws {
        didCallUpdateGenre = true
    }

    func delete(genreId: String) throws {
        didCallDeleteGenre = true
    }

    func musicGenre(withId genreId: String) throws -> MusicGenre? {
        nil
    }

    // UpdateEvent

    func insert(updateEvent newUpdateEvent: UpdateEvent) throws {
        didCallInsertUpdateEvent = true
        numberOfTimesInsertUpdateEventWasCalled += 1
        if let error = errorToThrowOnInsertUpdateEvent {
            throw error
        }
    }

    func markAsSucceeded(updateEventId: UUID) throws {
        didCallMarkAsSucceeded = true
        for i in stride(from: 0, to: localUpdates.count, by: 1) {
            if localUpdates[i].id == updateEventId {
                localUpdates[i].didSucceed = true
            }
        }
    }

    func unsuccessfulUpdates() throws -> [UpdateEvent] {
        didCallUnsuccessfulUpdates = true
        return localUpdates.filter { $0.didSucceed == false }
    }

    func exists(withId updateEventId: UUID) -> Bool {
        return localUpdates.contains(where: { $0.id == updateEventId })
    }

    func dateTimeOfLastUpdate() -> String {
        let dateFormatter = ISO8601DateFormatter()
        let dateArray = localUpdates.compactMap { dateFormatter.date(from: $0.dateTime) }

        if let latestDate = dateArray.max() {
            return dateFormatter.string(from: latestDate)
        } else {
            return "all"
        }
    }

    // SyncLog

    func insert(syncLog newSyncLog: SyncLog) {
        didCallInsertSyncLog = true
    }

    // Retrospective

    func getTopSoundsSharedByTheUser(_ limit: Int) throws -> [TopChartItem] {
        return topSharedSounds
    }

    func getTopAuthorSharedByTheUser() throws -> TopAuthorItem? {
        nil
    }

    func totalShareCount() -> Int {
        return shareCount
    }

    func allDatesInWhichTheUserShared() throws -> [Date] {
        return shareDates
    }

    func sharedSoundsCount() -> Int {
        0
    }

    // Retrospective 2025

    func getTopSoundsSharedByTheUserFor2025Retro(_ limit: Int) throws -> [TopChartItem] {
        return topSharedSounds
    }

    func getTopAuthorSharedByTheUserFor2025Retro() throws -> TopAuthorItem? {
        nil
    }

    func totalShareCountFor2025Retro() -> Int {
        return shareCount
    }

    func allDatesInWhichTheUserSharedFor2025Retro() throws -> [Date] {
        return shareDates
    }

    func sharedSoundsCountFor2025Retro() -> Int {
        0
    }

    // Pinned Reactions

    func insert(_ pinnedReaction: Reaction) throws {}

    func pinnedReactions() throws -> [Reaction] {
        []
    }

    func delete(reactionId: String) throws {
        didCallDeletePinnedReaction = true
    }

    // Episode Favorite

    func allEpisodeFavoriteIDs() throws -> Set<String> { [] }
    func insertEpisodeFavorite(episodeId: String) throws {}
    func deleteEpisodeFavorite(episodeId: String) throws {}

    // Episode Played

    func allEpisodePlayedIDs() throws -> Set<String> { [] }
    func insertEpisodePlayed(episodeId: String) throws {}
    func deleteEpisodePlayed(episodeId: String) throws {}

    // Episode Progress

    var episodeProgress: [String: (currentTime: Double, duration: Double)] = [:]

    func allEpisodeProgress() throws -> [String: (currentTime: Double, duration: Double)] { episodeProgress }
    func upsertEpisodeProgress(episodeId: String, currentTime: Double, duration: Double) throws {
        episodeProgress[episodeId] = (currentTime, duration)
    }
    func deleteEpisodeProgress(episodeId: String) throws {
        episodeProgress.removeValue(forKey: episodeId)
    }

    // Podcast Episode Cache

    func allPodcastEpisodes() throws -> [PodcastEpisode] { [] }
    func podcastEpisode(id: String) throws -> PodcastEpisode? { nil }
    func upsertPodcastEpisodes(_ episodes: [PodcastEpisode]) throws {}

    // Episode Bookmark

    var bookmarks: [EpisodeBookmark] = []

    func allBookmarks(forEpisodeId episodeId: String) throws -> [EpisodeBookmark] {
        bookmarks.filter { $0.episodeId == episodeId }
    }
    func allBookmarkedEpisodeIDs() throws -> Set<String> {
        Set(bookmarks.map { $0.episodeId })
    }
    func allBookmarkDates() throws -> [Date] {
        bookmarks.map { $0.createdAt }
    }
    func insertBookmark(_ bookmark: EpisodeBookmark) throws {
        bookmarks.append(bookmark)
    }
    func updateBookmark(_ bookmark: EpisodeBookmark) throws {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
        }
    }
    func deleteBookmark(id: String) throws {
        bookmarks.removeAll { $0.id == id }
    }

    // Episode Listen Log

    var episodeListenLogs: [EpisodeListenLog] = []

    func insertEpisodeListenLog(_ log: EpisodeListenLog) throws {
        episodeListenLogs.append(log)
    }

    func allEpisodeListenLogs() throws -> [EpisodeListenLog] {
        episodeListenLogs
    }

    func episodeListenLogs(forEpisodeId episodeId: String) throws -> [EpisodeListenLog] {
        episodeListenLogs.filter { $0.episodeId == episodeId }
    }

    func allListenDates() throws -> [Date] {
        episodeListenLogs.map(\.startedAt)
    }

    func deleteAllEpisodeListenLogs() throws {
        episodeListenLogs.removeAll()
    }

    func markAllUserShareLogsAsSentToServer() throws {
        //
    }

    func pendingShareStatsNotSentToServer() throws -> [PendingShareCountStat] {
        pendingShareStats
    }

    func getUniqueBundleIdsThatWereSharedTo() throws -> [ServerShareBundleIdLog] {
        bundleIdLogs
    }

    func markUserShareLogsAsSent(logIds: [String]) throws {
        markedShareLogIds.append(contentsOf: logIds)
    }

    func clearAudienceSharingStatisticTable() throws {
        //
    }
}
