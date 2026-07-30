import XCTest
import MapKit
@testable import TyphoonRiskNavi

/// 地図の初期表示が「沖縄が映らない」状態に戻らないことを守るテスト。
@MainActor
final class MapRegionTests: XCTestCase {

    private func makeTyphoon(lat: Double, lon: Double) -> Typhoon {
        Typhoon(
            id: "JMA-TEST",
            name: "TESTER",
            nameJa: "台風第99号（テスト）",
            source: "JMA",
            status: "ACTIVE",
            currentCenter: Coordinate(lat: lat, lon: lon),
            maxWindSpeed: 45,
            centralPressure: 955,
            direction: 292,
            speed: 15,
            windRadii: WindRadii(radius34kt: 330, radius50kt: 220, radius64kt: 110),
            forecasts: [],
            lastUpdated: "2026-07-29T00:45:00Z"
        )
    }

    private func makeViewModel(typhoon: Typhoon?, locations: [SavedLocation]) -> TyphoonViewModel {
        let viewModel = TyphoonViewModel()
        viewModel.state = DemoStateResponse(
            typhoon: typhoon,
            risks: [],
            savedLocations: locations,
            lastUpdated: "2026-07-29T00:45:00Z"
        )
        return viewModel
    }

    private let naha = SavedLocation(
        id: "naha",
        name: "那覇",
        lat: 26.2124,
        lon: 127.6809,
        notificationLevel: "HIGH"
    )

    /// 台風がないときは沖縄本島周辺を映す。
    func testRegionStaysOnOkinawaWhenNoTyphoon() {
        let viewModel = makeViewModel(typhoon: nil, locations: [])
        let region = viewModel.mapRegion

        XCTAssertEqual(region.center.latitude, 26.2, accuracy: 0.5)
        XCTAssertEqual(region.center.longitude, 127.7, accuracy: 0.5)
    }

    /// 遠方（マーシャル諸島付近）の台風でカメラを持っていかれない。
    /// これを許すと太平洋のど真ん中が映り「地図に何も出ない」状態になる。
    func testRegionStaysOnOkinawaWhenTyphoonIsFarAway() {
        let typhoon = makeTyphoon(lat: 14.1, lon: 169.1)
        let viewModel = makeViewModel(typhoon: typhoon, locations: [naha])

        XCTAssertTrue(viewModel.isTyphoonFarAway)

        let region = viewModel.mapRegion
        XCTAssertEqual(region.center.latitude, naha.lat, accuracy: 0.5)
        XCTAssertEqual(region.center.longitude, naha.lon, accuracy: 0.5)
    }

    /// 接近中の台風は、拠点と台風の両方が入る範囲を映す。
    func testRegionCoversBothWhenTyphoonIsClose() {
        let typhoon = makeTyphoon(lat: 24.0, lon: 126.0)
        let viewModel = makeViewModel(typhoon: typhoon, locations: [naha])

        XCTAssertFalse(viewModel.isTyphoonFarAway)

        let region = viewModel.mapRegion
        let north = region.center.latitude + region.span.latitudeDelta / 2
        let south = region.center.latitude - region.span.latitudeDelta / 2
        let east = region.center.longitude + region.span.longitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2

        XCTAssertTrue((south...north).contains(naha.lat), "拠点が表示範囲に入っていない")
        XCTAssertTrue((west...east).contains(naha.lon), "拠点が表示範囲に入っていない")
        XCTAssertTrue((south...north).contains(typhoon.currentCenter.lat), "台風が表示範囲に入っていない")
        XCTAssertTrue((west...east).contains(typhoon.currentCenter.lon), "台風が表示範囲に入っていない")
    }

    /// 距離と方角は拠点（代表地点）から見た値になる。
    func testDistanceAndDirectionAreMeasuredFromAnchor() throws {
        let typhoon = makeTyphoon(lat: 26.2, lon: 140.0)
        let viewModel = makeViewModel(typhoon: typhoon, locations: [naha])

        let distance = try XCTUnwrap(viewModel.typhoonDistanceKm)
        XCTAssertEqual(distance, 1230, accuracy: 150)
        XCTAssertEqual(viewModel.typhoonDirectionFromAnchor, "東")
        XCTAssertEqual(viewModel.mapAnchorName, "那覇")
    }

    /// 保存場所がないときは沖縄本島を基準名にする（「現在地」と誤表示しない）。
    func testAnchorNameFallsBackToOkinawa() {
        let viewModel = makeViewModel(typhoon: nil, locations: [])
        XCTAssertEqual(viewModel.mapAnchorName, "沖縄本島")
    }

    /// 台風が入れ替わったらカメラを組み直すためのキーが変わる。
    func testFocusKeyChangesWithTyphoon() {
        let withoutTyphoon = makeViewModel(typhoon: nil, locations: [naha])
        let withTyphoon = makeViewModel(typhoon: makeTyphoon(lat: 24.0, lon: 126.0), locations: [naha])

        XCTAssertNotEqual(withoutTyphoon.mapFocusKey, withTyphoon.mapFocusKey)
    }
}
