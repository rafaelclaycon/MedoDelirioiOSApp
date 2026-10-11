//
//  TrendsMetricTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct TrendsMetricTests {

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func offered(_ metric: TrendsMetric, on now: Date) -> [TrendsTimeInterval] {
        [
            .last24Hours, .last3Days, .lastWeek, .lastMonth, .last3Months,
            .year2026, .year2025, .year2024, .year2023, .year2022, .allTime
        ].filter { metric.isAvailable($0, now: now) }
    }

    // MARK: - Tests

    @Test
    func sharesOfferEveryPeriod() {
        #expect(offered(.shares, on: date(2026, 10, 11)).count == 11)
    }

    @Test
    func playsRightAfterLaunchOfferOnlyWhatFitsAfterIt() {
        #expect(offered(.plays, on: date(2026, 10, 11)) == [.last3Days, .allTime])
    }

    @Test
    func playsOfferAWeekOnceItFits() {
        #expect(offered(.plays, on: date(2026, 10, 13)) == [.last3Days, .allTime])
        #expect(offered(.plays, on: date(2026, 10, 14)) == [.last3Days, .lastWeek, .allTime])
    }

    @Test
    func playsOfferAMonthOnceItFits() {
        #expect(offered(.plays, on: date(2026, 11, 6)).contains(.lastMonth))
        #expect(!offered(.plays, on: date(2026, 11, 5)).contains(.lastMonth))
    }

    @Test
    func playsNeverOfferTheLast24Hours() {
        #expect(!TrendsMetric.plays.isAvailable(.last24Hours, now: date(2028, 1, 1)))
    }

    @Test
    func playsOfferYearsOnlyOnceThereIsASecondOne() {
        #expect(!TrendsMetric.plays.isAvailable(.year2026, now: date(2026, 12, 31)))
        #expect(TrendsMetric.plays.isAvailable(.year2026, now: date(2027, 1, 2)))
        #expect(!TrendsMetric.plays.isAvailable(.year2025, now: date(2027, 1, 2)))
    }

    @Test
    func playsFallBackToEverythingUntilThereIsAWeek() {
        #expect(TrendsMetric.plays.fallbackInterval(now: date(2026, 10, 11)) == .allTime)
        #expect(TrendsMetric.plays.fallbackInterval(now: date(2026, 10, 20)) == .lastWeek)
    }

    @Test
    func playsNameTheirStart() {
        #expect(TrendsMetric.plays.label(for: .allTime) == "Desde 07/10/26")
        #expect(TrendsMetric.plays.label(for: .year2026) == "2026 (desde 07/10)")
        #expect(TrendsMetric.plays.label(for: .lastWeek) == nil)
        #expect(TrendsMetric.shares.label(for: .allTime) == nil)
    }
}
