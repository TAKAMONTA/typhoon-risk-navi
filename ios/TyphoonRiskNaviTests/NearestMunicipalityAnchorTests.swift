import XCTest
import CoreLocation
@testable import TyphoonRiskNavi

/// 「最寄り自治体の情報」は、代表地点（あなたの危険度用）ではなく
/// 端末の実測現在地を優先すべき、というバグ修正を守るテスト。
@MainActor
final class NearestMunicipalityAnchorTests: XCTestCase {

    /// 石垣島付近の保存場所のみ。deviceLocation が無いときのフォールバック確認に使う。
    private let ishigaki = SavedLocation(
        id: "ishigaki-only",
        name: "石垣島の別荘",
        lat: 24.34,
        lon: 124.16,
        notificationLevel: "MEDIUM"
    )

    /// 那覇市付近の座標。deviceLocation に使う。
    private let nahaCoordinate = CLLocationCoordinate2D(latitude: 26.21, longitude: 127.68)

    private func makeViewModel(locations: [SavedLocation]) -> TyphoonViewModel {
        let viewModel = TyphoonViewModel()
        viewModel.state = DemoStateResponse(
            typhoon: nil,
            risks: [],
            savedLocations: locations,
            lastUpdated: "2026-08-01T00:00:00Z"
        )
        return viewModel
    }

    /// deviceLocation が未設定なら、従来どおり representativeLocation 基準の自治体になる。
    func testFallsBackToRepresentativeLocationWhenNoDeviceLocation() throws {
        let viewModel = makeViewModel(locations: [ishigaki])

        XCTAssertNil(viewModel.deviceLocation)
        XCTAssertFalse(viewModel.isMunicipalityFromDeviceLocation)

        let expected = try XCTUnwrap(OkinawaMunicipalityCatalog.nearest(to: ishigaki))
        let info = try XCTUnwrap(viewModel.nearestMunicipalityInfo)
        XCTAssertEqual(info.municipality.id, expected.municipality.id)
    }

    /// deviceLocation を設定すると、保存場所の内容にかかわらず deviceLocation 基準の
    /// 自治体が返る（石垣島だけ保存していても那覇市付近を返す）。
    func testUsesDeviceLocationOverSavedLocationsWhenSet() throws {
        let viewModel = makeViewModel(locations: [ishigaki])
        viewModel.updateDeviceLocation(nahaCoordinate)

        let expected = try XCTUnwrap(OkinawaMunicipalityCatalog.nearest(to: nahaCoordinate))
        let info = try XCTUnwrap(viewModel.nearestMunicipalityInfo)
        XCTAssertEqual(info.municipality.id, expected.municipality.id)

        // 石垣島基準の結果とは異なることも確認し、「別の市町村が出る」バグの再発を防ぐ。
        let ishigakiBased = try XCTUnwrap(OkinawaMunicipalityCatalog.nearest(to: ishigaki))
        XCTAssertNotEqual(info.municipality.id, ishigakiBased.municipality.id)
    }

    /// isMunicipalityFromDeviceLocation は deviceLocation の有無に連動して切り替わる。
    func testIsMunicipalityFromDeviceLocationTracksState() {
        let viewModel = makeViewModel(locations: [ishigaki])

        XCTAssertFalse(viewModel.isMunicipalityFromDeviceLocation)

        viewModel.updateDeviceLocation(nahaCoordinate)
        XCTAssertTrue(viewModel.isMunicipalityFromDeviceLocation)
    }
}
