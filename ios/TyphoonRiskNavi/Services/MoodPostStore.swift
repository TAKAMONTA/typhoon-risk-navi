import Foundation

/// 体感投稿の取得・送信を抽象化する。本番は CloudKit 実装、テストとスクショモードは InMemory 実装。
protocol MoodPostStore {
    /// since 以降の投稿を新しい順で返す。limit 件で打ち切る（limit は 0 以上を想定）。
    func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost]
    /// 投稿を1件保存し、保存されたレコードを返す。
    func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost
}

/// テスト・スクリーンショットモード用のインメモリ実装。
final class InMemoryMoodPostStore: MoodPostStore {
    private(set) var posts: [AreaMoodPost]
    /// テストでエラー経路を検証するためのフック。
    var fetchError: Error?
    var submitError: Error?
    /// 時刻を注入可能にする（テストの決定性のため）。
    var now: () -> Date

    init(posts: [AreaMoodPost] = [], now: @escaping () -> Date = { Date() }) {
        self.posts = posts
        self.now = now
    }

    func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost] {
        if let fetchError { throw fetchError }
        return posts
            .filter { $0.createdAt >= since }
            // createdAt が同値の場合に備え id をタイブレークにする（sorted は安定ソートを保証しないため）
            .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
            .prefix(limit)
            .map { $0 }
    }

    func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost {
        if let submitError { throw submitError }
        let post = AreaMoodPost(
            id: UUID().uuidString, area: area, level: level, phraseID: phraseID, createdAt: now()
        )
        posts.append(post)
        return post
    }
}

extension InMemoryMoodPostStore {
    /// App Store スクリーンショット用のサンプル投稿。台風接近中の見え方を再現する。
    /// スクショモードでは CloudKit には一切書かない（既存のデモデータ方針を踏襲）。
    static func screenshotSamples(now: Date = Date()) -> InMemoryMoodPostStore {
        func sample(_ area: OkinawaArea, _ level: MoodLevel, _ phraseID: String, minutesAgo: Double) -> AreaMoodPost {
            AreaMoodPost(id: UUID().uuidString, area: area, level: level, phraseID: phraseID,
                         createdAt: now.addingTimeInterval(-minutesAgo * 60))
        }
        return InMemoryMoodPostStore(posts: [
            sample(.naha, .stormy, "L3_windows_rattling", minutesAgo: 8),
            sample(.naha, .stormy, "L3_staying_in", minutesAgo: 25),
            sample(.south, .dangerous, "L4_power_outage", minutesAgo: 12),
            sample(.central, .stormy, "L3_transport_disrupted", minutesAgo: 18),
            sample(.north, .breezy, "L2_trees_swaying", minutesAgo: 30),
            sample(.keramaAguni, .dangerous, "L4_cannot_go_out", minutesAgo: 15),
            sample(.kumejima, .violent, "L5_roaring_wind", minutesAgo: 5),
            sample(.miyako, .breezy, "L2_rain_started", minutesAgo: 40),
            sample(.ishigaki, .calm, "L1_still_quiet", minutesAgo: 50),
            sample(.yonaguni, .calm, "L1_as_usual", minutesAgo: 65),
            sample(.daito, .stormy, "L3_umbrella_useless", minutesAgo: 22),
        ], now: { now })
    }
}
