//
//  ChapterPreferences.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 31/07/26.
//

import Foundation

/// Single source of truth for whether chapters should be surfaced.
///
/// Read from views via `@AppStorage(ChapterPreferences.hiddenKey)` and from
/// non-view code — `EpisodePlayer` drives the system player's title — via
/// `isEnabled`.
enum ChapterPreferences {

    static let hiddenKey = "episodeChaptersHidden"

    /// Set from the chapter list's "Ocultar capítulos" action, cleared from Settings.
    static var isHidden: Bool {
        UserDefaults.standard.bool(forKey: hiddenKey)
    }

    /// Chapters are behind a feature flag *and* a user preference.
    static var isEnabled: Bool {
        FeatureFlag.isEnabled(.episodeChapters) && !isHidden
    }

    // MARK: - Chapter Coverage

    /// Earliest episode publication date covered by generated chapters, as
    /// `yyyy-MM-dd`. Written by `ChapterDownloadService` from `version.json`.
    static let coverageStartKey = "episodeChaptersCoverageStart"

    /// Used until the first successful sync — and as the `@AppStorage` default,
    /// so a fresh install shows a sensible date rather than a blank.
    static let defaultCoverageStart = "2026-01-01"

    /// Parses the wire format `yyyy-MM-dd`.
    ///
    /// POSIX locale so the fixed format parses on any device, but the *local*
    /// time zone on purpose: this is a calendar date, not an instant. Parsing it
    /// at UTC midnight and rendering it locally shifts it a day backwards for
    /// anyone west of Greenwich — `2026-01-01` displayed as 31/12/2025 in Brazil.
    /// Parsing at local midnight makes it render as itself everywhere.
    static let coverageFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func coverageDate(from raw: String) -> Date? {
        coverageFormatter.date(from: raw)
    }

    /// Resolved coverage start — the synced value when there is one, else the
    /// bundled default.
    static var coverageStart: Date {
        let raw = UserDefaults.standard.string(forKey: coverageStartKey) ?? defaultCoverageStart
        return coverageDate(from: raw)
            ?? coverageDate(from: defaultCoverageStart)
            ?? .distantPast
    }

    /// `coverageStart` rendered in the device's locale, for display in empty
    /// states and Settings.
    static var formattedCoverageStart: String {
        coverageStart.formatted(.dateTime.day().month(.wide).year())
    }
}
