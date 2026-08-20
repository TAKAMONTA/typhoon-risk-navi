import XCTest
import SwiftUI
@testable import TyphoonRiskNavi

/// 定型フレーズカタログの整合性テスト。
/// CloudKit には phraseID しか保存しないため、ID の一意性と全レベルの網羅が壊れると
/// 過去投稿の表示が壊れる。ここで固定する。
final class MoodPhraseCatalogTests: XCTestCase {

    func testPhraseIDsAreUnique() {
        let ids = MoodPhraseCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "phraseID が重複している")
    }

    /// 各レベルに4件のフレーズがある。
    func testEveryLevelHasFourPhrases() {
        for level in MoodLevel.allCases {
            XCTAssertEqual(
                MoodPhraseCatalog.phrases(for: level).count, 4,
                "レベル\(level.rawValue) のフレーズが4件でない"
            )
        }
    }

    /// 全フレーズが ID で引ける。
    func testAllPhrasesResolveByID() {
        for phrase in MoodPhraseCatalog.all {
            XCTAssertEqual(MoodPhraseCatalog.phrase(for: phrase.id), phrase)
        }
    }

    /// 未知の ID（将来バージョンのフレーズ等）は nil を返す。
    func testUnknownIDReturnsNil() {
        XCTAssertNil(MoodPhraseCatalog.phrase(for: "L9_unknown_future_phrase"))
    }

    /// フレーズはレベルのラベルと重複させない（画面に並べて表示するため）。
    func testPhrasesDoNotDuplicateLevelLabels() {
        let labels = Set(MoodLevel.allCases.map(\.label))
        for phrase in MoodPhraseCatalog.all {
            XCTAssertFalse(labels.contains(phrase.text), "フレーズ「\(phrase.text)」がレベルのラベルと重複")
        }
    }

    func testMoodLevelIsComparable() {
        XCTAssertTrue(MoodLevel.calm < MoodLevel.violent)
        XCTAssertEqual(MoodLevel(rawValue: 3), .stormy)
    }

    /// MoodLevel の絵文字・ラベル・色の組み合わせを固定する。色覚多様性に配慮し色だけに
    /// 頼らないという設計上の要件のため、この三つ組はデコレーションではなくアクセシビリティ上の
    /// 保証。レベル同士の入れ替わり（例: breezy と stormy の絵文字入れ替え）は他のテストを
    /// すべて素通りしてしまうため、ここで全5レベル分を直接ピン留めする。
    func testEmojiLabelColorTriplePerLevel() {
        let expected: [(level: MoodLevel, emoji: String, label: String, color: Color)] = [
            (.calm, "😌", "おだやか", .blue),
            (.breezy, "🙂", "風が出てきた", .green),
            (.stormy, "😟", "雨風が強い", .yellow),
            (.dangerous, "😨", "外は危険", .orange),
            (.violent, "😱", "暴風", .red),
        ]
        for entry in expected {
            XCTAssertEqual(entry.level.emoji, entry.emoji, "レベル\(entry.level.rawValue) の絵文字が想定と異なる")
            XCTAssertEqual(entry.level.label, entry.label, "レベル\(entry.level.rawValue) のラベルが想定と異なる")
            XCTAssertEqual(entry.level.color, entry.color, "レベル\(entry.level.rawValue) の色が想定と異なる")
        }
    }

    /// 文言が解決されずに生のローカライズキーのまま表示されていないこと。
    /// キーの typo は NSLocalizedString がキー自体を返すため、これが唯一の検出手段になる。
    func testAllPhrasesResolveToRealText() {
        for phrase in MoodPhraseCatalog.all {
            XCTAssertFalse(phrase.text.hasPrefix("mood."), "\(phrase.id) の文言が未解決: \(phrase.text)")
        }
    }
}
