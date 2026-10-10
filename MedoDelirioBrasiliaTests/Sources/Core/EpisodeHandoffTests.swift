//
//  EpisodeHandoffTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct EpisodeHandoffTests {

    private let takenAt = Date(timeIntervalSince1970: 1_790_000_000)

    // MARK: - Payload

    @Test
    func payload_shouldRoundTripThroughUserInfo() {
        let payload = EpisodeHandoffPayload(episodeID: "ep-1", position: 754.5, duration: 4609)

        #expect(EpisodeHandoffPayload(userInfo: payload.userInfo) == payload)
    }

    @Test
    func payload_shouldDeclareEveryKeyItWritesAsRequired() {
        let payload = EpisodeHandoffPayload(episodeID: "ep-1", position: 1, duration: 2)

        #expect(Set(payload.userInfo.keys) == EpisodeHandoffPayload.requiredKeys)
    }

    enum InvalidUserInfo: CaseIterable {
        case none, empty, missingID, emptyID, missingPosition, nanPosition, zeroDuration, positionAsString

        var userInfo: [AnyHashable: Any]? {
            switch self {
            case .none: nil
            case .empty: [:]
            case .missingID: ["position": 10.0, "duration": 100.0]
            case .emptyID: ["episodeId": "", "position": 10.0, "duration": 100.0]
            case .missingPosition: ["episodeId": "ep-1", "duration": 100.0]
            case .nanPosition: ["episodeId": "ep-1", "position": Double.nan, "duration": 100.0]
            case .zeroDuration: ["episodeId": "ep-1", "position": 10.0, "duration": 0.0]
            case .positionAsString: ["episodeId": "ep-1", "position": "10", "duration": 100.0]
            }
        }
    }

    @Test(arguments: InvalidUserInfo.allCases)
    func payload_withMissingOrInvalidFields_shouldBeRejected(_ invalid: InvalidUserInfo) {
        #expect(EpisodeHandoffPayload(userInfo: invalid.userInfo) == nil)
    }

    @Test
    func payload_shouldClampPositionIntoTheEpisode() {
        let past = EpisodeHandoffPayload(userInfo: ["episodeId": "ep-1", "position": 120.0, "duration": 100.0])
        let negative = EpisodeHandoffPayload(userInfo: ["episodeId": "ep-1", "position": -5.0, "duration": 100.0])

        #expect(past?.position == 100)
        #expect(negative?.position == 0)
    }

    // MARK: - Continuation

    private let episode = PodcastEpisode.mockRecent

    @Test
    func continuation_whenTheEpisodeIsAlreadyLoaded_shouldResumeIt() {
        let payload = EpisodeHandoffPayload(episodeID: episode.id, position: 300, duration: 4000)

        let result = EpisodeHandoffContinuation.resolve(payload, loadedEpisodeID: episode.id) { _ in nil }

        #expect(result == .resume(at: 300))
    }

    @Test
    func continuation_whenAnotherEpisodeIsLoaded_shouldStartTheHandedOffOne() {
        let episode = episode
        let payload = EpisodeHandoffPayload(episodeID: episode.id, position: 300, duration: 4000)

        let result = EpisodeHandoffContinuation.resolve(payload, loadedEpisodeID: "another-episode") { id in
            id == episode.id ? episode : nil
        }

        #expect(result == .start(episode, at: 300))
    }

    @Test
    func continuation_whenTheEpisodeIsUnknownHere_shouldReportIt() {
        let payload = EpisodeHandoffPayload(episodeID: "ep-new", position: 300, duration: 4000)

        let result = EpisodeHandoffContinuation.resolve(payload, loadedEpisodeID: nil) { _ in nil }

        #expect(result == .episodeNotFound)
    }

    // MARK: - Snapshot

    @Test
    func snapshot_whilePlaying_shouldAdvanceWithElapsedTimeAndSpeed() {
        let snapshot = EpisodePlaybackSnapshot(episodeID: "ep-1", position: 100, duration: 4000, rate: 1.5, takenAt: takenAt)

        let payload = snapshot.payload(at: takenAt.addingTimeInterval(10))

        #expect(payload.position == 115)
    }

    @Test
    func snapshot_whilePaused_shouldStayPut() {
        let snapshot = EpisodePlaybackSnapshot(episodeID: "ep-1", position: 100, duration: 4000, rate: 0, takenAt: takenAt)

        let payload = snapshot.payload(at: takenAt.addingTimeInterval(600))

        #expect(payload.position == 100)
    }

    @Test
    func snapshot_shouldNotRunPastTheEnd() {
        let snapshot = EpisodePlaybackSnapshot(episodeID: "ep-1", position: 3990, duration: 4000, rate: 1, takenAt: takenAt)

        let payload = snapshot.payload(at: takenAt.addingTimeInterval(60))

        #expect(payload.position == 4000)
    }

    @Test
    func snapshot_askedForAnEarlierMoment_shouldNotGoBackwards() {
        let snapshot = EpisodePlaybackSnapshot(episodeID: "ep-1", position: 100, duration: 4000, rate: 1, takenAt: takenAt)

        let payload = snapshot.payload(at: takenAt.addingTimeInterval(-5))

        #expect(payload.position == 100)
    }
}
