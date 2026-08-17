import Foundation

struct MoodPhrase: Identifiable, Equatable {
    let id: String
    let level: MoodLevel
    /// 表示文言は id から解決する。id と文言キーを別々に持つと、
    /// 片方だけずれたときに生キー文字列が UI に出てしまう。
    var text: String { L10n.moodPhraseText(id) }
}

/// 定型フレーズの静的カタログ。CloudKit には phraseID のみ保存し、文言はここで解決する。
/// ID は文言と独立させ、文言を変えても過去投稿の意味が壊れないようにする。
/// フレーズはレベルのラベルと重複させない（画面に並べて表示するため）。
enum MoodPhraseCatalog {

    static let all: [MoodPhrase] = [
        // レベル1: おだやか
        MoodPhrase(id: "L1_still_quiet", level: .calm),
        MoodPhrase(id: "L1_gentle_wind", level: .calm),
        MoodPhrase(id: "L1_no_rain", level: .calm),
        MoodPhrase(id: "L1_as_usual", level: .calm),
        // レベル2: 風が出てきた
        MoodPhrase(id: "L2_trees_swaying", level: .breezy),
        MoodPhrase(id: "L2_rain_started", level: .breezy),
        MoodPhrase(id: "L2_stocked_up", level: .breezy),
        MoodPhrase(id: "L2_still_walkable", level: .breezy),
        // レベル3: 雨風が強い
        MoodPhrase(id: "L3_windows_rattling", level: .stormy),
        MoodPhrase(id: "L3_staying_in", level: .stormy),
        MoodPhrase(id: "L3_transport_disrupted", level: .stormy),
        MoodPhrase(id: "L3_umbrella_useless", level: .stormy),
        // レベル4: 外は危険
        MoodPhrase(id: "L4_cannot_go_out", level: .dangerous),
        MoodPhrase(id: "L4_debris_flying", level: .dangerous),
        MoodPhrase(id: "L4_power_outage", level: .dangerous),
        MoodPhrase(id: "L4_water_outage", level: .dangerous),
        // レベル5: 暴風
        MoodPhrase(id: "L5_roaring_wind", level: .violent),
        MoodPhrase(id: "L5_away_from_windows", level: .violent),
        MoodPhrase(id: "L5_peak_ahead", level: .violent),
        MoodPhrase(id: "L5_maybe_past_peak", level: .violent),
    ]

    static func phrases(for level: MoodLevel) -> [MoodPhrase] {
        all.filter { $0.level == level }
    }

    /// 未知の ID（将来のバージョンが追加したフレーズ等）は nil。表示側はレベルのラベルで代替する。
    static func phrase(for id: String) -> MoodPhrase? {
        all.first { $0.id == id }
    }
}
