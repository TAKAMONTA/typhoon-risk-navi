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
        let boundary = AreaMoodPost(id: "boundary", area: .naha, level: .calm, phraseID: "L1_gentle_wind",
                                    createdAt: now.addingTimeInterval(-10_800))
        let tooOld = AreaMoodPost(id: "tooOld", area: .naha, level: .calm, phraseID: "L1_as_usual",
                                  createdAt: now.addingTimeInterval(-20_000))
        let store = InMemoryMoodPostStore(posts: [old, newer, boundary, tooOld])

        let fetched = try await store.fetchPosts(since: now.addingTimeInterval(-10_800), limit: 10)
        // 新しい順・窓外は除外・since ちょうど（境界）は含む
        XCTAssertEqual(fetched.map(\.id), ["newer", "old", "boundary"])

        let limited = try await store.fetchPosts(since: now.addingTimeInterval(-10_800), limit: 1)
        XCTAssertEqual(limited.map(\.id), ["newer"])
    }

    func testSubmitAppendsWithInjectedClock() async throws {
        let store = InMemoryMoodPostStore(now: { self.now })
        let saved = try await store.submit(area: .miyako, level: .dangerous, phraseID: "L4_power_outage")
        XCTAssertEqual(saved.area, .miyako)
        XCTAssertEqual(saved.level, .dangerous)          // level 引数が無視されていないこと
        XCTAssertEqual(saved.phraseID, "L4_power_outage") // phraseID 引数が無視されていないこと
        XCTAssertEqual(saved.createdAt, now)
        XCTAssertEqual(store.posts.count, 1)
        XCTAssertEqual(store.posts, [saved])   // 返り値と保存物が同一であることを固定
        XCTAssertFalse(saved.id.isEmpty)       // id が空や定数でないこと
    }

    /// submit を2回呼ぶと異なる id が発行される。同一の非空 id を返し続ける実装は、
    /// Identifiable な AreaMoodPost を ForEach で使う際に重複 id として破綻する。
    func testSubmitTwiceProducesDifferentIDs() async throws {
        let store = InMemoryMoodPostStore(now: { self.now })
        let first = try await store.submit(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        let second = try await store.submit(area: .naha, level: .calm, phraseID: "L1_as_usual")
        XCTAssertNotEqual(first.id, second.id, "2回の submit が同じ id を返した")
        XCTAssertEqual(store.posts.count, 2)
    }

    func testErrorsPropagate() async {
        struct Boom: Error {}
        let store = InMemoryMoodPostStore()
        store.fetchError = Boom()
        do {
            _ = try await store.fetchPosts(since: .distantPast, limit: 10)
            XCTFail("fetchError が伝播していない")
        } catch {
            XCTAssertTrue(error is Boom)
        }
        store.submitError = Boom()
        do {
            _ = try await store.submit(area: .naha, level: .calm, phraseID: "L1_still_quiet")
            XCTFail("submitError が伝播していない")
        } catch {
            XCTAssertTrue(error is Boom)
        }
    }

    /// screenshotSamples は渡された時計をストア自身にも注入する。
    /// 注入し忘れると、固定時刻のフィクスチャと実時刻の投稿が混ざる。
    func testScreenshotSamplesInjectTheClockIntoTheStore() async throws {
        let store = InMemoryMoodPostStore.screenshotSamples(now: now)
        let saved = try await store.submit(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        XCTAssertEqual(saved.createdAt, now)
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
