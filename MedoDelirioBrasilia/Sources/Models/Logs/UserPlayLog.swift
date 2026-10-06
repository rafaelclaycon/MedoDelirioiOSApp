//
//  UserPlayLog.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 06/10/26.
//

import Foundation

/// One play of a sound or song, as counted by `PlayDeduplicator` — a burst of re-taps on
/// the same content is a single row.
struct UserPlayLog: Hashable, Identifiable {

    /// Also the idempotency key on the server, so a batch that is re-sent because the
    /// local "sent" mark failed after the upload succeeded isn't counted twice.
    let id: String
    let contentId: String
    /// `ContentType.sound` or `.song`.
    let contentType: Int
    let dateTime: Date
    /// Started by "play all" / "play from here" advancing on its own rather than by a tap.
    /// Kept apart so rankings can leave out a whole folder played back to back.
    let isAutoplay: Bool
    var sentToServer: Bool

    init(
        id: String = UUID().uuidString,
        contentId: String,
        contentType: Int,
        dateTime: Date,
        isAutoplay: Bool,
        sentToServer: Bool = false
    ) {
        self.id = id
        self.contentId = contentId
        self.contentType = contentType
        self.dateTime = dateTime
        self.isAutoplay = isAutoplay
        self.sentToServer = sentToServer
    }
}
