import Combine
import CoreLocation
import Foundation

/// 「みんな」タブの状態管理。取得→集約→表示と、投稿（楽観的反映つき）を担う。
@MainActor
final class AreaMoodViewModel: ObservableObject {

    /// 1回の取得で読む最大件数。10エリア×直近20件相当で、代表値の決定には十分。
    static let fetchLimit = 200
    /// 現在地からのエリア自動選択で「沖縄県内」とみなす上限距離(km)。
    /// 沖縄県内のどの地点からも最寄りの自治体はこの範囲に収まる。これを超える最寄り自治体しか
    /// 見つからない場合、その座標は沖縄県外であり、最寄りだからといってエリアを確定させてはいけない
    /// （県外ユーザーに沖縄のエリアが誤って自動選択され、捏造投稿につながるのを防ぐ）。
    static let maxAreaDetectionDistanceKm: Double = 100
    /// 表示中の自動更新間隔の既定値。テストから短い値を注入できるようにインスタンスプロパティにもしてある。
    /// init のデフォルト引数式から参照するため、MainActor 分離のない定数にしておく。
    nonisolated static let defaultRefreshInterval: TimeInterval = 5 * 60

    @Published private(set) var summaries: [OkinawaArea: AreaMoodSummary]
    @Published private(set) var recentPosts: [AreaMoodPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    /// 初回表示(redacted)を抜けたかどうかの判定専用のシグナル。取得成功・投稿成功のどちらでも true になる。
    /// lastUpdated は「取得が最後に成功した時刻」という意味だけに保つため、これとは分離してある
    /// （分離した理由は post() 内のコメント参照）。
    @Published private(set) var hasEverShownData = false
    @Published private(set) var fetchFailed = false
    @Published var postError: String?

    private let store: MoodPostStore
    private let rateLimiter: MoodPostRateLimiter
    private let now: () -> Date
    private let refreshInterval: TimeInterval
    private var refreshTask: Task<Void, Never>?
    /// 送信中フラグ。シートを閉じて開き直すと @State の isSubmitting は初期化されるため、
    /// 多重送信を防ぐ不変条件はシートではなくここに置く必要がある。
    private var isPosting = false

    init(
        store: MoodPostStore,
        rateLimiter: MoodPostRateLimiter = MoodPostRateLimiter(),
        now: @escaping () -> Date = { Date() },
        refreshInterval: TimeInterval = AreaMoodViewModel.defaultRefreshInterval
    ) {
        self.store = store
        self.rateLimiter = rateLimiter
        self.now = now
        self.refreshInterval = refreshInterval
        // 初期状態でも全エリアのセルが描けるよう、空の集約で埋めておく。
        self.summaries = MoodAggregator.summarize(posts: [], now: now())
    }

    /// 実運用は CloudKit、スクリーンショットモード（-screenshotMode YES）はサンプル入り InMemory。
    static func live() -> AreaMoodViewModel {
        if UserDefaults.standard.bool(forKey: "screenshotMode") {
            return AreaMoodViewModel(store: InMemoryMoodPostStore.screenshotSamples())
        }
        return AreaMoodViewModel(store: CloudKitMoodPostStore())
    }

    func refresh() async {
        // 取得の多重実行を防ぐ。重なると古い結果が新しい結果を上書きし、lastUpdated が巻き戻る。
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let current = now()
        do {
            let posts = try await store.fetchPosts(
                since: current.addingTimeInterval(-MoodAggregator.window),
                limit: Self.fetchLimit
            )
            recentPosts = posts
            summaries = MoodAggregator.summarize(posts: posts, now: current)
            lastUpdated = current
            hasEverShownData = true
            fetchFailed = false
        } catch {
            // 前回の結果を保持したまま、失敗だけ知らせる（無言で失敗させない）。
            // CloudKit のレート制限（CKError.requestRateLimited）もここに落ちる。即時再試行はせず、
            // 次の再試行はユーザー操作（再試行ボタン/プルリフレッシュ）か5分後の自動更新のみ。
            // retryAfter は通常数秒〜数十秒のため、この間隔はサーバーの指示より常に保守的で、
            // スペック §10「retryAfter を尊重して再試行する」を満たす。
            fetchFailed = true
        }
    }

    /// 投稿できない理由。nil なら投稿可能。
    var postingBlockedReason: String? {
        let remaining = rateLimiter.remainingSeconds(now: now())
        guard remaining > 0 else { return nil }
        let minutes = Int(ceil(remaining / 60))
        return L10n.moodRateLimited(minutes)
    }

    /// 投稿して楽観的に反映する。成功なら true。
    /// レート制限の記録は成功後のみ（失敗時に10分待たせない）。
    func post(area: OkinawaArea, level: MoodLevel, phraseID: String) async -> Bool {
        guard !isPosting else { return false }
        isPosting = true
        defer { isPosting = false }
        if let reason = postingBlockedReason {
            postError = reason
            return false
        }
        do {
            let saved = try await store.submit(area: area, level: level, phraseID: phraseID)
            rateLimiter.recordPost(now: now())
            recentPosts.insert(saved, at: 0)
            summaries = MoodAggregator.summarize(posts: recentPosts, now: now())
            // fetchPosts が失敗していても(fetchFailed = true のままでも)、自分の投稿は
            // 確かに反映されたので hasEverShownData を立てて redacted を解除する。
            // lastUpdated はここでは進めない。進めてしまうと「取得が成功した時刻」という
            // 意味が崩れ、取得失敗バナーと「更新 HH:mm」ラベルが同時に出て矛盾してしまう。
            hasEverShownData = true
            postError = nil
            return true
        } catch {
            postError = (error as? LocalizedError)?.errorDescription
                ?? L10n.moodPostFailedGeneric
            return false
        }
    }

    /// タブ表示中の自動更新を開始する。多重起動しない。
    func startAutoRefresh() {
        guard refreshTask == nil else { return }
        let interval = refreshInterval
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    // stopAutoRefresh() によるキャンセルはここに CancellationError として届く。
                    // try? で握りつぶすと、キャンセル後も次の行の refresh() が1回丸ごと走ってしまう
                    // （余計な取得が飛ぶ・キャンセルが fetchFailed = true として誤検出される）。
                    break
                }
                // self が解放されたらループを抜ける。weak self のまま回し続けると、
                // 誰にもキャンセルされない Task が5分おきに起き続けて何もせず眠るだけになる。
                guard let self else { break }
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// 座標からエリアを推定する（既存の最寄り自治体判定を経由）。
    /// 最寄りの自治体までの距離が maxAreaDetectionDistanceKm を超える場合は、
    /// その座標が沖縄県外にあるとみなし nil を返す。
    static func area(for coordinate: CLLocationCoordinate2D) -> OkinawaArea? {
        guard let nearest = OkinawaMunicipalityCatalog.nearest(to: coordinate),
              nearest.distanceKm <= maxAreaDetectionDistanceKm else {
            return nil
        }
        return nearest.municipality.area
    }
}
