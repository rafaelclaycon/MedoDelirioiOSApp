//
//  ContentUpdateService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 03/05/23.
//

import Foundation
import Observation

protocol ContentUpdateServiceProtocol {

    /// Returns `true` if any updates (local or remote) were processed.
    func update() async -> Bool
}

/// A service that updates local content to stay in sync with their versions on the server.
@Observable
@MainActor
class ContentUpdateService: ContentUpdateServiceProtocol {

    /// Single instance shared between the UI and background execution (silent pushes,
    /// scheduled refreshes) so concurrent updates can't process the same events twice.
    static let shared = ContentUpdateService(
        apiClient: APIClient.shared,
        database: LocalDatabase.shared,
        fileManager: ContentFileManager(),
        appMemory: AppPersistentMemory.shared,
        logger: Logger.shared
    )

    /// Number of events past which an update is worth showing progress for, in the
    /// in-app banner and outside the app.
    static let longUpdateThreshold: Int = 10

    // MARK: - Public Properties

    public var processedUpdateNumber: Int = 0
    public var totalUpdateCount: Int = 0
    public var isUpdating: Bool = false
    public var updateStartTime: Date? = nil
    public var lastUpdateStatus: ContentUpdateStatus = .updating

    /// Called once per run, as soon as the event count is known to be large. Lets the
    /// app layer ask the system to keep the update alive past backgrounding without
    /// this service knowing anything about background tasks.
    public var onLongUpdateDetected: (() -> Void)?

    /// Whether the previous run stopped before processing everything — the user ended the
    /// background continuation, or the system expired it. The UI uses this to resume
    /// promptly on return instead of waiting out the usual update-throttling windows.
    public private(set) var lastRunWasInterrupted: Bool = false

    public var estimatedSecondsRemaining: TimeInterval? {
        guard let start = updateStartTime,
              processedUpdateNumber > 0,
              totalUpdateCount > 0,
              processedUpdateNumber < totalUpdateCount else { return nil }

        let elapsed = Date().timeIntervalSince(start)
        let progress = Double(processedUpdateNumber) / Double(totalUpdateCount)
        let totalEstimated = elapsed / progress
        return totalEstimated - elapsed
    }

    // MARK: - Internal Properties

    private var localUnsuccessfulUpdates: [UpdateEvent]?
    private var serverUpdates: [UpdateEvent]?
    private var didReportLongUpdate: Bool = false
    private var isCancellationRequested: Bool = false

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let localDatabase: LocalDatabaseProtocol
    private let fileManager: ContentFileManagerProtocol
    private let appMemory: AppPersistentMemoryProtocol
    private let logger: LoggerProtocol

    // MARK: - Initializer

    init(
        apiClient: APIClientProtocol,
        database: LocalDatabaseProtocol,
        fileManager: ContentFileManagerProtocol,
        appMemory: AppPersistentMemoryProtocol,
        logger: LoggerProtocol
    ) {
        self.apiClient = apiClient
        self.localDatabase = database
        self.fileManager = fileManager
        self.appMemory = appMemory
        self.logger = logger
    }
}

// MARK: - Public Functions

extension ContentUpdateService {

    /// Asks the in-flight run to stop at the next event boundary. Everything processed so
    /// far keeps its success mark; the rest stays queued for a later run. No-op when idle.
    public func cancelCurrentUpdate() {
        guard isUpdating else { return }
        isCancellationRequested = true
    }

    /// Performs the content update operation with the server.
    @discardableResult
    public func update() async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true

        // The service outlives any single run, so progress starts from scratch each time.
        processedUpdateNumber = 0
        totalUpdateCount = 0
        updateStartTime = nil
        didReportLongUpdate = false
        isCancellationRequested = false
        lastRunWasInterrupted = false

        // Deliberately unstructured. The content list starts updates from a SwiftUI
        // `.task`, which SwiftUI cancels as soon as that view goes away — switching tabs
        // included. A sync has to outlive the view that happened to kick it off, so it
        // ends only when `cancelCurrentUpdate()` asks it to.
        let run = Task {
            await self.performUpdate()
        }
        return await run.value
    }

    private func performUpdate() async -> Bool {
        defer {
            appMemory.setLastUpdateAttempt(to: Date.now.iso8601withFractionalSeconds)
        }

        do {
            let didHaveAnyLocalUpdates = try await retryLocal()
            let didHaveAnyRemoteUpdates = try await syncDataWithServer()

            lastRunWasInterrupted = isCancellationRequested

            if didHaveAnyLocalUpdates || didHaveAnyRemoteUpdates {
                logger.updateSuccess("Atualização concluída com sucesso.")
            } else {
                logger.updateSuccess("Atualização concluída com sucesso, porém não existem novidades.")
            }

            lastUpdateStatus = .done
            isUpdating = false
            updateStartTime = nil
            return didHaveAnyLocalUpdates || didHaveAnyRemoteUpdates
        } catch is CancellationError {
            lastRunWasInterrupted = true
            lastUpdateStatus = .done
            isUpdating = false
            updateStartTime = nil
            return false
        } catch APIClientError.errorFetchingUpdateEvents(let errorMessage) {
            logger.updateError(errorMessage)
            lastUpdateStatus = .updateError
            isUpdating = false
            updateStartTime = nil
            return true // Error counts as "something happened" - show toast
        } catch ContentUpdateError.errorInsertingUpdateEvent(let updateEventId) {
            logger.updateError("Erro ao tentar inserir UpdateEvent no banco de dados.", updateEventId: updateEventId)
            lastUpdateStatus = .updateError
            isUpdating = false
            updateStartTime = nil
            return true
        } catch {
            logger.updateError(error.localizedDescription)
            lastUpdateStatus = .updateError
            isUpdating = false
            updateStartTime = nil
            return true
        }
    }
}

// MARK: - Internal Functions - Manipulating Updates

extension ContentUpdateService {

    private func getUpdates(from updateDateToConsider: String) async throws -> [UpdateEvent] {
        return try await apiClient.fetchUpdateEvents(from: updateDateToConsider)
    }

    private func retryLocal() async throws -> Bool {
        let localResult = try await retrieveUnsuccessfulLocalUpdates()
        guard localResult > 0 else { return false }

        // Counted before processing so the banner can show while we work through them.
        totalUpdateCount += localResult
        if updateStartTime == nil {
            updateStartTime = Date()
        }
        reportLongUpdateIfNeeded()

        try await syncUnsuccessful()
        return true
    }

    private func syncDataWithServer() async throws -> Bool {
        let result = try await retrieveServerUpdates()
        if result > 0 {
            try await serverSync()
        }
        return result > 0
    }

    private func retrieveServerUpdates() async throws -> Int {
        let lastUpdateDate = localDatabase.dateTimeOfLastUpdate()
        serverUpdates = try await getUpdates(from: lastUpdateDate)

        // Added to whatever the local retry phase already queued, so progress
        // reflects every event this run will process.
        let count = serverUpdates?.count ?? 0
        if count > 0 {
            totalUpdateCount += count
            if updateStartTime == nil {
                updateStartTime = Date()
            }
            reportLongUpdateIfNeeded()
        }

        if var serverUpdates = serverUpdates {
            for i in serverUpdates.indices {
                do {
                    if try !localDatabase.exists(withId: serverUpdates[i].id) {
                        serverUpdates[i].didSucceed = false
                        try localDatabase.insert(updateEvent: serverUpdates[i])
                    }
                } catch {
                    throw ContentUpdateError.errorInsertingUpdateEvent(updateEventId: serverUpdates[i].id.uuidString)
                }
            }
        }
        return count
    }

    private func reportLongUpdateIfNeeded() {
        guard !didReportLongUpdate, totalUpdateCount >= Self.longUpdateThreshold else { return }
        didReportLongUpdate = true
        onLongUpdateDetected?()
    }

    private func retrieveUnsuccessfulLocalUpdates() async throws -> Int {
        localUnsuccessfulUpdates = try localDatabase.unsuccessfulUpdates()
        return localUnsuccessfulUpdates?.count ?? 0
    }

    private func serverSync() async throws {
        guard let serverUpdates = serverUpdates, !serverUpdates.isEmpty else { return }

        for update in serverUpdates {
            guard !isCancellationRequested else { break }
            await process(updateEvent: update)
            processedUpdateNumber += 1
        }
    }

    private func syncUnsuccessful() async throws {
        guard let localUnsuccessfulUpdates = localUnsuccessfulUpdates, !localUnsuccessfulUpdates.isEmpty else { return }

        for update in localUnsuccessfulUpdates {
            guard !isCancellationRequested else { break }
            await process(updateEvent: update)
            processedUpdateNumber += 1
        }
    }

    private func process(updateEvent: UpdateEvent) async {
        switch updateEvent.eventType {
        case .created:
            await createResource(for: updateEvent)

        case .metadataUpdated:
            await updateResource(for: updateEvent)

        case .fileUpdated:
            if [MediaType.author, MediaType.musicGenre].contains(updateEvent.mediaType) {
                logger.updateError(
                    "Evento do tipo 'arquivo atualizado' recebido para o \(updateEvent.mediaType.description) \(updateEvent.contentId), porém esse tipo de evento não é válido para esse tipo de mídia.",
                    updateEventId: updateEvent.id.uuidString
                )
            } else {
                await updateResourceFile(for: updateEvent)
            }

        case .deleted:
            await deleteResource(for: updateEvent)
        }
    }
}

// MARK: - Internal Functions - Processing Updates

extension ContentUpdateService {

    private func createResource(for updateEvent: UpdateEvent) async {
        do {
            guard try !resourceAlreadyExists(updateEvent) else {
                try localDatabase.markAsSucceeded(updateEventId: updateEvent.id)
                let message = "\(updateEvent.mediaType.description) - \(updateEvent.contentId) já existe, marcando evento como bem sucedido."
                logger.updateError(message, updateEventId: updateEvent.id.uuidString)
                return
            }

            switch updateEvent.mediaType {
            case .sound:
                try localDatabase.insert(sound: try await apiClient.sound(updateEvent.contentId))
                try await fileManager.downloadSound(withId: updateEvent.contentId)
            case .author:
                try localDatabase.insert(author: try await apiClient.author(updateEvent.contentId))
            case .song:
                try localDatabase.insert(song: try await apiClient.song(updateEvent.contentId))
                try await fileManager.downloadSong(withId: updateEvent.contentId)
            case .musicGenre:
                try localDatabase.insert(genre: try await apiClient.musicGenre(updateEvent.contentId))
            }

            try localDatabase.markAsSucceeded(updateEventId: updateEvent.id)
            logger.updateSuccess(
                "\(updateEvent.mediaType.description) \(updateEvent.contentId) criade com sucesso.",
                updateEventId: updateEvent.id.uuidString
            )
        } catch {
            logger.updateError(
                "Erro ao tentar criar \(updateEvent.mediaType.description) - \(updateEvent.contentId): \(error.localizedDescription)",
                updateEventId: updateEvent.id.uuidString
            )
        }
    }

    private func resourceAlreadyExists(_ updateEvent: UpdateEvent) throws -> Bool {
        switch updateEvent.mediaType {
        case .sound, .song:
            return try localDatabase.contentExists(withId: updateEvent.contentId)
        case .author:
            return try localDatabase.author(withId: updateEvent.contentId) != nil
        case .musicGenre:
            return try localDatabase.musicGenre(withId: updateEvent.contentId) != nil
        }
    }

    private func updateResource(for updateEvent: UpdateEvent) async {
        do {
            switch updateEvent.mediaType {
            case .sound:
                try localDatabase.update(sound: try await apiClient.sound(updateEvent.contentId))
            case .author:
                try localDatabase.update(author: try await apiClient.author(updateEvent.contentId))
            case .song:
                try localDatabase.update(song: try await apiClient.song(updateEvent.contentId))
            case .musicGenre:
                try localDatabase.update(genre: try await apiClient.musicGenre(updateEvent.contentId))
            }

            try localDatabase.markAsSucceeded(updateEventId: updateEvent.id)
            logger.updateSuccess(
                "Dados de \(updateEvent.mediaType.description) \(updateEvent.contentId) atualizados com sucesso.",
                updateEventId: updateEvent.id.uuidString
            )
        } catch {
            logger.updateError(
                "Erro ao tentar atualizar dados de \(updateEvent.mediaType.description) - \(updateEvent.contentId): \(error.localizedDescription)",
                updateEventId: updateEvent.id.uuidString
            )
        }
    }

    private func updateResourceFile(for updateEvent: UpdateEvent) async {
        guard [MediaType.sound, MediaType.song].contains(updateEvent.mediaType) else { return }
        do {
            if updateEvent.mediaType == .sound {
                try await fileManager.downloadSound(withId: updateEvent.contentId)
                try localDatabase.setIsFromServer(to: true, onSoundId: updateEvent.contentId)
            } else {
                try await fileManager.downloadSong(withId: updateEvent.contentId)
                try localDatabase.setIsFromServer(to: true, onSongId: updateEvent.contentId)
            }
            try localDatabase.markAsSucceeded(updateEventId: updateEvent.id)
            logger.updateSuccess("Arquivo de \(updateEvent.mediaType.description) \(updateEvent.contentId) atualizado.", updateEventId: updateEvent.id.uuidString)
        } catch {
            logger.updateError(
                "Erro ao tentar atualizar arquivo de \(updateEvent.mediaType.description) - \(updateEvent.contentId): \(error.localizedDescription)",
                updateEventId: updateEvent.id.uuidString
            )
        }
    }

    private func deleteResource(for updateEvent: UpdateEvent) async {
        do {
            switch updateEvent.mediaType {
            case .sound:
                try localDatabase.delete(soundId: updateEvent.contentId)
                try fileManager.removeSoundFile(id: updateEvent.contentId)
            case .author:
                try localDatabase.delete(authorId: updateEvent.contentId)
            case .song:
                try localDatabase.delete(songId: updateEvent.contentId)
                try fileManager.removeSongFile(id: updateEvent.contentId)
            case .musicGenre:
                try localDatabase.delete(genreId: updateEvent.contentId)
            }

            try localDatabase.markAsSucceeded(updateEventId: updateEvent.id)
            logger.updateSuccess(
                "\(updateEvent.mediaType.description) \(updateEvent.contentId) removide com sucesso.",
                updateEventId: updateEvent.id.uuidString
            )
        } catch {
            logger.updateError(
                "Erro ao tentar remover \(updateEvent.mediaType.description) - \(updateEvent.contentId): \(error.localizedDescription)",
                updateEventId: updateEvent.id.uuidString
            )
        }
    }
}
