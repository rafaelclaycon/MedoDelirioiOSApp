//
//  SearchServiceTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 06/05/25.
//

import Testing
@testable import MedoDelirio

@MainActor
struct SearchServiceTests {

    @Test("When an EMPTY string is provided, it is NOT saved")
    func test_emptyStringIsNotSaved() async throws {
        let memory = FakeAppPersistentMemory()
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: memory,
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )
        service.save(searchString: "")

        #expect(service.recentSearches() == [])
        #expect(memory.recentSearches() == [])
    }

    @Test("When an NON-EMPTY string is provided, it IS saved but only ONCE")
    func test_nonEmptyStringIsSaved() async throws {
        let memory = FakeAppPersistentMemory()
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: memory,
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )
        service.save(searchString: "Anitt")
        service.save(searchString: "Anitt")
        service.save(searchString: "Anitt")
        service.flushPendingSave()

        #expect(service.recentSearches() == ["Anitt"])
        #expect(memory.recentSearches() == ["Anitt"])
    }

    @Test("When an 3 non-empty strings are provided, they are saved from last to first")
    func test_threeNonEmptyStringsAreSaved() async throws {
        let memory = FakeAppPersistentMemory()
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: memory,
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )
        service.save(searchString: "Anitt")
        service.save(searchString: "Meme")
        service.save(searchString: "Bolso")
        service.flushPendingSave()

        #expect(service.recentSearches() == ["Bolso", "Meme", "Anitt"])
        #expect(memory.recentSearches() == ["Bolso", "Meme", "Anitt"])
    }

    @Test("Only long versions of a string are saved")
    func test_onlyLongestVersionIsSaved() async throws {
        let memory = FakeAppPersistentMemory()
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: memory,
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )
        service.save(searchString: "Anitt")
        service.save(searchString: "Meme")
        service.save(searchString: "Jair")

        service.save(searchString: "Jair Bolsonaro")

        service.save(searchString: "Jair Bols")
        service.flushPendingSave()

        #expect(service.recentSearches() == ["Jair Bolsonaro", "Meme", "Anitt"])
        #expect(memory.recentSearches() == ["Jair Bolsonaro", "Meme", "Anitt"])
    }

    @Test("Longer version takes the top spot")
    func test_longerVersionTakesTheTopSpot() async throws {
        let memory = FakeAppPersistentMemory()
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: memory,
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )
        service.save(searchString: "Meme")
        service.save(searchString: "Jair")
        service.save(searchString: "Anitt")

        service.save(searchString: "Jair Bolsonaro")
        service.flushPendingSave()

        #expect(service.recentSearches() == ["Jair Bolsonaro", "Anitt", "Meme"])
        #expect(memory.recentSearches() == ["Jair Bolsonaro", "Anitt", "Meme"])
    }

    // MARK: - Reaction Search Tests

    @Test("Reactions state is loading by default")
    func test_reactionsStateIsLoadingByDefault() async throws {
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: FakeAppPersistentMemory(),
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )

        #expect(service.reactionsState == .loading)
    }

    @Test("After loading reactions, state becomes loaded")
    func test_afterLoadingReactions_stateBecomesLoaded() async throws {
        let reactionRepo = FakeReactionRepository()
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: FakeAppPersistentMemory(),
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: reactionRepo
        )

        await service.loadReactions()

        #expect(reactionRepo.didCallAllReactions == true)
        if case .loaded(let reactions) = service.reactionsState {
            #expect(reactions.isEmpty)
        } else {
            #expect(Bool(false), "Expected .loaded state")
        }
    }

    @Test("Results returns nil for reactions when not loaded")
    func test_resultsReturnsNilForReactions_whenNotLoaded() async throws {
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: FakeAppPersistentMemory(),
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )

        let results = service.results(matching: "test", mode: .virgulas)

        #expect(results.reactionsMatchingTitle == nil)
    }

    @Test("Results returns empty array for reactions when loaded but no matches")
    func test_resultsReturnsEmptyArray_whenLoadedButNoMatches() async throws {
        let service = SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: FakeAppPersistentMemory(),
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: FakeReactionRepository()
        )

        await service.loadReactions()
        let results = service.results(matching: "test", mode: .virgulas)

        #expect(results.reactionsMatchingTitle?.isEmpty == true)
    }
}
