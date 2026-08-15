import XCTest
@testable import TyphoonRiskNavi

/// 連投制限（10分に1回）のテスト。UserDefaults はテスト用スイートを注入する。
final class MoodPostRateLimiterTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "MoodPostRateLimiterTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testCanPostWhenNeverPosted() {
        let limiter = MoodPostRateLimiter(defaults: defaults)
        XCTAssertTrue(limiter.canPost(now: Date()))
        XCTAssertEqual(limiter.remainingSeconds(now: Date()), 0)
    }

    func testBlockedJustAfterPosting() {
        let limiter = MoodPostRateLimiter(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        limiter.recordPost(now: now)
        XCTAssertFalse(limiter.canPost(now: now.addingTimeInterval(1)))
        XCTAssertEqual(limiter.remainingSeconds(now: now.addingTimeInterval(60)), 540, accuracy: 0.5)
    }

    /// 10分ちょうどで解除される。
    func testUnblockedAtExactlyTenMinutes() {
        let limiter = MoodPostRateLimiter(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        limiter.recordPost(now: now)
        XCTAssertFalse(limiter.canPost(now: now.addingTimeInterval(599)))
        XCTAssertTrue(limiter.canPost(now: now.addingTimeInterval(600)))
    }

    /// interval を注入できる（テストや将来の調整用）。
    func testCustomInterval() {
        let limiter = MoodPostRateLimiter(defaults: defaults, interval: 60)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        limiter.recordPost(now: now)
        XCTAssertFalse(limiter.canPost(now: now.addingTimeInterval(30)))
        XCTAssertTrue(limiter.canPost(now: now.addingTimeInterval(60)))
    }
}
