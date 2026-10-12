//
//  TranscriptPreferences.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation

/// Whether the user has switched transcripts off, as opposed to simply not having
/// downloaded them yet. Off means no downloads, no syncing and no invitations to
/// download, except in Share Clip, where picking a clip by its text is the main
/// reason to have them.
///
/// Read from views via `@AppStorage(TranscriptPreferences.disabledKey)`, and from
/// non-view code via `isDisabled`. Turned on and off through
/// `TranscriptDownloadService`, which also deletes what's downloaded.
enum TranscriptPreferences {

    static let disabledKey = "episodeTranscriptsDisabled"

    static var isDisabled: Bool {
        UserDefaults.standard.bool(forKey: disabledKey)
    }

    static var isEnabled: Bool {
        !isDisabled
    }
}
