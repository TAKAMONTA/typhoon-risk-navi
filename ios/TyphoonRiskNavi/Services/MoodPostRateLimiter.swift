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
        // 型が壊れていたら未投稿扱い（投稿をブロックし続けるより安全）。
        guard let last = defaults.object(forKey: Self.lastPostKey) as? Date else { return 0 }
        // 保存時刻が now より未来なら、端末の時計が巻き戻された等で値が壊れている。
        // 同じく未投稿扱いにする。上限（min）で抑える案は採らない。表示される数字が
        // 600 秒に見えるだけで実際の解除は last + interval のままなので、
        // 「あと10分」の表示が何十分も動かないという、より悪い状態になる。
        guard last <= now else { return 0 }
        return max(0, interval - now.timeIntervalSince(last))
    }

    func recordPost(now: Date = Date()) {
        defaults.set(now, forKey: Self.lastPostKey)
    }
}
