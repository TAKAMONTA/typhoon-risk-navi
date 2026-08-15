import XCTest
@testable import TyphoonRiskNavi

/// エリア別集約の純関数テスト。
/// 代表値 = 時間窓内の最頻レベル、同数なら高いレベル（防災文脈では過剰側に倒す）。
final class MoodAggregatorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func post(
        _ area: OkinawaArea, _ level: MoodLevel, minutesAgo: Double
    ) -> AreaMoodPost {
        AreaMoodPost(id: UUID().uuidString, area: area, level: level, phraseID: "L1_still_quiet",
                     createdAt: now.addingTimeInterval(-minutesAgo * 60))
    }

    /// 最頻レベルが代表値になる。
    func testModeWins() {
        let posts = [
            post(.naha, .stormy, minutesAgo: 10),
            post(.naha, .stormy, minutesAgo: 20),
            post(.naha, .calm, minutesAgo: 30),
        ]
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.naha]?.representativeLevel, .stormy)
        XCTAssertEqual(result[.naha]?.postCount, 3)
    }

    /// 同数のときは高いレベルに倒す。
    func testTieBreaksToHigherLevel() {
        let posts = [
            post(.miyako, .calm, minutesAgo: 10),
            post(.miyako, .violent, minutesAgo: 20),
        ]
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.miyako]?.representativeLevel, .violent)
    }

    /// 時間窓の境界: ちょうど3時間前（180分）は含み、181分前は除外する。
    func testWindowBoundary() {
        let boundary = [
            post(.daito, .violent, minutesAgo: 180),
            post(.daito, .calm, minutesAgo: 181),
        ]
        let result = MoodAggregator.summarize(posts: boundary, now: now)
        XCTAssertEqual(result[.daito]?.postCount, 1)
        XCTAssertEqual(result[.daito]?.representativeLevel, .violent)
    }

    /// 投稿ゼロのエリアも postCount 0・representativeLevel nil で全10件返る。
    func testAllAreasPresentEvenWithNoPosts() {
        let result = MoodAggregator.summarize(posts: [], now: now)
        XCTAssertEqual(result.count, OkinawaArea.allCases.count)
        for area in OkinawaArea.allCases {
            XCTAssertEqual(result[area]?.postCount, 0)
            XCTAssertNil(result[area]?.representativeLevel)
        }
    }

    /// 最頻値は「最も重いレベル」ではない。穏やかな投稿の多数派が、
    /// 少数の重い投稿に上書きされないことを固定する。
    func testModeWinsOverAMoreSevereMinority() {
        let posts = [
            post(.naha, .calm, minutesAgo: 10),
            post(.naha, .calm, minutesAgo: 20),
            post(.naha, .calm, minutesAgo: 30),
            post(.naha, .violent, minutesAgo: 40),
        ]
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.naha]?.representativeLevel, .calm)
        XCTAssertEqual(result[.naha]?.postCount, 4)
    }

    /// エリアをまたいで混ざらない。
    func testAreasAreIndependent() {
        let posts = [
            post(.naha, .violent, minutesAgo: 5),
            post(.ishigaki, .calm, minutesAgo: 5),
        ]
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.naha]?.representativeLevel, .violent)
        XCTAssertEqual(result[.ishigaki]?.representativeLevel, .calm)
        XCTAssertEqual(result[.kumejima]?.postCount, 0)
    }

    /// 端末時計より未来の createdAt（サーバー時刻とのずれ）も除外しない。
    /// 投稿直後の楽観的反映が時計ずれで消えると、投稿が失敗したように見えるため。
    func testFuturePostsAreIncluded() {
        let posts = [post(.naha, .stormy, minutesAgo: -1)]   // 1分未来
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.naha]?.postCount, 1)
    }
}
