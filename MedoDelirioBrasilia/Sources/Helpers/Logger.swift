//
//  Logger.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 28/05/22.
//

import UIKit

internal protocol LoggerProtocol {

    func logShared(
        _ type: ContentType,
        contentId: String,
        destination: ShareDestination,
        destinationBundleId: String
    )

    func updateError(_ description: String, updateEventId: String)
    func updateError(_ description: String)

    func updateSuccess(_ description: String, updateEventId: String)
    func updateSuccess(_ description: String)
}

class Logger: LoggerProtocol {

    static let shared = Logger()

    // MARK: - Functions

    func logShared(
        _ type: ContentType,
        contentId: String,
        destination: ShareDestination,
        destinationBundleId: String
    ) {
        let shareLog = UserShareLog(
            installId: AppPersistentMemory.shared.customInstallId,
            contentId: contentId,
            contentType: type.rawValue,
            dateTime: .now,
            destination: destination.rawValue,
            destinationBundleId: destinationBundleId,
            sentToServer: false
        )
        try? LocalDatabase.shared.insert(userShareLog: shareLog)
    }

    /// Main-actor isolated because the deduplicator's memory is shared by every screen
    /// that plays content, and playback only ever starts there.
    @MainActor private var playDeduplicator = PlayDeduplicator()

    /// Records a play once it has actually started. Re-taps on the same content in quick
    /// succession are folded into one play (see `PlayDeduplicator`).
    @MainActor
    func logPlayed(_ content: AnyEquatableMedoContent, isAutoplay: Bool = false) {
        guard let contentType = ContentType.shareType(for: content.type) else { return }

        let now = Date.now
        guard playDeduplicator.shouldCount(contentId: content.id, at: now) else { return }

        let playLog = UserPlayLog(
            contentId: content.id,
            contentType: contentType.rawValue,
            dateTime: now,
            isAutoplay: isAutoplay
        )
        try? LocalDatabase.shared.insert(userPlayLog: playLog)
    }

    func shareCountStatsForServer() -> [ServerShareCountStat]? {
        guard 
            let items = try? LocalDatabase.shared.userShareStatsNotSentToServer(),
            items.count > 0
        else { return nil }
        return items
    }

    func uniqueBundleIdsForServer() -> [ServerShareBundleIdLog]? {
        guard
            let items = try? LocalDatabase.shared.getUniqueBundleIdsThatWereSharedTo(),
            items.count > 0
        else { return nil }
        return items
    }

    func logNetworkCall(
        callType: Int,
        requestUrl: String,
        requestBody: String?,
        response: String,
        wasSuccessful: Bool
    ) {
        let log = NetworkCallLog(
            callType: callType,
            requestBody: requestBody ?? "",
            response: response,
            dateTime: Date(),
            wasSuccessful: wasSuccessful
        )
        try? LocalDatabase.shared.insert(networkCallLog: log)
    }

    func updateError(
        _ description: String,
        updateEventId: String
    ) {
        let syncLog = SyncLog(
            logType: .error,
            description: description,
            updateEventId: updateEventId
        )
        LocalDatabase.shared.insert(syncLog: syncLog)
    }

    func updateError(
        _ description: String
    ) {
        let syncLog = SyncLog(
            logType: .error,
            description: description,
            updateEventId: ""
        )
        LocalDatabase.shared.insert(syncLog: syncLog)
    }

    func updateSuccess(
        _ description: String,
        updateEventId: String
    ) {
        let syncLog = SyncLog(
            logType: .success,
            description: description,
            updateEventId: updateEventId
        )
        LocalDatabase.shared.insert(syncLog: syncLog)
    }

    func updateSuccess(
        _ description: String
    ) {
        let syncLog = SyncLog(
            logType: .success,
            description: description,
            updateEventId: ""
        )
        LocalDatabase.shared.insert(syncLog: syncLog)
    }
}
