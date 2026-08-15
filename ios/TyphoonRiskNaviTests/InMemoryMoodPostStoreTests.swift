import XCTest
@testable import TyphoonRiskNavi

/// テスト用 InMemory ストアの挙動を固定する（ViewModel テストの土台になるため）。
final class InMemoryMoodPostStoreTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFetchFiltersSortsAndLimits() async throws {
        let old = AreaMoodPost(id: "old", area: .naha, level: .calm, phraseID: "L1_still_quiet",
                               createdAt: now.addingTimeInterval(-7200))
        let newer = AreaMoodPost(id: "newer", area: .naha, level: .stormy, phraseID: "L3_staying_in",
                                 createdAt: now.addingTimeInterval(-60))
        let tooOld = AreaMoodPost(id: "tooOld", area: .naha, level: .calm, phraseID: "L1_as_usual",
                                  createdAt: now.addingTimeInterval(-20_000))
        let store = InMemoryMoodPostStore(posts: [old, newer, tooOld])

        let fetched = try await store.fetchPosts(since: now.addingTimeInterval(-10_800), limit: 10)
        XCTAssertEqual(fetched.map(\.id), ["newer", "old"])   // 新しい順・窓外は除外

        let limited = try await store.fetchPosts(since: now.addingTimeInterval(-10_800), limit: 1)
        XCTAssertEqual(limited.map(\.id), ["newer"])
    }

    func testSubmitAppendsWithInjectedClock() async throws {
        let store = InMemoryMoodPostStore(now: { self.now })
        let saved = try await store.submit(area: .miyako, level: .dangerous, phraseID: "L4_power_outage")
        XCTAssertEqual(saved.area, .miyako)
        XCTAssertEqual(saved.createdAt, now)
        XCTAssertEqual(store.posts.count, 1)
    }

    func testErrorsPropagate() async {
        struct Boom: Error {}
        let store = InMemoryMoodPostStore()
        store.fetchError = Boom()
        do {
            _ = try await store.fetchPosts(since: .distantPast, limit: 10)
            XCTFail("fetchError が伝播していない")
        } catch {}
        store.submitError = Boom()
        do {
            _ = try await store.submit(area: .naha, level: .calm, phraseID: "L1_still_quiet")
            XCTFail("submitError が伝播していない")
        } catch {}
    }

    /// スクショ用サンプルは全エリアに1件以上あり、phraseID がカタログで解決できる。
    func testScreenshotSamplesAreWellFormed() async throws {
        let store = InMemoryMoodPostStore.screenshotSamples(now: now)
        let posts = try await store.fetchPosts(since: now.addingTimeInterval(-MoodAggregator.window), limit: 200)
        let coveredAreas = Set(posts.map(\.area))
        XCTAssertEqual(coveredAreas, Set(OkinawaArea.allCases), "サンプルが全エリアを覆っていない")
        for post in posts {
            XCTAssertNotNil(MoodPhraseCatalog.phrase(for: post.phraseID),
                            "サンプルの phraseID \(post.phraseID) がカタログに無い")
            XCTAssertEqual(MoodPhraseCatalog.phrase(for: post.phraseID)?.level, post.level,
                           "サンプルの phraseID とレベルが食い違っている")
        }
    }
}
