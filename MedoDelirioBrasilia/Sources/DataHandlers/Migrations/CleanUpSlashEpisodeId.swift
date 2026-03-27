//
//  CleanUpSlashEpisodeId.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/03/26.
//

import Foundation
import SQLiteMigrationManager
import SQLite

/// Removes the corrupted episode row with id "/" and all associated state.
///
/// 153 episodes (Mar–Dec 2020) had WordPress-style GUIDs
/// (`http://www.central3.com.br/?p=XXXXX`) whose `lastPathComponent` resolved
/// to "/", causing every one of them to collide on the same primary key.
/// After `parseEpisodeId` is fixed, the next feed sync will insert them with
/// correct IDs; this migration just cleans up the leftover bad row.
struct CleanUpSlashEpisodeId: Migration {

    var version: Int64 = 2026_03_21_12_00_00

    func migrateDatabase(_ db: Connection) throws {
        let badId = "/"

        try db.run("DELETE FROM podcastEpisode WHERE id = ?", badId)
        try db.run("DELETE FROM episodeFavorite WHERE episodeId = ?", badId)
        try db.run("DELETE FROM episodePlayed WHERE episodeId = ?", badId)
        try db.run("DELETE FROM episodeProgress WHERE episodeId = ?", badId)
        try db.run("DELETE FROM episodeBookmark WHERE episodeId = ?", badId)
        try db.run("DELETE FROM episodeListenLog WHERE episodeId = ?", badId)

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let orphanedMP3 = documentsURL
            .appendingPathComponent(InternalFolderNames.downloadedEpisodes)
            .appendingPathComponent("_.mp3")
        try? FileManager.default.removeItem(at: orphanedMP3)
    }
}
