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
}
