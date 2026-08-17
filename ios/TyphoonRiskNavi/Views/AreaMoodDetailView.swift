import SwiftUI

/// エリアの体感内訳シート。レベル分布バーと直近投稿のリスト。
struct AreaMoodDetailView: View {
    let area: OkinawaArea
    let posts: [AreaMoodPost]   // 呼び出し側でこのエリアの直近3時間分に絞って渡す

    var body: some View {
        NavigationStack {
            // disclaimer を List の外(兄弟)に置くことで、内訳・直近投稿をスクロールしても
            // 免責文言が画面外に流れない（AreaMoodView と同じ構成。スペック §1: 常時表示）。
            VStack(alignment: .leading, spacing: 8) {
                disclaimer
                    .padding(.horizontal)
                List {
                    if posts.isEmpty {
                        Text(L10n.moodDetailNoRecentPosts)
                            .foregroundStyle(.secondary)
                    } else {
                        Section(L10n.moodDetailBreakdown) {
                            distribution
                        }
                        Section(L10n.moodDetailRecentPosts) {
                            ForEach(posts) { post in
                                HStack(spacing: 10) {
                                    Text(post.level.emoji)
                                    VStack(alignment: .leading, spacing: 2) {
                                        // 未知の phraseID（将来バージョンのフレーズ）はレベルのラベルで代替
                                        Text(MoodPhraseCatalog.phrase(for: post.phraseID)?.text ?? post.level.label)
                                            .font(.subheadline)
                                        Text(relativeTime(post.createdAt))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
            .navigationTitle(area.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    /// 常時表示の免責。公式情報と誤認させない（スペック §1）。AreaMoodView と同じ文言・体裁。
    private var disclaimer: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2")
            Text(L10n.moodDisclaimer)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// レベル5→1の順（重い方を上）に、件数を横棒で示す。
    private var distribution: some View {
        let counts = Dictionary(grouping: posts, by: \.level).mapValues(\.count)
        let maxCount = max(counts.values.max() ?? 1, 1)
        return ForEach(MoodLevel.allCases.reversed()) { level in
            let count = counts[level] ?? 0
            HStack(spacing: 8) {
                Text(level.emoji)
                Text(level.label)
                    .font(.caption)
                    .frame(width: 88, alignment: .leading)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level.color.opacity(0.6))
                        .frame(width: max(2, geo.size.width * CGFloat(count) / CGFloat(maxCount)))
                }
                .frame(height: 10)
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return L10n.moodTimeJustNow }
        if minutes < 60 { return L10n.moodTimeMinutesAgo(minutes) }
        return L10n.moodTimeHoursMinutesAgo(minutes / 60, minutes % 60)
    }
}
