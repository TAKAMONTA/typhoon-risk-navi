import Foundation

/// 危険度に応じた「いま取る対策」ガイド。
/// 既存の台風情報・リスク表示と組み合わせて、「知る → 対策する」流れを作る。
enum TyphoonActionGuide {

    struct Step: Identifiable, Equatable {
        let id: String
        let text: String
    }

    /// 危険度ごとの対策リスト。SEVERE ほど緊急性の高い行動を先頭に置く。
    static func steps(forRiskLevel level: String) -> [Step] {
        switch level {
        case "SEVERE":
            return [
                Step(id: "severe-1", text: L10n.actionSevere1),
                Step(id: "severe-2", text: L10n.actionSevere2),
                Step(id: "severe-3", text: L10n.actionSevere3),
                Step(id: "severe-4", text: L10n.actionSevere4),
            ]
        case "HIGH":
            return [
                Step(id: "high-1", text: L10n.actionHigh1),
                Step(id: "high-2", text: L10n.actionHigh2),
                Step(id: "high-3", text: L10n.actionHigh3),
                Step(id: "high-4", text: L10n.actionHigh4),
            ]
        case "MEDIUM":
            return [
                Step(id: "medium-1", text: L10n.actionMedium1),
                Step(id: "medium-2", text: L10n.actionMedium2),
                Step(id: "medium-3", text: L10n.actionMedium3),
            ]
        default:
            return [
                Step(id: "low-1", text: L10n.actionLow1),
                Step(id: "low-2", text: L10n.actionLow2),
                Step(id: "low-3", text: L10n.actionLow3),
            ]
        }
    }

    /// 台風なし時の平時の備え。
    static var quietPeriodSteps: [Step] {
        [
            Step(id: "quiet-1", text: L10n.actionQuiet1),
            Step(id: "quiet-2", text: L10n.actionQuiet2),
            Step(id: "quiet-3", text: L10n.actionQuiet3),
        ]
    }
}
