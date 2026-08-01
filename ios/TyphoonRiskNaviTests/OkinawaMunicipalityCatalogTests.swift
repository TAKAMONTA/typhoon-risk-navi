import XCTest
import CoreLocation
@testable import TyphoonRiskNavi

final class OkinawaMunicipalityCatalogTests: XCTestCase {

    func testNearestToNahaIsNaha() {
        let coord = CLLocationCoordinate2D(latitude: 26.21, longitude: 127.68)
        let result = OkinawaMunicipalityCatalog.nearest(to: coord)
        XCTAssertEqual(result?.municipality.id, "naha")
        XCTAssertLessThan(result?.distanceKm ?? 999, 5)
    }

    func testNearestToIshigakiIsIshigaki() {
        let location = SavedLocation(
            id: "test-ishigaki",
            name: "石垣",
            lat: 24.34,
            lon: 124.16,
            notificationLevel: "MEDIUM"
        )
        let result = OkinawaMunicipalityCatalog.nearest(to: location)
        XCTAssertEqual(result?.municipality.id, "ishigaki")
    }

    func testNearestToMiyakoIsMiyakojima() {
        let coord = CLLocationCoordinate2D(latitude: 24.81, longitude: 125.28)
        let result = OkinawaMunicipalityCatalog.nearest(to: coord)
        XCTAssertEqual(result?.municipality.id, "miyakojima")
    }

    func testDisasterURLsAreHTTPS() {
        for municipality in OkinawaMunicipalityCatalog.all {
            XCTAssertEqual(municipality.disasterInfoURL.scheme, "https")
            XCTAssertEqual(municipality.evacuationInfoURL.scheme, "https")
        }
    }

    /// 沖縄県は41市町村。避難情報の誘導先が欠けないよう全件を収録する。
    func testCatalogCoversAll41Municipalities() {
        XCTAssertEqual(OkinawaMunicipalityCatalog.all.count, 41)
    }

    /// 座標の取り違え（緯度と経度の入れ替えなど）を検出する。
    /// 緯度の上限は沖縄県最北の自治体である伊平屋村（北緯約27.04度）を含める。
    /// 経度は西端の与那国町（東経約123.0度）から東端の北大東村（東経約131.3度）まで。
    func testAllCoordinatesAreWithinOkinawa() {
        for municipality in OkinawaMunicipalityCatalog.all {
            XCTAssertGreaterThanOrEqual(municipality.lat, 24.0, "\(municipality.name) の緯度が範囲外")
            XCTAssertLessThanOrEqual(municipality.lat, 27.1, "\(municipality.name) の緯度が範囲外")
            XCTAssertGreaterThanOrEqual(municipality.lon, 122.9, "\(municipality.name) の経度が範囲外")
            XCTAssertLessThanOrEqual(municipality.lon, 131.4, "\(municipality.name) の経度が範囲外")
        }
    }

    func testIDsAndNamesAreUnique() {
        let ids = OkinawaMunicipalityCatalog.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "id が重複している")

        let names = OkinawaMunicipalityCatalog.all.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count, "name が重複している")
    }

    func testNearestToYomitanIsYomitan() {
        let coord = CLLocationCoordinate2D(latitude: 26.3961, longitude: 127.7444)
        let result = OkinawaMunicipalityCatalog.nearest(to: coord)
        XCTAssertEqual(result?.municipality.name, "読谷村")
        XCTAssertLessThan(result?.distanceKm ?? 999, 5)
    }

    func testNearestToChatanIsChatan() {
        let coord = CLLocationCoordinate2D(latitude: 26.3201, longitude: 127.7638)
        let result = OkinawaMunicipalityCatalog.nearest(to: coord)
        XCTAssertEqual(result?.municipality.name, "北谷町")
        XCTAssertLessThan(result?.distanceKm ?? 999, 5)
    }

    func testNearestToHaebaruIsHaebaru() {
        let coord = CLLocationCoordinate2D(latitude: 26.1911, longitude: 127.7285)
        let result = OkinawaMunicipalityCatalog.nearest(to: coord)
        XCTAssertEqual(result?.municipality.name, "南風原町")
        XCTAssertLessThan(result?.distanceKm ?? 999, 5)
    }

    /// 離島が本島付近に紛れ込んでいないかを代表点で確認する。
    func testRemoteIslandsAreNotMappedToMainIsland() {
        let cases: [(String, CLLocationCoordinate2D)] = [
            ("南大東村", CLLocationCoordinate2D(latitude: 25.8288, longitude: 131.2321)),
            ("久米島町", CLLocationCoordinate2D(latitude: 26.3407, longitude: 126.8049)),
            ("多良間村", CLLocationCoordinate2D(latitude: 24.6693, longitude: 124.7016)),
            ("粟国村", CLLocationCoordinate2D(latitude: 26.5818, longitude: 127.2289)),
        ]
        for (name, coord) in cases {
            let result = OkinawaMunicipalityCatalog.nearest(to: coord)
            XCTAssertEqual(result?.municipality.name, name)
        }
    }
}
