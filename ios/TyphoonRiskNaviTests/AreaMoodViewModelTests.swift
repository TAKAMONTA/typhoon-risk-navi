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

    private func makeViewModel(
        store: MoodPostStore,
        refreshInterval: TimeInterval = AreaMoodViewModel.defaultRefreshInterval
    ) -> AreaMoodViewModel {
        AreaMoodViewModel(
            store: store,
            rateLimiter: MoodPostRateLimiter(defaults: defaults),
            now: { self.now },
            refreshInterval: refreshInterval
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
        XCTAssertEqual(viewModel.recentPosts.count, 1, "失敗時に recentPosts が消えた")
        XCTAssertEqual(viewModel.lastUpdated, now, "失敗なのに lastUpdated が更新された")
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
        XCTAssertNil(viewModel.lastUpdated, "post() は取得成功時刻ではないので lastUpdated を進めてはいけない（「更新」ラベルの意味が壊れる）")
        XCTAssertTrue(viewModel.hasEverShownData, "投稿成功後もグリッドが redacted のままになってはいけない")
    }

    /// fetch 失敗のまま post だけ成功する組み合わせ。lastUpdated と hasEverShownData を混同すると、
    /// 取得失敗バナーと「更新 HH:mm」ラベルが同時に出てしまう（レビューで指摘された矛盾）の回帰防止。
    func testPostSuccessAfterFetchFailureEndsFirstLoadWithoutLastUpdated() async {
        struct Boom: Error {}
        let store = InMemoryMoodPostStore(now: { self.now })
        store.fetchError = Boom()
        let viewModel = makeViewModel(store: store)

        await viewModel.refresh()
        XCTAssertTrue(viewModel.fetchFailed)
        XCTAssertNil(viewModel.lastUpdated)
        XCTAssertFalse(viewModel.hasEverShownData, "取得が一度も成功していないのに first load を抜けた")

        let succeeded = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        XCTAssertTrue(succeeded)
        XCTAssertTrue(viewModel.hasEverShownData, "投稿成功後もグリッドが redacted のままになってはいけない")
        XCTAssertNil(viewModel.lastUpdated, "取得は一度も成功していないので「更新」ラベルを出してはいけない")
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
        // ブロック理由は postingBlockedReason だけで表現する（postError にはコピーしない）。
        // postError にもコピーすると @Published 化した意味が消え、シートの表示が固まってしまう。
        XCTAssertNotNil(viewModel.postingBlockedReason)
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

    /// stopAutoRefresh() の後に取得が走らないこと。
    /// Task.sleep のキャンセルを try? で飲むと、停止直後に1回だけ取得が走ってしまう。
    func testStopAutoRefreshDoesNotTriggerAnotherFetch() async throws {
        struct Boom: Error {}
        let store = InMemoryMoodPostStore(now: { self.now })
        // 間隔を十分長くとり、スケジュールされた refresh が一度も発火しない状態にする。
        // こうすると「sleep のキャンセルを try? が飲んで refresh が走る」バグだけを検出できる。
        let viewModel = makeViewModel(store: store, refreshInterval: 10)
        viewModel.startAutoRefresh()
        try await Task.sleep(nanoseconds: 50_000_000)
        store.fetchError = Boom()
        viewModel.stopAutoRefresh()          // バグがあるとここで1回取得が走る
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(viewModel.fetchFailed, "停止後に取得が走った")
    }

    /// 座標→エリア判定は最寄り自治体経由（那覇市役所付近 → 那覇、石垣市役所付近 → 石垣）。
    /// 沖縄県外の座標では距離キャップにより nil を返す（東京付近）。
    func testAreaForCoordinate() {
        let naha = CLLocationCoordinate2D(latitude: 26.2124, longitude: 127.6809)
        XCTAssertEqual(AreaMoodViewModel.area(for: naha), .naha)
        let ishigaki = CLLocationCoordinate2D(latitude: 24.3444, longitude: 124.1572)
        XCTAssertEqual(AreaMoodViewModel.area(for: ishigaki), .ishigaki)
        // 沖縄から離れた座標(例: 東京)は、最寄りの自治体があっても遠すぎるため nil を返す
        // (県外ユーザーに沖縄のエリアが誤って自動選択されるのを防ぐ)。
        let tokyo = CLLocationCoordinate2D(latitude: 35.68, longitude: 139.77)
        XCTAssertNil(AreaMoodViewModel.area(for: tokyo), "沖縄県外の座標はエリアを返してはいけない")
    }

    // MARK: - 再入防止ガード（過去の fix round で追加された回帰防止）

    /// refresh() は多重実行を防ぐ。防がないと、後から発火した取得の結果を先に発火していた
    /// 取得が後追いで上書きし、lastUpdated が巻き戻る恐れがある。
    func testConcurrentRefreshIsRejectedWhileFirstIsInFlight() async {
        let store = BlockingMoodPostStore()
        let viewModel = makeViewModel(store: store)

        let taskA = Task { await viewModel.refresh() }
        await store.waitUntilFetchStarted()
        XCTAssertEqual(store.fetchCallCount, 1)
        XCTAssertTrue(viewModel.isLoading)

        let taskB = Task { await viewModel.refresh() }
        store.releaseAllFetches()
        await taskA.value
        await taskB.value

        XCTAssertEqual(store.fetchCallCount, 1, "多重実行ガードが効いておらず fetchPosts が2回呼ばれた")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.fetchFailed)
        XCTAssertEqual(viewModel.lastUpdated, now)
    }

    /// post() は多重実行を防ぐ。防がないと、1件目がレート制限を記録する前に2件目がすり抜け、
    /// 10分に1回の連投制限をバイパスできてしまう（シートを閉じて開き直しての連投）。
    func testConcurrentPostIsRejectedWhileFirstIsInFlight() async {
        let store = BlockingMoodPostStore()
        let viewModel = makeViewModel(store: store)

        let taskA = Task { await viewModel.post(area: .naha, level: .calm, phraseID: "L1_still_quiet") }
        await store.waitUntilSubmitStarted()
        XCTAssertEqual(store.submitCallCount, 1)

        let taskB = Task { await viewModel.post(area: .naha, level: .calm, phraseID: "L1_as_usual") }
        store.releaseAllSubmits()
        let firstResult = await taskA.value
        let secondResult = await taskB.value

        XCTAssertTrue(firstResult)
        XCTAssertFalse(secondResult, "多重送信ガードが効いておらず2件目の post が受理された")
        XCTAssertEqual(store.submitCallCount, 1, "多重送信ガードが効いておらず submit が2回呼ばれた")
    }

    // MARK: - 直近のクリーンアップで入った挙動変更

    /// 投稿の楽観的反映は id でマージされる。サーバー側が自分の投稿を反映するようになった後の
    /// refresh() で、二重計上（同じ id が2件になる）が起きないことを固定する。
    func testOptimisticPostMergesWithoutDuplicationWhenServerReturnsIt() async {
        let store = EventuallyConsistentMoodPostStore()
        store.now = { self.now }
        let viewModel = makeViewModel(store: store)

        let succeeded = await viewModel.post(area: .naha, level: .stormy, phraseID: "L3_staying_in")
        XCTAssertTrue(succeeded)
        guard let submittedID = viewModel.recentPosts.first?.id else {
            return XCTFail("楽観的反映された投稿が見つからない")
        }

        // サーバー側にも自分の投稿が反映されるようになった。
        store.fetchResult = [
            AreaMoodPost(id: submittedID, area: .naha, level: .stormy, phraseID: "L3_staying_in", createdAt: now),
        ]
        await viewModel.refresh()

        XCTAssertEqual(viewModel.recentPosts.filter { $0.id == submittedID }.count, 1, "同じ id の投稿が重複した")
        XCTAssertEqual(viewModel.summaries[.naha]?.postCount, 1)
    }

    /// サーバーがまだ自分の投稿を返さない（結果整合性）場合でも、楽観的に反映した投稿は
    /// refresh() で消えない。
    func testOptimisticPostSurvivesWhenServerDoesNotYetReturnIt() async {
        let store = EventuallyConsistentMoodPostStore()
        store.now = { self.now }
        let viewModel = makeViewModel(store: store)

        let succeeded = await viewModel.post(area: .naha, level: .stormy, phraseID: "L3_staying_in")
        XCTAssertTrue(succeeded)
        guard let submittedID = viewModel.recentPosts.first?.id else {
            return XCTFail("楽観的反映された投稿が見つからない")
        }

        store.fetchResult = []   // サーバーにまだ反映されていない
        await viewModel.refresh()

        XCTAssertEqual(viewModel.recentPosts.map(\.id), [submittedID], "楽観的反映が refresh() で消えた")
        XCTAssertEqual(viewModel.summaries[.naha]?.postCount, 1)
    }

    /// refresh() は CancellationError を取得失敗として扱わない（タブ切り替え等でのキャンセルが
    /// 誤って「更新できませんでした」バナーを出さないため）。一方でキャンセルでない一般エラーは
    /// 従来通り fetchFailed を立てる（キャンセル判定が広すぎて全エラーを飲み込んでいないことの対照）。
    func testCancellationIsNotTreatedAsFetchFailureButGenuineErrorIs() async {
        let cancelledStore = InMemoryMoodPostStore(now: { self.now })
        cancelledStore.fetchError = CancellationError()
        let cancelledViewModel = makeViewModel(store: cancelledStore)
        await cancelledViewModel.refresh()
        XCTAssertFalse(cancelledViewModel.fetchFailed, "キャンセルが取得失敗として扱われた")

        struct Boom: Error {}
        let boomStore = InMemoryMoodPostStore(now: { self.now })
        boomStore.fetchError = Boom()
        let boomViewModel = makeViewModel(store: boomStore)
        await boomViewModel.refresh()
        XCTAssertTrue(boomViewModel.fetchFailed, "一般エラーがキャンセル扱いで握りつぶされた")
    }

    /// postingBlockedReason は republish される。投稿時点でブロック理由をスナップショットしたまま
    /// 固まっていないか、時計を進めた refresh() の後に確認する。
    func testPostingBlockedReasonReflectsInjectedClockNotAStaleSnapshot() async {
        var currentTime = now
        let store = InMemoryMoodPostStore(now: { currentTime })
        let viewModel = AreaMoodViewModel(
            store: store,
            rateLimiter: MoodPostRateLimiter(defaults: defaults),
            now: { currentTime },
            refreshInterval: AreaMoodViewModel.defaultRefreshInterval
        )

        let succeeded = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        XCTAssertTrue(succeeded)
        XCTAssertNotNil(viewModel.postingBlockedReason, "投稿直後はブロックされているはず")

        // レート制限の窓（10分）を過ぎるまで時計を進める。
        currentTime = now.addingTimeInterval(MoodPostRateLimiter.defaultInterval + 1)
        await viewModel.refresh()
        XCTAssertNil(viewModel.postingBlockedReason, "時計が進んでも postingBlockedReason が古いまま固定されている")
    }
}

/// isLoading / isPosting の多重実行ガードをテストするための、任意のタイミングまで
/// fetchPosts / submit を止められるストア。release 系メソッドを呼んだ後は、それ以降に
/// 届く呼び出しも待たせず即完了させる（テストがタスクを起動できたタイミングに関わらず、
/// 必ず終了できるようにするため）。@MainActor に固定し、2つの Task から並行に呼ばれても
/// 内部状態（保留中の継続の配列など）へのアクセスが直列化されるようにする
/// （そうしないと継続の取りこぼしでテストがハングし得る）。
@MainActor
private final class BlockingMoodPostStore: MoodPostStore {
    private(set) var fetchCallCount = 0
    private(set) var submitCallCount = 0
    var postsToReturn: [AreaMoodPost] = []

    private var fetchesReleased = false
    private var submitsReleased = false
    private var pendingFetchContinuations: [CheckedContinuation<Void, Never>] = []
    private var pendingSubmitContinuations: [CheckedContinuation<Void, Never>] = []
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var submitStartedContinuation: CheckedContinuation<Void, Never>?

    /// fetchPosts が呼ばれて待機に入るまで待つ。
    func waitUntilFetchStarted() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            fetchStartedContinuation = cont
        }
    }

    /// submit が呼ばれて待機に入るまで待つ。
    func waitUntilSubmitStarted() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            submitStartedContinuation = cont
        }
    }

    func releaseAllFetches() {
        fetchesReleased = true
        let pending = pendingFetchContinuations
        pendingFetchContinuations.removeAll()
        pending.forEach { $0.resume() }
    }

    func releaseAllSubmits() {
        submitsReleased = true
        let pending = pendingSubmitContinuations
        pendingSubmitContinuations.removeAll()
        pending.forEach { $0.resume() }
    }

    func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost] {
        fetchCallCount += 1
        fetchStartedContinuation?.resume()
        fetchStartedContinuation = nil
        if !fetchesReleased {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                pendingFetchContinuations.append(cont)
            }
        }
        return postsToReturn
    }

    func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost {
        submitCallCount += 1
        submitStartedContinuation?.resume()
        submitStartedContinuation = nil
        if !submitsReleased {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                pendingSubmitContinuations.append(cont)
            }
        }
        return AreaMoodPost(id: UUID().uuidString, area: area, level: level, phraseID: phraseID, createdAt: Date())
    }
}

/// CloudKit の結果整合性（投稿直後は fetch にまだ反映されないことがある）を再現するためのストア。
/// submit() の結果と fetchPosts() の返り値を切り離して制御できる。
@MainActor
private final class EventuallyConsistentMoodPostStore: MoodPostStore {
    var fetchResult: [AreaMoodPost] = []
    var now: () -> Date = { Date() }

    func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost] {
        fetchResult.filter { $0.createdAt >= since }
    }

    func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost {
        AreaMoodPost(id: UUID().uuidString, area: area, level: level, phraseID: phraseID, createdAt: now())
    }
}
