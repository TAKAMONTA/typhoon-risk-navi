import Foundation

/// 投稿列からエリア別の代表体感を集約する純関数。
enum MoodAggregator {

    /// 集約に使う時間窓（3時間）。これより古い投稿は無視する。
    static let window: TimeInterval = 3 * 60 * 60

    /// 全10エリア分のサマリーを返す（投稿が無いエリアも postCount 0 で含む）。
    /// 代表値は時間窓内の最頻レベル。同数の場合は高いレベル側に倒す
    /// （防災文脈では見逃しより過剰の方が安全）。
    /// createdAt が now より未来の投稿は除外しない。サーバー時刻と端末時計のずれで
    /// 投稿直後の楽観的反映が消えると、投稿が失敗したように見えるため。
    static func summarize(posts: [AreaMoodPost], now: Date = Date()) -> [OkinawaArea: AreaMoodSummary] {
        let cutoff = now.addingTimeInterval(-window)
        let recent = posts.filter { $0.createdAt >= cutoff }
        let grouped = Dictionary(grouping: recent, by: \.area)

        var result: [OkinawaArea: AreaMoodSummary] = [:]
        for area in OkinawaArea.allCases {
            let areaPosts = grouped[area] ?? []
            let counts = Dictionary(grouping: areaPosts, by: \.level).mapValues(\.count)
            let representative = counts.max { a, b in
                if a.value != b.value { return a.value < b.value }
                return a.key < b.key   // キー比較は必須。外すと同数時の結果が Dictionary の反復順に依存する
            }?.key
            result[area] = AreaMoodSummary(
                area: area,
                representativeLevel: representative,
                postCount: areaPosts.count
            )
        }
        return result
    }
}
