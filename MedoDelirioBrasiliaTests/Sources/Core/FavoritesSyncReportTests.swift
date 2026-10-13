//
//  FavoritesSyncReportTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 13/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct FavoritesSyncReportTests {

    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    @Test
    func report_shouldSplitWhatDiffersBetweenHereAndTheCloud() {
        let sut = FavoritesSyncReport(
            localDates: ["a": date, "b": date, "c": date],
            localTombstones: ["x": date],
            cloudRecords: [
                "a": ContentFavoriteRecord(isFavorite: true, updatedAt: date),
                "d": ContentFavoriteRecord(isFavorite: true, updatedAt: date),
                "b": ContentFavoriteRecord(isFavorite: false, updatedAt: date)
            ],
            catalogIDs: ["a", "b", "d"]
        )

        #expect(sut.onlyHere == ["b", "c"])
        #expect(sut.onlyInCloud == ["d"])
        #expect(sut.notInCatalog == ["c"])
        #expect(sut.shownCount == 2)
        #expect(sut.cloudRemovals == 1)
        #expect(sut.localRemovals == 1)
        #expect(!sut.isInStep)
    }

    @Test
    func report_whenEverythingMatches_shouldBeInStep() {
        let sut = FavoritesSyncReport(
            localDates: ["a": date],
            localTombstones: [:],
            cloudRecords: ["a": ContentFavoriteRecord(isFavorite: true, updatedAt: date)],
            catalogIDs: ["a"]
        )

        #expect(sut.isInStep)
    }

    @Test
    func report_withNothingFromTheCloud_shouldNotClaimToBeInStep() {
        let sut = FavoritesSyncReport(localDates: [:], localTombstones: [:], cloudRecords: nil, catalogIDs: [])

        #expect(sut.cloudFavorites == nil)
        #expect(!sut.isInStep)
    }
}
