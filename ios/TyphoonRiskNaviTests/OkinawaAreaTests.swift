import XCTest
@testable import TyphoonRiskNavi

/// 10エリア区分（気象庁 class15 準拠）と41自治体の割当のテスト。
/// スペック: docs/superpowers/specs/2026-08-15-area-mood-posts-design.md §4
final class OkinawaAreaTests: XCTestCase {

    func testCatalogHas41Municipalities() {
        XCTAssertEqual(OkinawaMunicipalityCatalog.all.count, 41)
    }

    /// 41自治体すべてがちょうど1エリアに属する（漏れなし）。
    func testAll41MunicipalitiesHaveAnArea() {
        for municipality in OkinawaMunicipalityCatalog.all {
            XCTAssertNotNil(
                municipality.area,
                "\(municipality.name) (\(municipality.id)) にエリアが割り当てられていない"
            )
        }
    }

    /// 対応表にカタログ外の孤児キーがない（typo 検出）。
    func testMappingHasNoOrphanEntries() {
        let catalogIDs = Set(OkinawaMunicipalityCatalog.all.map(\.id))
        for key in OkinawaArea.municipalityAreaMap.keys {
            XCTAssertTrue(catalogIDs.contains(key), "対応表のキー \(key) がカタログに存在しない")
        }
    }

    /// 全10エリアに1自治体以上が割り当てられている。
    func testEveryAreaHasAtLeastOneMunicipality() {
        let assignedAreas = Set(OkinawaArea.municipalityAreaMap.values)
        XCTAssertEqual(assignedAreas, Set(OkinawaArea.allCases))
    }

    /// 各エリアの自治体数を固定する（気象庁 class15 区分準拠）。
    /// 「全自治体が割り当て済み」「全エリアが1件以上使われている」を確認するだけでは、
    /// 自治体が別エリアへ迷い込む取り違え（例: onna を north から central へ）を検出できない。
    /// エリアごとの件数を直接ピン留めすることで、これを検出する。
    func testMunicipalityCountsPerArea() {
        let expected: [OkinawaArea: Int] = [
            .naha: 1,
            .south: 8,
            .central: 8,
            .north: 12,
            .keramaAguni: 4,
            .kumejima: 1,
            .miyako: 2,
            .ishigaki: 2,
            .yonaguni: 1,
            .daito: 2,
        ]
        XCTAssertEqual(expected.values.reduce(0, +), 41, "期待値の合計が41自治体と一致しない")
        let actual = Dictionary(grouping: OkinawaArea.municipalityAreaMap.values, by: { $0 })
            .mapValues(\.count)
        for area in OkinawaArea.allCases {
            XCTAssertEqual(actual[area] ?? 0, expected[area], "\(area) の自治体数が想定と異なる")
        }
    }

    /// 気象庁 class15 区分との照合（判断が分かれる自治体のスポットチェック）。
    func testJMAClass15SpotChecks() {
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["naha"], .naha)
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["urasoe"], .south)      // 浦添は気象庁区分では南部
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["iheya"], .north)       // 伊平屋は離島だが本島北部
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["ie"], .north)          // 伊江島も本島北部
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["tokashiki"], .keramaAguni)
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["tarama"], .miyako)     // 多良間は宮古
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["taketomi"], .ishigaki) // 竹富町は石垣
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["minamidaito"], .daito)
    }

    func testDisplayNames() {
        XCTAssertEqual(OkinawaArea.keramaAguni.displayName, "慶良間・粟国")
        XCTAssertEqual(OkinawaArea.naha.displayName, "那覇")
    }

    /// displayName が解決されずに生のローカライズキーのまま表示されていないこと（全10エリア）。
    /// キーの typo は NSLocalizedString がキー自体を返すため、これが唯一の検出手段になる。
    func testAllDisplayNamesResolveToRealText() {
        for area in OkinawaArea.allCases {
            XCTAssertFalse(area.displayName.hasPrefix("area."), "\(area) の displayName が未解決: \(area.displayName)")
        }
    }

    /// MoodLevel.label が解決されずに生のローカライズキーのまま表示されていないこと（全5レベル）。
    func testAllMoodLevelLabelsResolveToRealText() {
        for level in MoodLevel.allCases {
            XCTAssertFalse(level.label.hasPrefix("mood."), "レベル\(level.rawValue) の label が未解決: \(level.label)")
        }
    }
}
