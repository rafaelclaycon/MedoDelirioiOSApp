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

    @Test(arguments: [
        nil,
        [:],
        ["position": 10.0, "duration": 100.0],
        ["episodeId": "", "position": 10.0, "duration": 100.0],
        ["episodeId": "ep-1", "duration": 100.0],
        ["episodeId": "ep-1", "position": Double.nan, "duration": 100.0],
        ["episodeId": "ep-1", "position": 10.0, "duration": 0.0],
        ["episodeId": "ep-1", "position": "10", "duration": 100.0]
    ] as [[String: AnyHashable]?])
    func payload_withMissingOrInvalidFields_shouldBeRejected(userInfo: [String: AnyHashable]?) {
        #expect(EpisodeHandoffPayload(userInfo: userInfo) == nil)
    }

    @Test
    func payload_shouldClampPositionIntoTheEpisode() {
        let past = EpisodeHandoffPayload(userInfo: ["episodeId": "ep-1", "position": 120.0, "duration": 100.0])
        let negative = EpisodeHandoffPayload(userInfo: ["episodeId": "ep-1", "position": -5.0, "duration": 100.0])

        #expect(past?.position == 100)
        #expect(negative?.position == 0)
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
