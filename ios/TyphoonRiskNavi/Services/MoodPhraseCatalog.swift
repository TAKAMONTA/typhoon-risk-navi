import Foundation

struct MoodPhrase: Identifiable, Equatable {
    let id: String
    let level: MoodLevel
    let text: String
}

/// 定型フレーズの静的カタログ。CloudKit には phraseID のみ保存し、文言はここで解決する。
/// ID は文言と独立させ、文言を変えても過去投稿の意味が壊れないようにする。
/// フレーズはレベルのラベルと重複させない（画面に並べて表示するため）。
enum MoodPhraseCatalog {

    static let all: [MoodPhrase] = [
        // レベル1: おだやか
        MoodPhrase(id: "L1_still_quiet", level: .calm, text: L10n.moodPhraseText("L1_still_quiet")),
        MoodPhrase(id: "L1_gentle_wind", level: .calm, text: L10n.moodPhraseText("L1_gentle_wind")),
        MoodPhrase(id: "L1_no_rain", level: .calm, text: L10n.moodPhraseText("L1_no_rain")),
        MoodPhrase(id: "L1_as_usual", level: .calm, text: L10n.moodPhraseText("L1_as_usual")),
        // レベル2: 風が出てきた
        MoodPhrase(id: "L2_trees_swaying", level: .breezy, text: L10n.moodPhraseText("L2_trees_swaying")),
        MoodPhrase(id: "L2_rain_started", level: .breezy, text: L10n.moodPhraseText("L2_rain_started")),
        MoodPhrase(id: "L2_stocked_up", level: .breezy, text: L10n.moodPhraseText("L2_stocked_up")),
        MoodPhrase(id: "L2_still_walkable", level: .breezy, text: L10n.moodPhraseText("L2_still_walkable")),
        // レベル3: 雨風が強い
        MoodPhrase(id: "L3_windows_rattling", level: .stormy, text: L10n.moodPhraseText("L3_windows_rattling")),
        MoodPhrase(id: "L3_staying_in", level: .stormy, text: L10n.moodPhraseText("L3_staying_in")),
        MoodPhrase(id: "L3_transport_disrupted", level: .stormy, text: L10n.moodPhraseText("L3_transport_disrupted")),
        MoodPhrase(id: "L3_umbrella_useless", level: .stormy, text: L10n.moodPhraseText("L3_umbrella_useless")),
        // レベル4: 外は危険
        MoodPhrase(id: "L4_cannot_go_out", level: .dangerous, text: L10n.moodPhraseText("L4_cannot_go_out")),
        MoodPhrase(id: "L4_debris_flying", level: .dangerous, text: L10n.moodPhraseText("L4_debris_flying")),
        MoodPhrase(id: "L4_power_outage", level: .dangerous, text: L10n.moodPhraseText("L4_power_outage")),
        MoodPhrase(id: "L4_water_outage", level: .dangerous, text: L10n.moodPhraseText("L4_water_outage")),
        // レベル5: 暴風
        MoodPhrase(id: "L5_roaring_wind", level: .violent, text: L10n.moodPhraseText("L5_roaring_wind")),
        MoodPhrase(id: "L5_away_from_windows", level: .violent, text: L10n.moodPhraseText("L5_away_from_windows")),
        MoodPhrase(id: "L5_peak_ahead", level: .violent, text: L10n.moodPhraseText("L5_peak_ahead")),
        MoodPhrase(id: "L5_maybe_past_peak", level: .violent, text: L10n.moodPhraseText("L5_maybe_past_peak")),
    ]

    static func phrases(for level: MoodLevel) -> [MoodPhrase] {
        all.filter { $0.level == level }
    }

    /// 未知の ID（将来のバージョンが追加したフレーズ等）は nil。表示側はレベルのラベルで代替する。
    static func phrase(for id: String) -> MoodPhrase? {
        all.first { $0.id == id }
    }
}
