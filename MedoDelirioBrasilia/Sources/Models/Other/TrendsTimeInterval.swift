//
//  TrendsTimeInterval.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 12/10/22.
//

import Foundation

enum TrendsTimeInterval: Int {

    case last24Hours
    case last3Days
    case lastWeek
    case lastMonth
    case year2026
    case year2025
    case year2024
    case year2023
    case year2022
    case allTime
    case last3Months
}

enum TrendsContentType {

    case sounds, songs
}

/// What a sound or song ranking counts.
enum TrendsMetric {

    case shares, plays

    /// The day the version that logs plays reached the App Store: it was approved a day
    /// after the server could take them (06/10). Every period that reaches further back
    /// would rank the same plays as "Desde 07/10/26", so the menu leaves it out.
    static let playsStartDate: Date = Calendar.current.date(
        from: DateComponents(year: 2026, month: 10, day: 7)
    )!

    /// Whether the period ranks something of its own for this metric.
    ///
    /// For plays, the last 24 hours is never offered: the app sends plays once a day,
    /// so that ranking would always be missing most of them. A recent period appears
    /// once it fits after `playsStartDate`, and the years once there is more than one.
    func isAvailable(_ interval: TrendsTimeInterval, now: Date = .now) -> Bool {
        guard self == .plays else { return true }

        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: Self.playsStartDate)

        func fitsAfterStart(days: Int) -> Bool {
            guard let periodStart = calendar.date(byAdding: .day, value: -days, to: now) else { return false }
            return calendar.startOfDay(for: periodStart) >= Self.playsStartDate
        }

        switch interval {
        case .last24Hours:
            return false
        case .last3Days:
            return fitsAfterStart(days: 3)
        case .lastWeek:
            return fitsAfterStart(days: 7)
        case .lastMonth:
            return fitsAfterStart(days: 30)
        case .last3Months:
            return fitsAfterStart(days: 90)
        case .year2026, .year2025, .year2024, .year2023, .year2022:
            guard let year = interval.year else { return false }
            return year >= startYear && calendar.component(.year, from: now) > startYear
        case .allTime:
            return true
        }
    }

    /// Where a ranking goes when it switches to this metric and its period isn't
    /// available: a week once there is one, everything before that.
    func fallbackInterval(now: Date = .now) -> TrendsTimeInterval {
        isAvailable(.lastWeek, now: now) ? .lastWeek : .allTime
    }

    /// A period name that differs from the usual one for this metric, like 2022's
    /// "(desde 21/06)".
    func label(for interval: TrendsTimeInterval) -> String? {
        guard self == .plays else { return nil }
        switch interval {
        case .allTime: return "Desde 07/10/26"
        case .year2026: return "2026 (desde 07/10)"
        default: return nil
        }
    }
}

extension TrendsTimeInterval {

    /// The year a yearly interval covers, `nil` for the rest.
    var year: Int? {
        switch self {
        case .year2026: 2026
        case .year2025: 2025
        case .year2024: 2024
        case .year2023: 2023
        case .year2022: 2022
        default: nil
        }
    }
}
