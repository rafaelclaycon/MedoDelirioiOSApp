import Foundation
import SQLite

private typealias Expression = SQLite.Expression

// MARK: - Top Author Model

struct TopAuthorItem {
    let authorId: String
    let authorName: String
    let authorPhoto: String?
    let shareCount: Int
}

extension LocalDatabase {

    // MARK: - Personal Top Chart

    func getTopSoundsSharedByTheUser(_ limit: Int) throws -> [TopChartItem] {
        guard let firstDay2023 = "2024-01-01T00:00:00.000Z".iso8601withFractionalSeconds else { return [] }

        var result = [TopChartItem]()

        let content_id = Expression<String>("contentId")
        let content_type = Expression<Int>("contentType")

        let soundId = Expression<String>("id")
        let soundTitle = Expression<String>("title")
        let authorIdOnSounds = Expression<String>("authorId")

        let authorId = Expression<String>("id")
        let authorName = Expression<String>("name")

        let dateTime = Expression<Date>("dateTime")

        let contentCount = content_id.count
        for row in try db.prepare(
            userShareLog
                .join(soundTable, on: userShareLog[content_id] == soundTable[soundId])
                .join(author, on: soundTable[authorIdOnSounds] == author[authorId])
                .select(userShareLog[content_id], soundTable[soundTitle], soundTable[authorId], author[authorName], contentCount)
                .where(userShareLog[content_type] == 0 || userShareLog[content_type] == 2)
                .filter(dateTime > firstDay2023)
                .group(userShareLog[content_id])
                .order(contentCount.desc)
                .limit(limit)
        ) {
            result.append(
                TopChartItem(
                    id: "",
                    rankNumber: "",
                    contentId: row[content_id],
                    contentName: row[soundTable[soundTitle]],
                    contentAuthorId: row[soundTable[authorId]],
                    contentAuthorName: row[author[authorName]],
                    shareCount: row[contentCount]
                )
            )
        }
        return result
    }

    // MARK: - Audience Top Chart

    func getTop10SoundsSharedByTheAudience(for timeInterval: TrendsTimeInterval) throws -> [TopChartItem] {
        var result = [TopChartItem]()

        let content_id = Expression<String>("contentId")
        let content_type = Expression<Int>("contentType")
        let share_count = Expression<Int>("shareCount")
        let ranking_type = Expression<Int>("rankingType")

        let soundId = Expression<String>("id")
        let soundTitle = Expression<String>("title")
        let authorIdOnSounds = Expression<String>("authorId")

        let authorId = Expression<String>("id")
        let authorName = Expression<String>("name")

        let totalShareCount = share_count.sum
        for row in try db.prepare(
            audienceSharingStatistic
                .join(soundTable, on: audienceSharingStatistic[content_id] == soundTable[soundId])
                .join(author, on: soundTable[authorIdOnSounds] == author[authorId])
                .select(audienceSharingStatistic[content_id], soundTable[soundTitle], soundTable[authorId], author[authorName], totalShareCount)
                .where(audienceSharingStatistic[content_type] == 0)
                .where(audienceSharingStatistic[ranking_type] == timeInterval.rawValue)
                .group(audienceSharingStatistic[content_id])
                .order(totalShareCount.desc)
                .limit(10)
        ) {
            result.append(
                TopChartItem(
                    id: "",
                    rankNumber: "",
                    contentId: row[audienceSharingStatistic[content_id]],
                    contentName: row[soundTable[soundTitle]],
                    contentAuthorId: row[soundTable[authorId]],
                    contentAuthorName: row[author[authorName]],
                    shareCount: row[totalShareCount] ?? 0
                )
            )
        }
        return result
    }

    // MARK: - Personal Stats in a Date Range

    // Seu Mês and the year-end Retrospectiva. Sounds only, shared as audio or video, like
    // the personal ranking. `interval.end` is left out, so back-to-back months don't
    // count a share twice.

    func topSoundsSharedByTheUser(in interval: DateInterval, limit: Int) throws -> [TopChartItem] {
        let content_id = Expression<String>("contentId")
        let content_type = Expression<Int>("contentType")

        let soundId = Expression<String>("id")
        let soundTitle = Expression<String>("title")
        let authorIdOnSounds = Expression<String>("authorId")

        let authorId = Expression<String>("id")
        let authorName = Expression<String>("name")

        let dateTime = Expression<Date>("dateTime")

        let contentCount = content_id.count
        return try db.prepare(
            userShareLog
                .join(soundTable, on: userShareLog[content_id] == soundTable[soundId])
                .join(author, on: soundTable[authorIdOnSounds] == author[authorId])
                .select(userShareLog[content_id], soundTable[soundTitle], soundTable[authorId], author[authorName], contentCount)
                .where(userShareLog[content_type] == 0 || userShareLog[content_type] == 2)
                .filter(dateTime >= interval.start && dateTime < interval.end)
                .group(userShareLog[content_id])
                .order(contentCount.desc)
                .limit(limit)
        ).map { row in
            TopChartItem(
                id: "",
                rankNumber: "",
                contentId: row[content_id],
                contentName: row[soundTable[soundTitle]],
                contentAuthorId: row[soundTable[authorId]],
                contentAuthorName: row[author[authorName]],
                shareCount: row[contentCount]
            )
        }
    }

    /// Prefers an author with a photo, since the picture is the point of showing them.
    func topAuthorSharedByTheUser(in interval: DateInterval) throws -> TopAuthorItem? {
        let content_id = Expression<String>("contentId")
        let content_type = Expression<Int>("contentType")

        let soundId = Expression<String>("id")
        let authorIdOnSounds = Expression<String>("authorId")

        let authorId = Expression<String>("id")
        let authorName = Expression<String>("name")
        let authorPhoto = Expression<String?>("photo")

        let dateTime = Expression<Date>("dateTime")

        let contentCount = content_id.count
        let query = userShareLog
            .join(soundTable, on: userShareLog[content_id] == soundTable[soundId])
            .join(author, on: soundTable[authorIdOnSounds] == author[authorId])
            .select(author[authorId], author[authorName], author[authorPhoto], contentCount)
            .where(userShareLog[content_type] == 0 || userShareLog[content_type] == 2)
            .filter(dateTime >= interval.start && dateTime < interval.end)
            .group(author[authorId])
            .order(contentCount.desc)
            .limit(1)

        for withPhotoOnly in [true, false] {
            let filtered = withPhotoOnly
                ? query.filter(author[authorPhoto] != nil && author[authorPhoto] != "")
                : query
            for row in try db.prepare(filtered) {
                return TopAuthorItem(
                    authorId: row[author[authorId]],
                    authorName: row[author[authorName]],
                    authorPhoto: row[author[authorPhoto]],
                    shareCount: row[contentCount]
                )
            }
        }
        return nil
    }

    func shareDates(in interval: DateInterval) throws -> [Date] {
        let content_type = Expression<Int>("contentType")
        let date_time = Expression<Date>("dateTime")

        return try db.prepare(
            userShareLog
                .select(userShareLog[date_time])
                .where(userShareLog[content_type] == 0 || userShareLog[content_type] == 2)
                .filter(date_time >= interval.start && date_time < interval.end)
        ).map { $0[date_time] }
    }

    func sharedSoundsCount(in interval: DateInterval) -> Int {
        let content_id = Expression<String>("contentId")
        let content_type = Expression<Int>("contentType")
        let dateTime = Expression<Date>("dateTime")

        let query = userShareLog
            .where(content_type == 0 || content_type == 2)
            .filter(dateTime >= interval.start && dateTime < interval.end)

        return (try? db.scalar(query.select(content_id.distinct.count))) ?? 0
    }
}
