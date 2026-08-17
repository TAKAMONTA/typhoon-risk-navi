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
                Section("どのエリア？") {
                    Picker("エリア", selection: $selectedArea) {
                        Text("選択してください").tag(OkinawaArea?.none)
                        ForEach(OkinawaArea.allCases) { area in
                            Text(area.displayName).tag(OkinawaArea?.some(area))
                        }
                    }
                    Button {
                        detectAreaFromCurrentLocation(overwriteExisting: true)
                    } label: {
                        Label("現在地から選ぶ", systemImage: "location")
                    }
                }

                Section("いまの体感は？") {
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
                    Section("ひとことで言うと？") {
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

                if let message = viewModel.postError {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("体感を投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿する") { submit() }
                        .disabled(selectedArea == nil || selectedLevel == nil
                                  || selectedPhraseID == nil || isSubmitting)
                }
            }
            .onAppear {
                // レート制限中なら開いた時点で残り時間を見せる
                viewModel.postError = viewModel.postingBlockedReason
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
            guard let area = AreaMoodViewModel.area(for: location.coordinate) else { return }
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
        guard let area = selectedArea, let level = selectedLevel, let phraseID = selectedPhraseID else { return }
        viewModel.postError = nil
        isSubmitting = true
        Task {
            let succeeded = await viewModel.post(area: area, level: level, phraseID: phraseID)
            isSubmitting = false
            if succeeded { dismiss() }
        }
    }
}
