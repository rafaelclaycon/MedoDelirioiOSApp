//
//  SearchServiceFuzzyTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 07/04/26.
//

import Testing
import Foundation
@testable import MedoDelirio

@Suite(.serialized)
@MainActor
struct SearchServiceFuzzyTests {

    // MARK: - Helpers

    private func makeService(
        reactionRepository: ReactionRepositoryProtocol = FakeReactionRepository()
    ) -> SearchService {
        SearchService(
            contentRepository: FakeContentRepository(),
            authorService: FakeAuthorService(),
            appMemory: FakeAppPersistentMemory(),
            userFolderRepository: FakeUserFolderRepository(),
            userSettings: FakeUserSettings(),
            reactionRepository: reactionRepository
        )
    }

    // MARK: - Mode Isolation

    @Test("Episodios mode does not return sounds or songs")
    func test_episodiosMode_noSoundOrSongResults() async throws {
        let service = makeService()
        let results = service.results(matching: "test", mode: .episodios)

        #expect(results.soundsMatchingTitle == nil)
        #expect(results.songsMatchingTitle == nil)
    }

    // MARK: - Fuzzy Reaction Matching

    @Test("Fuzzy reaction match finds exact title match")
    func test_fuzzyReaction_exactMatch() async throws {
        let repo = ReactionsWithDataFake()
        let service = makeService(reactionRepository: repo)
        await service.loadReactions()

        let results = service.results(matching: "choque", mode: .virgulas)

        #expect(results.reactionsMatchingTitle != nil)
        #expect(results.reactionsMatchingTitle?.isEmpty == false)
    }

    @Test("Fuzzy reaction match finds prefix match")
    func test_fuzzyReaction_prefixMatch() async throws {
        let repo = ReactionsWithDataFake()
        let service = makeService(reactionRepository: repo)
        await service.loadReactions()

        let results = service.results(matching: "choq", mode: .virgulas)

        #expect(results.reactionsMatchingTitle != nil)
        #expect(results.reactionsMatchingTitle?.isEmpty == false)
    }

    @Test("Fuzzy reaction match returns empty when no match")
    func test_fuzzyReaction_noMatch() async throws {
        let repo = ReactionsWithDataFake()
        let service = makeService(reactionRepository: repo)
        await service.loadReactions()

        let results = service.results(matching: "xyzxyzxyz", mode: .virgulas)

        #expect(results.reactionsMatchingTitle?.isEmpty == true)
    }

    @Test("Fuzzy reaction match returns nil when reactions not loaded")
    func test_fuzzyReaction_notLoaded() async throws {
        let service = makeService()

        let results = service.results(matching: "choque", mode: .virgulas)

        #expect(results.reactionsMatchingTitle == nil)
    }

    // MARK: - Top Hits

    @Test("topHits is nil when no results match")
    func test_topHits_nilWhenNoResults() async throws {
        let service = makeService(reactionRepository: ReactionsWithDataFake())
        await service.loadReactions()
        let results = service.results(matching: "xyzxyzxyz", mode: .virgulas)

        #expect(results.topHits == nil)
    }

    @Test("topHits contains at most 3 items")
    func test_topHits_atMostThreeItems() async throws {
        let service = makeService(reactionRepository: ReactionsWithDataFake())
        await service.loadReactions()
        let results = service.results(matching: "choque", mode: .virgulas)

        if let topHits = results.topHits {
            #expect(topHits.count <= 3)
        }
    }

    // MARK: - buildTopHits

    @Test("buildTopHits returns nil when all arrays are empty")
    func test_buildTopHits_emptyInput() {
        let service = makeService()
        let result = service.buildTopHits(
            soundsTitle: [],
            soundsDesc: [],
            songsTitle: [],
            songsDesc: [],
            authors: nil,
            folders: nil,
            reactions: nil
        )
        #expect(result == nil)
    }

    @Test("buildTopHits returns at most 3 items")
    func test_buildTopHits_maxThree() {
        let service = makeService()

        let sound1 = AnyEquatableMedoContent(Sound(id: "s1", title: "Sound 1"))
        let sound2 = AnyEquatableMedoContent(Sound(id: "s2", title: "Sound 2"))
        let song1 = AnyEquatableMedoContent(Song(id: "sg1", title: "Song 1", genreId: "g1", genreName: "Genre"))
        let song2 = AnyEquatableMedoContent(Song(id: "sg2", title: "Song 2", genreId: "g1", genreName: "Genre"))
        let author = Author(id: "auth1", name: "Author Mock")
        let folder = UserFolder(id: "f1", symbol: "📁", name: "Folder Mock", backgroundColor: "pastelBlue")
        let reaction = Reaction(id: "r1", title: "Reaction Mock", image: "")

        let result = service.buildTopHits(
            soundsTitle: [ScoredItem(item: sound1, score: 0.9)],
            soundsDesc: [ScoredItem(item: sound2, score: 0.8)],
            songsTitle: [ScoredItem(item: song1, score: 0.7)],
            songsDesc: [ScoredItem(item: song2, score: 0.6)],
            authors: [ScoredItem(item: author, score: 0.85)],
            folders: [ScoredItem(item: folder, score: 0.5)],
            reactions: [ScoredItem(item: reaction, score: 0.4)]
        )

        #expect(result != nil)
        #expect(result!.count == 3)
    }

    @Test("buildTopHits sorts by weighted score descending")
    func test_buildTopHits_sortedByWeightedScore() {
        let service = makeService()

        let sound = AnyEquatableMedoContent(Sound(id: "s1", title: "Sound"))
        let author = Author(id: "auth1", name: "Author Mock")
        let reaction = Reaction(id: "r1", title: "Reaction Mock", image: "")

        let result = service.buildTopHits(
            soundsTitle: [ScoredItem(item: sound, score: 0.5)],
            soundsDesc: [],
            songsTitle: [],
            songsDesc: [],
            authors: [ScoredItem(item: author, score: 1.0)],
            folders: nil,
            reactions: [ScoredItem(item: reaction, score: 0.9)]
        )

        #expect(result != nil)
        #expect(result!.count == 3)
        #expect(result![0].weightedScore >= result![1].weightedScore)
        #expect(result![1].weightedScore >= result![2].weightedScore)

        // author: 1.0 * 2.0 = 2.0 (highest)
        // sound title: 0.5 * 3.0 = 1.5 (second)
        // reaction: 0.9 * 1.5 = 1.35 (third)
        #expect(result![0].weightedScore == 2.0)
        #expect(result![1].weightedScore == 1.5)
        #expect(result![2].weightedScore == 1.35)
    }

    @Test("buildTopHits deduplicates by id, keeping highest weighted score")
    func test_buildTopHits_deduplication() {
        let service = makeService()

        let sound = AnyEquatableMedoContent(Sound(id: "same-id", title: "Sound"))

        let result = service.buildTopHits(
            soundsTitle: [ScoredItem(item: sound, score: 0.8)],
            soundsDesc: [ScoredItem(item: sound, score: 0.7)],
            songsTitle: [],
            songsDesc: [],
            authors: nil,
            folders: nil,
            reactions: nil
        )

        #expect(result != nil)
        #expect(result!.count == 1)
        // Title weight (3.0) * 0.8 = 2.4, Desc weight (1.5) * 0.7 = 1.05
        #expect(abs(result![0].weightedScore - 2.4) < 0.001)
    }
}

// MARK: - Test Doubles

private final class ReactionsWithDataFake: ReactionRepositoryProtocol {

    func allReactions() async throws -> [Reaction] {
        Reaction.allMocks
    }

    func reaction(_ reactionId: String) async throws -> Reaction {
        Reaction(id: reactionId, title: "Test", image: "")
    }

    func reactionContent(reactionId: String) async throws -> [ReactionContent] {
        []
    }

    func pinnedReactions(_ serverReactions: [Reaction]) async throws -> [Reaction] {
        []
    }

    func savePin(reaction: Reaction) throws {}
    func removePin(reactionId: String) throws {}
}
