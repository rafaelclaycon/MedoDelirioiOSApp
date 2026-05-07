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

    enum ShareCountStatServerExchangeResult: Equatable {

        case successful, noStatsToSend, failed(String)
    }
}
