import Foundation

/// 連投制限。同一端末からの体感投稿を interval（既定10分）に1回に制限する。
/// UserDefaults に最終投稿時刻を持つだけの端末ローカル制限
/// （CloudKit Public Database にはサーバー側のレート制限を書けないため）。
struct MoodPostRateLimiter {
    static let defaultInterval: TimeInterval = 10 * 60
    static let lastPostKey = "area_mood_last_post_at_v1"

    private let defaults: UserDefaults
    private let interval: TimeInterval

    init(defaults: UserDefaults = .standard, interval: TimeInterval = MoodPostRateLimiter.defaultInterval) {
        self.defaults = defaults
        self.interval = interval
    }

    func canPost(now: Date = Date()) -> Bool {
        remainingSeconds(now: now) <= 0
    }

    /// 次に投稿できるまでの残り秒数。投稿可能なら 0。
    func remainingSeconds(now: Date = Date()) -> TimeInterval {
        guard let last = defaults.object(forKey: Self.lastPostKey) as? Date else { return 0 }
        return max(0, interval - now.timeIntervalSince(last))
    }

    func recordPost(now: Date = Date()) {
        defaults.set(now, forKey: Self.lastPostKey)
    }
}
