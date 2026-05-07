import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    // MARK: - User statistics to be sent to the server

    func pendingShareStatsNotSentToServer() throws -> [PendingShareCountStat] {
        var result = [PendingShareCountStat]()

        let id = Expression<String>("id")
        let install_id = Expression<String>("installId")
        let content_id = Expression<String>("contentId")
        let content_type = Expression<Int>("contentType")
        let sent_to_server = Expression<Bool>("sentToServer")
        let date_time = Expression<Date>("dateTime")

        for row in try db.prepare(
            userShareLog
                .select(id, install_id, content_id, content_type, date_time)
                .where(sent_to_server == false)
        ) {
            result.append(
                PendingShareCountStat(
                    localLogId: row[id],
                    payload: ServerShareCountStat(
                        installId: row[install_id],
                        contentId: row[content_id],
                        contentType: row[content_type],
                        shareCount: 1,
                        dateTime: row[date_time].iso8601withFractionalSeconds
                    )
                )
            )
        }
        return result
    }

    func userShareStatsNotSentToServer() throws -> [ServerShareCountStat] {
        try pendingShareStatsNotSentToServer().map(\.payload)
    }

    func getUniqueBundleIdsThatWereSharedTo() throws -> [ServerShareBundleIdLog] {
        var result = [ServerShareBundleIdLog]()
        
        let destination_bundle_id = Expression<String>("destinationBundleId")
        let sent_to_server = Expression<Bool>("sentToServer")
        
        let idCount = destination_bundle_id.count
        for row in try db.prepare(userShareLog
                                      .select(destination_bundle_id,idCount)
                                      .where(sent_to_server == false)
                                      .group(destination_bundle_id)
                                      .order(idCount.desc)) {
            result.append(ServerShareBundleIdLog(bundleId: row[destination_bundle_id], count: row[idCount]))
        }
        return result
    }
    
    // MARK: - Audience statistics from the server
    
    func insert(audienceStat newAudienceStat: AudienceShareCountStat) throws {
        let insert = try audienceSharingStatistic.insert(newAudienceStat)
        try db.run(insert)
    }
    
    func getAudienceSharingStatCount() throws -> Int {
        try db.scalar(audienceSharingStatistic.count)
    }
    
    func clearAudienceSharingStatisticTable() throws {
        try db.run(audienceSharingStatistic.delete())
    }
}
