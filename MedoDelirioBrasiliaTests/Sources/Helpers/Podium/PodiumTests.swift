@testable import MedoDelirio
import XCTest

class PodiumTests: XCTestCase {

    var apiClientStub: FakeAPIClient!
    var databaseStub: FakeLocalDatabase!
    var sut: Podium!

    override func setUp() {
        super.setUp()
        apiClientStub = .init()
        apiClientStub.serverPath = "https://example.com/api/"
        databaseStub = .init()
        sut = Podium(database: databaseStub, apiClient: apiClientStub)
    }

    override func tearDown() {
        sut = nil
        databaseStub = nil
        apiClientStub = nil
        super.tearDown()
    }

    func test_sendShareCountStatsToServer_whenNoPendingStats_shouldReturnNoStatsToSend() async {
        let result = await sut.sendShareCountStatsToServer()

        XCTAssertEqual(result, .noStatsToSend)
        XCTAssertTrue(databaseStub.markedShareLogIds.isEmpty)
        XCTAssertTrue(apiClientStub.shareCountStatsPosted.isEmpty)
    }

    func test_sendShareCountStatsToServer_whenAllPostsSucceed_shouldMarkAllSuccessfulLogsAsSent() async {
        databaseStub.pendingShareStats = [
            PendingShareCountStat(
                localLogId: "log-1",
                payload: ServerShareCountStat(installId: "i", contentId: "a", contentType: ContentType.sound.rawValue, shareCount: 1, dateTime: "2026-01-01T00:00:00.000Z")
            ),
            PendingShareCountStat(
                localLogId: "log-2",
                payload: ServerShareCountStat(installId: "i", contentId: "b", contentType: ContentType.song.rawValue, shareCount: 1, dateTime: "2026-01-01T00:00:01.000Z")
            )
        ]
        databaseStub.bundleIdLogs = [ServerShareBundleIdLog(bundleId: "com.test.app", count: 2)]

        let result = await sut.sendShareCountStatsToServer()

        XCTAssertEqual(result, .successful)
        XCTAssertEqual(Set(databaseStub.markedShareLogIds), Set(["log-1", "log-2"]))
        XCTAssertEqual(apiClientStub.shareCountStatsPosted.count, 2)
        XCTAssertEqual(apiClientStub.postedBundleIdLogs.count, 1)
    }

    func test_sendShareCountStatsToServer_whenSomePostsFail_shouldMarkOnlySuccessfulLogs() async {
        databaseStub.pendingShareStats = [
            PendingShareCountStat(
                localLogId: "log-1",
                payload: ServerShareCountStat(installId: "i", contentId: "a", contentType: ContentType.sound.rawValue, shareCount: 1, dateTime: "2026-01-01T00:00:00.000Z")
            ),
            PendingShareCountStat(
                localLogId: "log-2",
                payload: ServerShareCountStat(installId: "i", contentId: "b", contentType: ContentType.song.rawValue, shareCount: 1, dateTime: "2026-01-01T00:00:01.000Z")
            )
        ]
        apiClientStub.failShareCountPostAtIndexes = [1]

        let result = await sut.sendShareCountStatsToServer()

        guard case .failed = result else {
            return XCTFail("Expected failed result for partial send failure.")
        }
        XCTAssertEqual(databaseStub.markedShareLogIds, ["log-1"])
        XCTAssertEqual(apiClientStub.shareCountStatsPosted.count, 1)
        XCTAssertTrue(apiClientStub.postedBundleIdLogs.isEmpty)
    }

    func test_sendShareCountStatsToServer_whenBundlePostFails_shouldStillKeepMarkedShareLogs() async {
        databaseStub.pendingShareStats = [
            PendingShareCountStat(
                localLogId: "log-1",
                payload: ServerShareCountStat(installId: "i", contentId: "a", contentType: ContentType.sound.rawValue, shareCount: 1, dateTime: "2026-01-01T00:00:00.000Z")
            )
        ]
        databaseStub.bundleIdLogs = [ServerShareBundleIdLog(bundleId: "com.test.app", count: 1)]
        apiClientStub.shouldFailBundleIdPost = true

        let result = await sut.sendShareCountStatsToServer()

        guard case .failed = result else {
            return XCTFail("Expected failed result for bundle-id send failure.")
        }
        XCTAssertEqual(databaseStub.markedShareLogIds, ["log-1"])
        XCTAssertEqual(apiClientStub.shareCountStatsPosted.count, 1)
    }

    func test_contentTypeShareMapping_shouldMapSongAndSoundCorrectly() {
        XCTAssertEqual(ContentType.shareType(for: .song), .song)
        XCTAssertEqual(ContentType.shareType(for: .sound), .sound)
    }

    func test_contentTypeVideoShareMapping_shouldMapSongAndSoundCorrectly() {
        XCTAssertEqual(ContentType.videoShareType(for: .song), .videoFromSong)
        XCTAssertEqual(ContentType.videoShareType(for: .sound), .videoFromSound)
    }
}
