import XCTest
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

    /// 文言が解決されずに生のローカライズキーのまま表示されていないこと。
    /// キーの typo は NSLocalizedString がキー自体を返すため、これが唯一の検出手段になる。
    func testAllPhrasesResolveToRealText() {
        for phrase in MoodPhraseCatalog.all {
            XCTAssertFalse(phrase.text.hasPrefix("mood."), "\(phrase.id) の文言が未解決: \(phrase.text)")
        }
    }
}
