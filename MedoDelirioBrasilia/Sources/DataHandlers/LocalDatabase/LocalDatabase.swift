import Foundation
import SQLite
import SQLiteMigrationManager

internal protocol LocalDatabaseProtocol {

    // Content
    func content(withIds contentIds: [String]) throws -> [AnyEquatableMedoContent]
    func contentExists(withId contentId: String) throws -> Bool

    // Favorite
    func isFavorite(contentId: String) throws -> Bool
    func insert(favorite newFavorite: Favorite) throws
    func favorites() throws -> [Favorite]
    func deleteFavorite(withId contentId: String) throws

    // Sound
    func insert(sound newSound: Sound) throws
    func update(sound updatedSound: Sound) throws
    func delete(soundId: String) throws
    func setIsFromServer(to value: Bool, onSoundId soundId: String) throws
    func sounds(matchingDescription searchText: String) throws -> [Sound]
    func sounds(withIds soundIds: [String]) throws -> [Sound]
    func sounds(allowSensitive: Bool) throws -> [Sound]

    // Author
    func allAuthors() throws -> [Author]
    func insert(author newAuthor: Author) throws
    func update(author updatedAuthor: Author) throws
    func delete(authorId: String) throws
    func author(withId authorId: String) throws -> Author?

    // UserFolder
    func allFolders() throws -> [UserFolder]
    func contentsInside(userFolder userFolderId: String) throws -> [UserFolderContent]
    func contentExistsInsideUserFolder(withId folderId: String, contentId: String) throws -> Bool
    func insert(contentId: String, intoUserFolder userFolderId: String) throws
    func contentIdsInside(userFolder userFolderId: String) throws -> [String]
    func folderHashes() throws -> [String: String]
    func folders(withIds folderIds: [String]) throws -> [UserFolder]
    func update(userSortPreference: Int, forFolderId userFolderId: String) throws
    func insert(_ userFolder: UserFolder) throws
    func update(_ userFolder: UserFolder) throws
    func deleteUserFolder(withId folderId: String) throws
    func deleteUserContentFromFolder(withId folderId: String, contentId: String) throws

    // Song
    func insert(song newSong: Song) throws
    func update(song updatedSong: Song) throws
    func delete(songId: String) throws
    func setIsFromServer(to value: Bool, onSongId songId: String) throws
    func songs(withIds songIds: [String]) throws -> [Song]
    func songs(allowSensitive: Bool) throws -> [Song]

    // MusicGenre
    func insert(genre newGenre: MusicGenre) throws
    func update(genre updatedGenre: MusicGenre) throws
    func delete(genreId: String) throws
    func musicGenre(withId genreId: String) throws -> MusicGenre?

    // UpdateEvent
    func insert(updateEvent newUpdateEvent: UpdateEvent) throws
    func markAsSucceeded(updateEventId: UUID) throws
    func unsuccessfulUpdates() throws -> [UpdateEvent]
    func exists(withId updateEventId: UUID) throws -> Bool
    func dateTimeOfLastUpdate() -> String

    // SyncLog
    func insert(syncLog newSyncLog: SyncLog)

    // Retrospective
    func getTopSoundsSharedByTheUser(_ limit: Int) throws -> [TopChartItem]
    func getTopAuthorSharedByTheUser() throws -> TopAuthorItem?
    func totalShareCount() -> Int
    func allDatesInWhichTheUserShared() throws -> [Date]
    func sharedSoundsCount() -> Int
    
    // Retrospective 2025
    func getTopSoundsSharedByTheUserFor2025Retro(_ limit: Int) throws -> [TopChartItem]
    func getTopAuthorSharedByTheUserFor2025Retro() throws -> TopAuthorItem?
    func totalShareCountFor2025Retro() -> Int
    func allDatesInWhichTheUserSharedFor2025Retro() throws -> [Date]
    func sharedSoundsCountFor2025Retro() -> Int

    // Pinned Reactions
    func insert(_ pinnedReaction: Reaction) throws
    func pinnedReactions() throws -> [Reaction]
    func delete(reactionId: String) throws

    // Episode Favorite
    func allEpisodeFavoriteIDs() throws -> Set<String>
    func insertEpisodeFavorite(episodeId: String) throws
    func deleteEpisodeFavorite(episodeId: String) throws

    // Episode Played
    func allEpisodePlayedIDs() throws -> Set<String>
    func insertEpisodePlayed(episodeId: String) throws
    func deleteEpisodePlayed(episodeId: String) throws

    // Episode Progress
    func allEpisodeProgress() throws -> [String: (currentTime: Double, duration: Double)]
    func upsertEpisodeProgress(episodeId: String, currentTime: Double, duration: Double) throws
    func deleteEpisodeProgress(episodeId: String) throws

    // Episode Bookmark
    func allBookmarks(forEpisodeId episodeId: String) throws -> [EpisodeBookmark]
    func allBookmarkedEpisodeIDs() throws -> Set<String>
    func allBookmarkDates() throws -> [Date]
    func insertBookmark(_ bookmark: EpisodeBookmark) throws
    func updateBookmark(_ bookmark: EpisodeBookmark) throws
    func deleteBookmark(id: String) throws

    // Podcast Episode Cache
    func allPodcastEpisodes() throws -> [PodcastEpisode]
    func podcastEpisode(id: String) throws -> PodcastEpisode?
    func upsertPodcastEpisodes(_ episodes: [PodcastEpisode]) throws

    // Episode Listen Log
    func insertEpisodeListenLog(_ log: EpisodeListenLog) throws
    func allEpisodeListenLogs() throws -> [EpisodeListenLog]
    func episodeListenLogs(forEpisodeId episodeId: String) throws -> [EpisodeListenLog]
    func allListenDates() throws -> [Date]
    func deleteAllEpisodeListenLogs() throws

    func pendingShareStatsNotSentToServer() throws -> [PendingShareCountStat]
    func getUniqueBundleIdsThatWereSharedTo() throws -> [ServerShareBundleIdLog]
    func markUserShareLogsAsSent(logIds: [String]) throws
    func markAllUserShareLogsAsSentToServer() throws
    func clearAudienceSharingStatisticTable() throws
}

class LocalDatabase: LocalDatabaseProtocol {

    var db: Connection
    var migrationManager: SQLiteMigrationManager
    
    var favorite = Table("favorite")
    var userShareLog = Table("userShareLog")
    var audienceSharingStatistic = Table("audienceSharingStatistic")
    var networkCallLog = Table("networkCallLog")
    var userFolder = Table("userFolder")
    var userFolderContent = Table("userFolderContent")
    var soundTable = Table("sound")
    var author = Table("author")
    var updateEventTable = Table("updateEvent")
    var syncLogTable = Table("syncLog")
    let songTable = Table("song")
    var musicGenreTable = Table("musicGenre")
    var pinnedReactionTable = Table("pinnedReaction")
    var episodeFavoriteTable = Table("episodeFavorite")
    var episodePlayedTable = Table("episodePlayed")
    var episodeProgressTable = Table("episodeProgress")
    var podcastEpisodeTable = Table("podcastEpisode")
    var episodeBookmarkTable = Table("episodeBookmark")
    var episodeListenLogTable = Table("episodeListenLog")

    static let shared = LocalDatabase()
    
    // MARK: - Setup
    
    init() {
        do {
            db = try Connection(LocalDatabase.databaseFilepath())
        } catch {
            fatalError(error.localizedDescription)
        }

        self.migrationManager = SQLiteMigrationManager(db: self.db, migrations: LocalDatabase.migrations())
    }
    
    func migrateIfNeeded() throws {
        if !migrationManager.hasMigrationsTable() {
            try migrationManager.createMigrationsTable()
        }

        if migrationManager.needsMigration() {
            try migrationManager.migrateDatabase()
        }
    }

}

extension LocalDatabase {

    static func databaseFilepath() -> String {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first!
        return "\(path)/medo_db.sqlite3"
    }

    static func migrations() -> [Migration] {
        return [
            InitialMigration(),
            AddNetworkCallLogTable(),
            AddUserFolderTables(),
            RemoveFavoriteLogTable(),
            AddAudienceSharingStatisticTable(),
            AddRankingTypeToAudienceSharingStatisticTable(),
            AddDateAndVersionToUserFolderTables(),
            AddSyncTables(),
            AddSongAndMusicGenreTables(),
            AddExternalLinksFieldToAuthorTable(),
            AddChangeHashFieldToUserFolderTable(),
            AddPinnedReactionTable(),
            AddEpisodeStateTables(),
            AddPodcastEpisodeTable(),
            AddEpisodeBookmarkTable(),
            AddEpisodeListenLogTable(),
            CleanUpSlashEpisodeId()
        ]
    }

    var needsMigration: Bool {
        return migrationManager.needsMigration()
    }
}

extension LocalDatabase: CustomStringConvertible {

    var description: String {
        return "Database:\n" +
        "url: \(LocalDatabase.databaseFilepath())\n" +
        "migration state:\n" +
        "  hasMigrationsTable() \(migrationManager.hasMigrationsTable())\n" +
        "  currentVersion()     \(migrationManager.currentVersion())\n" +
        "  originVersion()      \(migrationManager.originVersion())\n" +
        "  appliedVersions()    \(migrationManager.appliedVersions())\n" +
        "  pendingMigrations()  \(migrationManager.pendingMigrations())\n" +
        "  needsMigration()     \(migrationManager.needsMigration())"
    }

}

// MARK: - Date Parsing

private let localDatabaseDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

extension LocalDatabase {

    func parseLocalDatabaseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return localDatabaseDateFormatter.date(from: value)
    }
}

enum LocalDatabaseError: Error {

    case favoriteNotFound
    case folderNotFound
    case folderContentNotFound
    case internalError
    case authorNotFound
    case songNotFound
    case musicGenreNotFound
    case pinnedReactionNotFound
    case episodeProgressNotFound
}

extension LocalDatabaseError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .favoriteNotFound:
            return NSLocalizedString("O Favorito solicitado não foi encontrado no banco de dados.", comment: "Favorito Não Encontrado")
        case .folderNotFound:
            return NSLocalizedString("A Pasta solicitada não foi encontrada no banco de dados.", comment: "Pasta Não Encontrada")
        case .folderContentNotFound:
            return NSLocalizedString("O Conteúdo de Pasta solicitado não foi encontrado no banco de dados.", comment: "Conteúdo de Pasta Não Encontrado")
        case .internalError:
            return NSLocalizedString("Ocorreu um erro interno.", comment: "Erro Interno")
        case .authorNotFound:
            return NSLocalizedString("O Autor solicitado não foi encontrado no banco de dados.", comment: "Autor Não Encontrado")
        case .songNotFound:
            return NSLocalizedString("A Música solicitada não foi encontrada no bando de dados.", comment: "")
        case .musicGenreNotFound:
            return NSLocalizedString("O Gênero Musical solicitado não foi encontrado no banco de dados.", comment: "")
        case .pinnedReactionNotFound:
            return NSLocalizedString("A Reação Fixada solicitada não foi encontrada no banco de dados.", comment: "")
        case .episodeProgressNotFound:
            return NSLocalizedString("O progresso do episódio solicitado não foi encontrado no banco de dados.", comment: "")
        }
    }
}
