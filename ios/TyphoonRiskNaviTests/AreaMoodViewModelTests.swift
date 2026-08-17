import XCTest
import CoreLocation
@testable import TyphoonRiskNavi

/// AreaMoodViewModel のテスト。ストアは InMemory、UserDefaults はテスト用スイート、時刻は固定注入。
@MainActor
final class AreaMoodViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "AreaMoodViewModelTests"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeViewModel(store: InMemoryMoodPostStore) -> AreaMoodViewModel {
        AreaMoodViewModel(
            store: store,
            rateLimiter: MoodPostRateLimiter(defaults: defaults),
            now: { self.now }
        )
    }

    func testRefreshPopulatesSummaries() async {
        let store = InMemoryMoodPostStore(posts: [
            AreaMoodPost(id: "1", area: .naha, level: .stormy, phraseID: "L3_staying_in",
                         createdAt: now.addingTimeInterval(-600)),
        ])
        let viewModel = makeViewModel(store: store)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.summaries[.naha]?.representativeLevel, .stormy)
        XCTAssertEqual(viewModel.summaries.count, OkinawaArea.allCases.count)
        XCTAssertEqual(viewModel.lastUpdated, now)
        XCTAssertFalse(viewModel.fetchFailed)
    }

    /// 取得失敗時は前回の結果を保持し、fetchFailed を立てる（無言で失敗させない）。
    func testFetchFailureKeepsPreviousResults() async {
        let store = InMemoryMoodPostStore(posts: [
            AreaMoodPost(id: "1", area: .miyako, level: .violent, phraseID: "L5_roaring_wind",
                         createdAt: now.addingTimeInterval(-60)),
        ])
        let viewModel = makeViewModel(store: store)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.summaries[.miyako]?.representativeLevel, .violent)

        struct Boom: Error {}
        store.fetchError = Boom()
        await viewModel.refresh()
        XCTAssertTrue(viewModel.fetchFailed)
        XCTAssertEqual(viewModel.summaries[.miyako]?.representativeLevel, .violent, "前回の結果が消えた")
    }

    /// 投稿成功で楽観的に反映され、レート制限が記録される。
    func testPostSuccessAppliesOptimistically() async {
        let store = InMemoryMoodPostStore(now: { self.now })
        let viewModel = makeViewModel(store: store)
        let succeeded = await viewModel.post(area: .daito, level: .dangerous, phraseID: "L4_cannot_go_out")
        XCTAssertTrue(succeeded)
        XCTAssertEqual(viewModel.summaries[.daito]?.representativeLevel, .dangerous)
        XCTAssertEqual(viewModel.summaries[.daito]?.postCount, 1)
        XCTAssertNil(viewModel.postError)
        XCTAssertNotNil(viewModel.postingBlockedReason, "投稿直後はレート制限がかかるはず")
        XCTAssertEqual(store.posts.count, 1, "成功したのにストアへ書かれていない")
    }

    /// 投稿の楽観的反映は既存のサマリーを消さず、新しい投稿を積み増す
    /// （新しい投稿だけで作り直すと、他エリアの直近の集約結果が消えてしまう）。
    func testPostMergesIntoExistingSummaries() async {
        let store = InMemoryMoodPostStore(posts: [
            AreaMoodPost(id: "1", area: .naha, level: .calm, phraseID: "L1_still_quiet",
                         createdAt: now.addingTimeInterval(-600)),
            AreaMoodPost(id: "2", area: .miyako, level: .stormy, phraseID: "L3_staying_in",
                         createdAt: now.addingTimeInterval(-600)),
        ], now: { self.now })
        let viewModel = makeViewModel(store: store)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.summaries[.naha]?.representativeLevel, .calm)
        XCTAssertEqual(viewModel.summaries[.miyako]?.representativeLevel, .stormy)

        let succeeded = await viewModel.post(area: .daito, level: .dangerous, phraseID: "L4_cannot_go_out")
        XCTAssertTrue(succeeded)
        XCTAssertEqual(viewModel.summaries[.daito]?.representativeLevel, .dangerous, "新しい投稿が反映されていない")
        XCTAssertEqual(viewModel.summaries[.naha]?.representativeLevel, .calm, "既存のサマリーが消えた")
        XCTAssertEqual(viewModel.summaries[.miyako]?.representativeLevel, .stormy, "既存のサマリーが消えた")
    }

    /// レート制限中は投稿がブロックされ、ストアに書かれない。
    func testPostBlockedByRateLimit() async {
        let store = InMemoryMoodPostStore(now: { self.now })
        let viewModel = makeViewModel(store: store)
        _ = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        let second = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_as_usual")
        XCTAssertFalse(second)
        XCTAssertNotNil(viewModel.postError)
        XCTAssertEqual(store.posts.count, 1, "ブロック中にストアへ書かれた")
    }

    /// 投稿失敗時はエラーを表示し、レート制限を記録しない（再送できるように）。
    func testPostFailureDoesNotRecordRateLimit() async {
        struct Boom: Error {}
        let store = InMemoryMoodPostStore(now: { self.now })
        store.submitError = Boom()
        let viewModel = makeViewModel(store: store)
        let succeeded = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        XCTAssertFalse(succeeded)
        XCTAssertNotNil(viewModel.postError)
        XCTAssertNil(viewModel.postingBlockedReason, "失敗したのにレート制限が記録された")
    }

    /// 座標→エリア判定は最寄り自治体経由（那覇市役所付近 → 那覇、石垣市役所付近 → 石垣）。
    func testAreaForCoordinate() {
        let naha = CLLocationCoordinate2D(latitude: 26.2124, longitude: 127.6809)
        XCTAssertEqual(AreaMoodViewModel.area(for: naha), .naha)
        let ishigaki = CLLocationCoordinate2D(latitude: 24.3444, longitude: 124.1572)
        XCTAssertEqual(AreaMoodViewModel.area(for: ishigaki), .ishigaki)
    }
}
