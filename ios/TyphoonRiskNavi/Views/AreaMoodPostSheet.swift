import SwiftUI

/// 体感の投稿シート。エリア → レベル → フレーズの3選択で完了する。
/// 位置情報の許可要求はユーザー操作（「現在地から選ぶ」ボタン）のときだけ行う（既存方針）。
/// 許可済みならシート表示時に黙って現在地からエリアを初期選択する（プロンプトは出ないため安全）。
struct AreaMoodPostSheet: View {
    @ObservedObject var viewModel: AreaMoodViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var locationHelper = LocationManagerHelper()
    @State private var selectedArea: OkinawaArea?
    @State private var selectedLevel: MoodLevel?
    @State private var selectedPhraseID: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.moodPostAreaSection) {
                    Picker(L10n.moodPostAreaPickerLabel, selection: $selectedArea) {
                        Text(L10n.moodPostSelectPlaceholder).tag(OkinawaArea?.none)
                        ForEach(OkinawaArea.allCases) { area in
                            Text(area.displayName).tag(OkinawaArea?.some(area))
                        }
                    }
                    Button {
                        detectAreaFromCurrentLocation(overwriteExisting: true)
                    } label: {
                        Label(L10n.moodPostUseCurrentLocation, systemImage: "location")
                    }
                }

                Section(L10n.moodPostLevelSection) {
                    ForEach(MoodLevel.allCases) { level in
                        Button {
                            selectedLevel = level
                            // レベルを変えたら、他レベルのフレーズ選択は無効にする
                            if let phraseID = selectedPhraseID,
                               MoodPhraseCatalog.phrase(for: phraseID)?.level != level {
                                selectedPhraseID = nil
                            }
                        } label: {
                            HStack {
                                Text(level.emoji)
                                Text(level.label)
                                Spacer()
                                if selectedLevel == level {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(level.color)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .listRowBackground(level.color.opacity(selectedLevel == level ? 0.25 : 0.06))
                    }
                }

                if let level = selectedLevel {
                    Section(L10n.moodPostPhraseSection) {
                        ForEach(MoodPhraseCatalog.phrases(for: level)) { phrase in
                            Button {
                                selectedPhraseID = phrase.id
                            } label: {
                                HStack {
                                    Text(phrase.text)
                                    Spacer()
                                    if selectedPhraseID == phrase.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                // postError（投稿失敗）を優先し、なければ postingBlockedReason（レート制限）を見せる。
                // postingBlockedReason は @Published なので、シートを開いたままレート制限の
                // 残り時間が変わったり解除されたりしても表示が自動的に更新される。
                if let message = viewModel.postError ?? viewModel.postingBlockedReason {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(L10n.moodPostTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.mapSummaryCollapse) { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.moodPostSubmit) { submit() }
                        .disabled(selectedArea == nil || selectedLevel == nil
                                  || selectedPhraseID == nil || isSubmitting)
                }
            }
            .onAppear {
                // 許可済みなら黙って初期選択（未許可ならボタン操作まで何もしない）
                if locationHelper.isAuthorized, selectedArea == nil {
                    detectAreaFromCurrentLocation(overwriteExisting: false)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func detectAreaFromCurrentLocation(overwriteExisting: Bool) {
        locationHelper.onLocation = { location in
            guard let area = AreaMoodViewModel.area(for: location.coordinate) else {
                // 現在地が沖縄県外と判定された場合、黙って何もしないとボタンが無反応に見えるため
                // (かつては最寄りの自治体が無条件に選ばれてしまい、県外からの捏造投稿を招いていた)。
                viewModel.postError = L10n.moodPostOutsideOkinawa
                return
            }
            // 位置情報の解決に成功したので、直前の「県外のようです」エラーが
            // 画面に残り続けないようにする
            viewModel.postError = nil
            // 自動検出中にユーザーが手で選んでいたら、後着の測位で上書きしない
            if overwriteExisting || selectedArea == nil {
                selectedArea = area
            }
        }
        locationHelper.onFailure = {
            // 拒否・失敗時は自動選択しない（手動で選んでもらう）。スペック §10
        }
        locationHelper.requestLocation()
    }

    private func submit() {
        guard let area = selectedArea, let level = selectedLevel, let phraseID = selectedPhraseID,
              // UI は選択済みレベルのフレーズしか選ばせないが、その不変条件を書き込み経路でも
              // 構造的に保証する（表示ロジックとは独立に、level と phraseID の食い違いを防ぐ）。
              MoodPhraseCatalog.phrase(for: phraseID)?.level == level
        else { return }
        viewModel.postError = nil
        isSubmitting = true
        Task {
            let succeeded = await viewModel.post(area: area, level: level, phraseID: phraseID)
            isSubmitting = false
            if succeeded { dismiss() }
        }
    }
}
