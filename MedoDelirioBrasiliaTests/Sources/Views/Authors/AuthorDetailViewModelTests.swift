//
//  AuthorDetailViewModelTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 17/06/26.
//

import Testing
import SwiftUI
@testable import MedoDelirio

struct AuthorDetailViewModelTests {

    // MARK: - Helpers

    private func makeContent(_ ids: [String]) -> [AnyEquatableMedoContent] {
        ids.map { AnyEquatableMedoContent(Sound(id: $0, title: "Sound \($0)")) }
    }

    private func makeSUT(
        author: Author = Author(id: "author-1", name: "Author"),
        repository: FakeContentRepository = FakeContentRepository(),
        userSettings: FakeUserSettings = FakeUserSettings()
    ) -> AuthorDetailViewModel {
        AuthorDetailViewModel(
            author: author,
            currentContentListMode: .constant(.regular),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            contentRepository: repository,
            userSettings: userSettings
        )
    }

    // MARK: - Loading content

    @Test
    func onViewLoaded_withContent_shouldEnterLoadedState() {
        let repository = FakeContentRepository()
        repository.contentByAuthor = makeContent(["1", "2", "3"])
        let sut = makeSUT(repository: repository)

        sut.onViewLoaded()

        guard case .loaded(let loaded) = sut.state else {
            Issue.record("Expected .loaded state, got \(sut.state)")
            return
        }
        #expect(loaded.map(\.id) == ["1", "2", "3"])
    }

    @Test
    func onViewLoaded_whenRepositoryThrows_shouldEnterErrorState() {
        let repository = FakeContentRepository()
        repository.contentByAuthorError = NSError(domain: "test", code: 1)
        let sut = makeSUT(repository: repository)

        sut.onViewLoaded()

        if case .error = sut.state {
            // success
        } else {
            Issue.record("Expected .error state, got \(sut.state)")
        }
    }

    // MARK: - soundCount / soundCountText

    @Test
    func soundCount_beforeLoading_shouldBeZero() {
        let sut = makeSUT()
        #expect(sut.soundCount == 0)
    }

    @Test
    func soundCount_afterLoading_shouldMatchContentCount() {
        let repository = FakeContentRepository()
        repository.contentByAuthor = makeContent(["1", "2"])
        let sut = makeSUT(repository: repository)

        sut.onViewLoaded()

        #expect(sut.soundCount == 2)
    }

    @Test
    func soundCountText_withSingleSound_shouldUseSingular() {
        let repository = FakeContentRepository()
        repository.contentByAuthor = makeContent(["1"])
        let sut = makeSUT(repository: repository)

        sut.onViewLoaded()

        #expect(sut.soundCountText == "1 SOM")
    }

    @Test
    func soundCountText_withMultipleSounds_shouldUsePlural() {
        let repository = FakeContentRepository()
        repository.contentByAuthor = makeContent(["1", "2", "3"])
        let sut = makeSUT(repository: repository)

        sut.onViewLoaded()

        #expect(sut.soundCountText == "3 SONS")
    }

    @Test
    func soundCountText_withNoSounds_shouldUsePlural() {
        let sut = makeSUT()

        sut.onViewLoaded()

        #expect(sut.soundCountText == "0 SONS")
    }

    // MARK: - Dependency forwarding

    @Test
    func onViewLoaded_shouldRequestContentForTheCurrentAuthor() {
        let repository = FakeContentRepository()
        let sut = makeSUT(author: Author(id: "author-42", name: "Forty Two"), repository: repository)

        sut.onViewLoaded()

        #expect(repository.lastContentByAuthorCall?.authorId == "author-42")
    }

    @Test
    func onViewLoaded_whenExplicitContentEnabled_shouldRequestSensitiveContent() {
        let repository = FakeContentRepository()
        let userSettings = FakeUserSettings()
        userSettings.showExplicitContent = true
        let sut = makeSUT(repository: repository, userSettings: userSettings)

        sut.onViewLoaded()

        #expect(repository.lastContentByAuthorCall?.allowSensitive == true)
    }

    @Test
    func onViewLoaded_whenExplicitContentDisabled_shouldNotRequestSensitiveContent() {
        let repository = FakeContentRepository()
        let userSettings = FakeUserSettings()
        userSettings.showExplicitContent = false
        let sut = makeSUT(repository: repository, userSettings: userSettings)

        sut.onViewLoaded()

        #expect(repository.lastContentByAuthorCall?.allowSensitive == false)
    }

    @Test
    func onSortOptionChanged_shouldForwardSelectedSortOrder() {
        let repository = FakeContentRepository()
        let sut = makeSUT(repository: repository)
        sut.soundSortOption = SoundSortOption.dateAddedDescending.rawValue

        sut.onSortOptionChanged()

        #expect(repository.lastContentByAuthorCall?.sortOrder == .dateAddedDescending)
    }
}
