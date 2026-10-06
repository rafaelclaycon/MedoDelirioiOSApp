//
//  ServerStatsAndLogs.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 02/06/22.
//

import Foundation

/// Logs sent to and from the server to generate audience statistics.
struct ServerShareCountStat: Hashable, Codable {

    var installId: String
    var contentId: String
    var contentType: Int
    var shareCount: Int
    var dateTime: String
}

/// The client receives a ServerShareCountStat from the server and transforms it into this for local persistance.
struct AudienceShareCountStat: Hashable, Codable {

    var contentId: String
    var contentType: Int
    var shareCount: Int
    var rankingType: Int
}

/// Sent to the server. Goal: satisfy the developer's curiosity.
struct ServerShareDestinationStat: Hashable, Codable {

    var installId: String
    var whatsAppCount: Int
    var telegramCount: Int
    var otherCount: Int
}

/// Sent to the server. Goal: understand usage trends.
struct ServerShareBundleIdLog: Hashable, Codable {

    var bundleId: String
    var count: Int
}

/// Local upload unit that links a pending user-share log row to server payload.
struct PendingShareCountStat: Hashable {

    let localLogId: String
    let payload: ServerShareCountStat
}

/// Sent to the server in batches. Goal: know what people listen to, not only what they share.
///
/// The install ID and app version go once per batch rather than on every play. The version
/// is there so the server can tell apart data counted under different dedupe rules.
struct ServerPlayLogBatch: Hashable, Codable {

    var installId: String
    var appVersion: String
    var plays: [ServerPlayLog]
}

struct ServerPlayLog: Hashable, Codable {

    /// The local log's ID, which the server uses to ignore a play it already has.
    var id: String
    var contentId: String
    var dateTime: String
    var isAutoplay: Bool
}
