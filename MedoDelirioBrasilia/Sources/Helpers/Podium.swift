//
//  Podium.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 08/06/22.
//

import Foundation

class Podium {

    static let shared = Podium(database: LocalDatabase.shared, apiClient: APIClient.shared)

    private let database: LocalDatabaseProtocol
    private let apiClient: any APIClientProtocol

    init(
        database: LocalDatabaseProtocol,
        apiClient: some APIClientProtocol
    ) {
        self.database = database
        self.apiClient = apiClient
    }
    
    func top10SoundsSharedByTheUser() -> [TopChartItem]? {
        do {
            var items = try database.getTopSoundsSharedByTheUser(10)
            for i in 0..<items.count {
                items[i].id = UUID().uuidString
                items[i].rankNumber = "\(i + 1)"
            }
            return items
        } catch {
            print(error)
            return nil
        }
    }

    func sendShareCountStatsToServer() async -> ShareCountStatServerExchangeResult {
        guard await apiClient.serverIsAvailable() else { return .failed("Servidor indisponível.") }

        // Prepare local stats to be sent
        let pendingStats: [PendingShareCountStat]
        let bundleIdLogs: [ServerShareBundleIdLog]
        do {
            pendingStats = try database.pendingShareStatsNotSentToServer()
            bundleIdLogs = try database.getUniqueBundleIdsThatWereSharedTo()
        } catch {
            return .failed("Falha carregando estatísticas locais de compartilhamento.")
        }

        guard !pendingStats.isEmpty else {
            return .noStatsToSend
        }

        // Send them and keep track of successes only.
        var successfulLogIds = [String]()
        var failedStats = [ServerShareCountStat]()
        for pending in pendingStats {
            do {
                try await self.apiClient.post(shareCountStat: pending.payload)
                successfulLogIds.append(pending.localLogId)
            } catch {
                print("Sending of \(pending.payload) failed: \(error.localizedDescription)")
                failedStats.append(pending.payload)
            }
        }

        if !successfulLogIds.isEmpty {
            do {
                try self.database.markUserShareLogsAsSent(logIds: successfulLogIds)
            } catch {
                return .failed("Falha ao marcar compartilhamentos enviados localmente.")
            }
        }

        if !failedStats.isEmpty {
            return .failed("Falha ao enviar \(failedStats.count) compartilhamentos.")
        }

        // Send bundles IDs as well (independent from share-log sent markers).
        let bundleIdUrl = URL(string: apiClient.serverPath + "v1/shared-to-bundle-id")!
        for log in bundleIdLogs {
            do {
                try await apiClient.post(to: bundleIdUrl, body: log)
            } catch {
                return .failed("Sending of \(log) failed.")
            }
        }

        return .successful
    }
    
    func cleanAudienceSharingStatisticTableToReceiveUpdatedData() {
        try? self.database.clearAudienceSharingStatisticTable()
    }

    /// Plays per request. Comfortably inside the server's body limit for the route
    /// (`api/v4/play-logs`), while a week of heavy use still goes in a request or two.
    static let playLogBatchSize = 250

    /// A run stops after this many batches and leaves the rest for the next day, so
    /// one launch never turns into an open-ended upload.
    static let maxPlayLogBatchesPerRun = 20

    /// Uploads unsent plays in batches, oldest first.
    ///
    /// Independent from `sendShareCountStatsToServer()` so a failure on either side
    /// never holds up the other. A batch the server accepted but that couldn't be marked
    /// as sent locally is simply sent again next time; the server ignores play IDs it
    /// already has.
    func sendPlayLogsToServer() async -> PlayLogServerExchangeResult {
        var sentCount = 0

        for _ in 0..<Self.maxPlayLogBatchesPerRun {
            let pendingLogs: [UserPlayLog]
            do {
                pendingLogs = try database.pendingPlayLogsNotSentToServer(limit: Self.playLogBatchSize)
            } catch {
                return .failed("Falha carregando reproduções locais.")
            }

            guard !pendingLogs.isEmpty else { break }

            // Checked only once there is something to send, so a day with no plays
            // doesn't cost a status-check round trip.
            if sentCount == 0 {
                guard await apiClient.serverIsAvailable() else { return .failed("Servidor indisponível.") }
            }

            let batch = ServerPlayLogBatch(
                installId: AppPersistentMemory.shared.customInstallId,
                appVersion: Versioneer.appVersion,
                plays: pendingLogs.map {
                    ServerPlayLog(
                        id: $0.id,
                        contentId: $0.contentId,
                        dateTime: $0.dateTime.iso8601withFractionalSeconds,
                        isAutoplay: $0.isAutoplay
                    )
                }
            )

            do {
                let url = URL(string: apiClient.serverPath + "v4/play-logs")!
                try await apiClient.post(to: url, body: batch)
            } catch {
                return .failed("Falha ao enviar \(pendingLogs.count) reproduções.")
            }

            do {
                try database.markUserPlayLogsAsSent(logIds: pendingLogs.map(\.id))
            } catch {
                return .failed("Falha ao marcar reproduções enviadas localmente.")
            }

            sentCount += pendingLogs.count

            // A short batch means the queue just ran dry; no need to ask again.
            if pendingLogs.count < Self.playLogBatchSize { break }
        }

        return sentCount == 0 ? .noLogsToSend : .successful
    }

    enum ShareCountStatServerExchangeResult: Equatable {

        case successful, noStatsToSend, failed(String)
    }

    enum PlayLogServerExchangeResult: Equatable {

        case successful, noLogsToSend, failed(String)
    }
}
