//
//  EpisodeHighlightStoreTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 27/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct EpisodeHighlightStoreTests {

    private let apiClient = FakeAPIClient()
    private let url = "v4/episode-highlight"

    private func makeSUT() -> EpisodeHighlightStore {
        EpisodeHighlightStore(apiClient: apiClient)
    }

    private func respond(_ json: String) {
        apiClient.getErrors[url] = nil
        apiClient.getResponses[url] = Data(json.utf8)
    }

    @Test
    func load_withAKnownStyle_highlightsThatEpisodeOnly() async {
        respond(#"{"episodeId": "ep-1", "style": "lulaWin", "label": "Lula eleito"}"#)
        let sut = makeSUT()

        await sut.loadIfNeeded()

        #expect(sut.highlight(for: "ep-1") == .init(episodeId: "ep-1", style: .lulaWin, label: "Lula eleito"))
        #expect(sut.highlight(for: "ep-2") == nil)
    }

    @Test
    func load_withoutALabel_leavesItNil() async {
        respond(#"{"episodeId": "ep-1", "style": "lulaWin"}"#)
        let sut = makeSUT()

        await sut.loadIfNeeded()

        #expect(sut.highlight?.label == nil)
        #expect(sut.highlight?.style == .lulaWin)
    }

    @Test
    func load_withAStyleThisVersionDoesntKnow_highlightsNothing() async {
        respond(#"{"episodeId": "ep-1", "style": "fireworks"}"#)
        let sut = makeSUT()

        await sut.loadIfNeeded()

        #expect(sut.highlight == nil)
    }

    @Test
    func reload_afterTheHighlightIsTakenOff_clearsIt() async {
        respond(#"{"episodeId": "ep-1", "style": "lulaWin"}"#)
        let sut = makeSUT()
        await sut.loadIfNeeded()

        apiClient.getErrors[url] = APIClientError.resourceNotFound
        await sut.reload()

        #expect(sut.highlight == nil)
    }

    @Test
    func reload_whenTheRequestFails_keepsTheHighlight() async {
        respond(#"{"episodeId": "ep-1", "style": "lulaWin"}"#)
        let sut = makeSUT()
        await sut.loadIfNeeded()

        apiClient.getErrors[url] = APIClientError.unexpectedStatusCode
        await sut.reload()

        #expect(sut.highlight?.episodeId == "ep-1")
    }
}
