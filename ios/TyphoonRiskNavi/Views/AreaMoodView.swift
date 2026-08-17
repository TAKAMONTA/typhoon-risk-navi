import SwiftUI

/// 「みんな」タブ。10エリアの体感を地理配置に沿ったグリッドで表示する。
/// 3列グリッドの中央列が本島（北→南）、左列が西の離島、右上が大東、最下段が先島（西→東）。
struct AreaMoodView: View {
    @StateObject private var viewModel = AreaMoodViewModel.live()
    @State private var selectedArea: OkinawaArea?
    @State private var isShowingPostSheet = false

    /// 一度もデータが届いていない状態。取得中か失敗かを問わない。
    /// isLoading を条件に含めると、初回取得が失敗したときに「投稿なし」の断定表示に戻ってしまう。
    /// lastUpdated ではなく hasEverShownData を見る。lastUpdated は「取得が最後に成功した時刻」
    /// を意味し「更新 HH:mm」ラベルの入力でもあるため、取得は失敗したまま投稿だけ成功した場合に
    /// lastUpdated で判定すると、そのラベルが取得失敗バナーと同時に出て矛盾してしまう。
    private var isFirstLoad: Bool { !viewModel.hasEverShownData }

    var body: some View {
        NavigationStack {
            // disclaimer を ScrollView の外(兄弟)に置くことで、アクセシビリティ文字サイズで
            // グリッドが伸びてスクロールしても免責文言が画面外に流れない（スペック §1: 常時表示）。
            VStack(alignment: .leading, spacing: 8) {
                disclaimer
                    .padding(.horizontal)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.fetchFailed {
                            fetchFailedBanner
                        }
                        areaGrid
                            .redacted(reason: isFirstLoad ? .placeholder : [])
                            .allowsHitTesting(!isFirstLoad)
                            .overlay {
                                if isFirstLoad && viewModel.isLoading {
                                    ProgressView()
                                }
                            }
                        if let lastUpdated = viewModel.lastUpdated {
                            Text(L10n.moodUpdatedAt(lastUpdated.formatted(date: .omitted, time: .shortened)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.refresh() }
            }
            .padding(.top, 8)
            .navigationTitle(L10n.moodTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingPostSheet = true
                    } label: {
                        Label(L10n.moodPostAction, systemImage: "plus.bubble")
                    }
                }
            }
            .task {
                await viewModel.refresh()
                // タブ切り替えでこの task がキャンセルされた後は、
                // オフスクリーンのタブでポーリングを起動しない。
                if !Task.isCancelled {
                    viewModel.startAutoRefresh()
                }
            }
            .onDisappear { viewModel.stopAutoRefresh() }
            .sheet(item: $selectedArea) { area in
                AreaMoodDetailView(
                    area: area,
                    posts: viewModel.recentPosts.filter {
                        $0.area == area && $0.createdAt >= Date().addingTimeInterval(-MoodAggregator.window)
                    }
                )
            }
            .sheet(isPresented: $isShowingPostSheet) {
                AreaMoodPostSheet(viewModel: viewModel)
            }
        }
    }

    /// 常時表示の免責。公式情報と誤認させない（スペック §1）。
    private var disclaimer: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2")
            Text(L10n.moodDisclaimer)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// 取得失敗時のバナー。前回の結果は出したまま、失敗だけ知らせる
    /// （DataSourceStatusBanner と同じ流儀）。
    private var fetchFailedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(L10n.moodFetchFailed)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.retry) {
                Task { await viewModel.refresh() }
            }
            .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    /// 地理関係のラフな再現:
    /// 　　　　　　　　［北部］
    /// ［久米島］　　　［中部］［大東］
    /// ［慶良間・粟国］［那覇］
    /// 　　　　　　　　［南部］
    /// ［与那国］　　　［石垣］［宮古］
    private var areaGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                spacerCell
                cell(.north)
                spacerCell
            }
            GridRow {
                cell(.kumejima)
                cell(.central)
                cell(.daito)
            }
            GridRow {
                cell(.keramaAguni)
                cell(.naha)
                spacerCell
            }
            GridRow {
                spacerCell
                cell(.south)
                spacerCell
            }
            GridRow {
                cell(.yonaguni)
                cell(.ishigaki)
                cell(.miyako)
            }
        }
    }

    private var spacerCell: some View {
        Color.clear
            .gridCellUnsizedAxes([.horizontal, .vertical])
    }

    private func cell(_ area: OkinawaArea) -> some View {
        let summary = viewModel.summaries[area]
        let level = summary?.representativeLevel
        return Button {
            selectedArea = area
        } label: {
            VStack(spacing: 4) {
                Text(level?.emoji ?? "－")
                    .font(.title2)
                    // 表情は装飾。VoiceOver には下のボタン全体のラベルでまとめて読ませる。
                    .accessibilityHidden(true)
                Text(area.displayName)
                    .font(.caption.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                Text(cellCaption(summary))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background((level?.color ?? Color.gray).opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke((level?.color ?? Color.gray).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        // 素の読み上げは「slightly smiling face、北部、風が出てきた・1件、ボタン」のように断片化するため、
        // 意味の通る一文にまとめる（「－」も含まれなくなる）。
        .accessibilityLabel(L10n.moodCellAccessibilityLabel(area.displayName, cellCaption(summary)))
    }

    private func cellCaption(_ summary: AreaMoodSummary?) -> String {
        guard let summary, summary.postCount > 0, let level = summary.representativeLevel else {
            return L10n.moodNoPosts
        }
        return L10n.moodCellCaption(level.label, summary.postCount)
    }
}
