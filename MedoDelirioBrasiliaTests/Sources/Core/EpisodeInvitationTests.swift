//
//  EpisodeInvitationTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 01/11/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct EpisodeInvitationTests {

    private let database = FakeLocalDatabase()
    private let defaults = UserDefaults(suiteName: "EpisodeInvitationTests-\(UUID().uuidString)")!

    private var sut: EpisodeInvitation {
        EpisodeInvitation(database: database, userDefaults: defaults)
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    // MARK: - Who

    @Test
    func hasNeverListened_withNothingSaved_isTrue() {
        #expect(sut.hasNeverListened())
    }

    @Test
    func hasNeverListened_afterAListen_isFalse() {
        database.episodeListenLogs = [
            EpisodeListenLog(episodeId: "ep-1", startedAt: date(1), endedAt: date(1), durationListened: 60, didComplete: false)
        ]

        #expect(!sut.hasNeverListened())
    }

    @Test
    func hasNeverListened_withAPlaceSavedFromAnotherDevice_isFalse() {
        database.episodeProgress = ["ep-1": (currentTime: 120, duration: 3600, updatedAt: date(1))]

        #expect(!sut.hasNeverListened())
    }

    // MARK: - What

    @Test
    func suggestedEpisode_withoutAHighlight_isTheLatest() {
        database.podcastEpisodes = [.mockLastWeek, .mockRecent, .mockOld]

        #expect(sut.suggestedEpisode(highlightedEpisodeId: nil) == .mockRecent)
    }

    @Test
    func suggestedEpisode_withAHighlight_isTheHighlightedOne() {
        database.podcastEpisodes = [.mockLastWeek, .mockRecent, .mockOld]

        #expect(sut.suggestedEpisode(highlightedEpisodeId: PodcastEpisode.mockLastWeek.id) == .mockLastWeek)
    }

    @Test
    func suggestedEpisode_withAHighlightNotDownloadedYet_isTheLatest() {
        database.podcastEpisodes = [.mockLastWeek, .mockRecent]

        #expect(sut.suggestedEpisode(highlightedEpisodeId: "not-synced-yet") == .mockRecent)
    }

    @Test
    func suggestedEpisode_withNoEpisodes_isNil() {
        #expect(sut.suggestedEpisode(highlightedEpisodeId: nil) == nil)
    }

    // MARK: - Card

    @Test
    func card_afterBeingClosed_staysClosed() {
        sut.dismissCard()

        #expect(!sut.canShowCard(on: date(1)))
    }

    @Test
    func card_showsOnItsShareOfDaysAndThenStops() {
        for day in 1...EpisodeInvitation.maximumCardDays {
            #expect(sut.canShowCard(on: date(day)))
            sut.cardWasShown(on: date(day))
        }

        #expect(!sut.canShowCard(on: date(EpisodeInvitation.maximumCardDays + 1)))
    }

    @Test
    func card_shownTwiceInADay_countsOnce() {
        sut.cardWasShown(on: date(1, hour: 9))
        sut.cardWasShown(on: date(1, hour: 21))

        #expect(defaults.integer(forKey: "episodeInvitationCardDaysShown") == 1)
    }

    @Test
    func card_onItsLastDay_staysOpenUntilTheDayEnds() {
        for day in 1...EpisodeInvitation.maximumCardDays {
            sut.cardWasShown(on: date(day))
        }

        #expect(sut.canShowCard(on: date(EpisodeInvitation.maximumCardDays, hour: 22)))
    }
}
