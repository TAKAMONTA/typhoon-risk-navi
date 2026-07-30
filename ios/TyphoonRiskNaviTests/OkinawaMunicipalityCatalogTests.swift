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
}
