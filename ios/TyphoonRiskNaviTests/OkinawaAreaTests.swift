import XCTest
@testable import TyphoonRiskNavi

/// 10エリア区分（気象庁 class15 準拠）と41自治体の割当のテスト。
/// スペック: docs/superpowers/specs/2026-08-15-area-mood-posts-design.md §4
final class OkinawaAreaTests: XCTestCase {

    func testCatalogHas41Municipalities() {
        XCTAssertEqual(OkinawaMunicipalityCatalog.all.count, 41)
    }

    /// 41自治体すべてがちょうど1エリアに属する(漏れなし)。
    func testAll41MunicipalitiesHaveAnArea() {
        for municipality in OkinawaMunicipalityCatalog.all {
            XCTAssertNotNil(
                municipality.area,
                "\(municipality.name) (\(municipality.id)) にエリアが割り当てられていない"
            )
        }
    }

    /// 対応表にカタログ外の孤児キーがない(typo 検出)。
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

    /// 気象庁 class15 区分との照合(判断が分かれる自治体のスポットチェック)。
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
}
