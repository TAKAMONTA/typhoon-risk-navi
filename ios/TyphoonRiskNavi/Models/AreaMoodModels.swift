import SwiftUI

/// 体感レベル5段階。色・表情・ラベルはレベルと1対1。
/// 色覚多様性に配慮し、UI では色だけに頼らず表情と文字を常に併記する。
/// スペック: docs/superpowers/specs/2026-08-15-area-mood-posts-design.md §5
enum MoodLevel: Int, CaseIterable, Codable, Comparable, Identifiable {
    case calm = 1
    case breezy = 2
    case stormy = 3
    case dangerous = 4
    case violent = 5

    var id: Int { rawValue }

    static func < (lhs: MoodLevel, rhs: MoodLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        L10n.moodLevelLabel(self)
    }

    var emoji: String {
        switch self {
        case .calm: return "😌"
        case .breezy: return "🙂"
        case .stormy: return "😟"
        case .dangerous: return "😨"
        case .violent: return "😱"
        }
    }

    var color: Color {
        switch self {
        case .calm: return .blue
        case .breezy: return .green
        case .stormy: return .yellow
        case .dangerous: return .orange
        case .violent: return .red
        }
    }
}

/// 1件の体感投稿（クライアント側モデル）。CloudKit レコードとの変換は CloudKitMoodPostStore が行う。
struct AreaMoodPost: Identifiable, Equatable {
    let id: String          // CKRecord.ID.recordName 由来。InMemory 実装では UUID
    let area: OkinawaArea
    let level: MoodLevel
    let phraseID: String
    let createdAt: Date
}

/// エリアの集約結果。representativeLevel が nil のときは期間内に投稿なし。
struct AreaMoodSummary: Equatable {
    let area: OkinawaArea
    let representativeLevel: MoodLevel?
    let postCount: Int
}
