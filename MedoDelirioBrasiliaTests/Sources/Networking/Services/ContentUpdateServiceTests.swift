//
//  ContentUpdateServiceTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 03/05/23.
//

import Testing
@testable import MedoDelirio

@MainActor
struct ContentUpdateServiceTests {

    private var service: ContentUpdateService!

    private var apiClient: FakeAPIClient!
    private var localDatabase: FakeLocalDatabase!
    private var fileManager: FakeContentFileManager!
    private var appMemory: FakeAppPersistentMemory!
    private var logger: FakeLoggerService!

    init() {
        self.apiClient = FakeAPIClient()
        self.localDatabase = FakeLocalDatabase()
        self.fileManager = FakeContentFileManager()
        self.appMemory = FakeAppPersistentMemory()
        self.logger = FakeLoggerService()

        self.service = ContentUpdateService(
            apiClient: apiClient,
            database: localDatabase,
            fileManager: fileManager,
            appMemory: appMemory,
            logger: logger
        )
    }

    @Test
    func update_whenTryingToInsertContentThatAlreadyExists_shouldMarkThatSavedEventAsSucceeded() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let event = UpdateEvent(contentId: "ABC", mediaType: .sound, eventType: .created, didSucceed: false)
        let sound = Sound(id: "ABC", title: "")

        localDatabase.localUpdates = [event]
        apiClient.updateEvents.append(event)
        apiClient.sound = sound
        localDatabase.sounds.append(sound)

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
        #expect(!fileManager.didCallDownloadSound)
    }

    @Test
    func update_whenNewContent_shouldCreateDownloadAndMarkEventAsSucceeded() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let event = UpdateEvent(contentId: "ABC", mediaType: .sound, eventType: .created, didSucceed: false)
        let sound = Sound(id: "ABC", title: "")

        apiClient.updateEvents.append(event)
        apiClient.sound = sound

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(localDatabase.didCallInsertSound)
        #expect(fileManager.didCallDownloadSound)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }

    @Test
    func update_whenSoundMetadataUpdated_shouldUpdateSoundAndMarkEventAsSucceeded() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let event = UpdateEvent(contentId: "ABC", mediaType: .sound, eventType: .metadataUpdated, didSucceed: false)
        let sound = Sound(id: "ABC", title: "")

        apiClient.updateEvents.append(event)
        apiClient.sound = sound

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(!localDatabase.didCallInsertSound)
        #expect(localDatabase.didCallUpdateSound)
        #expect(!localDatabase.didCallDeleteSound)
        #expect(!fileManager.didCallDownloadSound)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }

    @Test
    func update_whenSoundFileUpdated_shouldRedownloadAndMarkEventAsSucceeded() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let event = UpdateEvent(contentId: "ABC", mediaType: .sound, eventType: .fileUpdated, didSucceed: false)
        let sound = Sound(id: "ABC", title: "")

        apiClient.updateEvents.append(event)
        apiClient.sound = sound

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(!localDatabase.didCallInsertSound)
        #expect(fileManager.didCallDownloadSound)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }

    @Test
    func update_whenSoundRemoved_shouldDeleteSoundDeleteFileAndMarkEventAsSucceeded() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let event = UpdateEvent(contentId: "ABC", mediaType: .sound, eventType: .deleted, didSucceed: false)
        apiClient.updateEvents.append(event)

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(localDatabase.didCallDeleteSound)
        #expect(fileManager.didCallRemoveSoundFile)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }

    @Test
    func update_whenRetryingACreationThatWasLaterDeleted_shouldSkipItAndMarkItAsSucceeded() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let created = UpdateEvent(contentId: "ABC", dateTime: "2026-10-10T03:00:06.701Z", mediaType: .sound, eventType: .created, didSucceed: false)
        let deleted = UpdateEvent(contentId: "ABC", dateTime: "2026-10-10T03:00:29.284Z", mediaType: .sound, eventType: .deleted, didSucceed: true)
        localDatabase.localUpdates = [created, deleted]
        apiClient.sound = Sound(id: "ABC", title: "")

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(!localDatabase.didCallInsertSound)
        #expect(!fileManager.didCallDownloadSound)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }

    @Test
    func update_whenCreatedContentIsGoneFromServer_shouldMarkEventAsSucceededWithoutDownloading() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let created = UpdateEvent(contentId: "ABC", mediaType: .sound, eventType: .created, didSucceed: false)
        localDatabase.localUpdates = [created]
        apiClient.sound = nil

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(!localDatabase.didCallInsertSound)
        #expect(!fileManager.didCallDownloadSound)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }

    @Test
    func update_whenSoundIsCreatedAgainAfterBeingDeleted_shouldStillCreateIt() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let deleted = UpdateEvent(contentId: "ABC", dateTime: "2026-10-10T03:00:29.284Z", mediaType: .sound, eventType: .deleted, didSucceed: true)
        let created = UpdateEvent(contentId: "ABC", dateTime: "2026-10-10T04:00:00.000Z", mediaType: .sound, eventType: .created, didSucceed: false)
        localDatabase.localUpdates = [deleted, created]
        apiClient.sound = Sound(id: "ABC", title: "")

        await service.update()

        #expect(localDatabase.didCallInsertSound)
        #expect(fileManager.didCallDownloadSound)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }

    @Test
    func update_whenAuthorEventErroneouslySetAsFileUpdated_shouldNotProcessItAtAll() async throws {
        appMemory.hasAllowedContentUpdate(true)

        let event = UpdateEvent(contentId: "ABC", mediaType: .author, eventType: .fileUpdated, didSucceed: false)
        apiClient.updateEvents.append(event)

        await service.update()

        #expect(service.lastUpdateStatus == .done)
        #expect(!localDatabase.didCallUpdateAuthor)
        #expect(!fileManager.didCallDownloadSound)
        #expect(!fileManager.didCallDownloadSong)
        #expect(try localDatabase.unsuccessfulUpdates().isEmpty)
    }
}
