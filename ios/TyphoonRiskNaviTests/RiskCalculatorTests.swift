import XCTest
@testable import TyphoonRiskNavi

final class RiskCalculatorTests: XCTestCase {

    // MARK: - Test Fixtures

    /// 沖縄に北西から接近する典型的なデモ台風
    private func makeTyphoon(now: Date = Date()) -> Typhoon {
        let iso = ISO8601DateFormatter()
        let f1 = ForecastPoint(
            validTime: iso.string(from: now.addingTimeInterval(6 * 3600)),
            center: Coordinate(lat: 24.2, lon: 126.8),
            radius: 165,
            maxWindSpeed: 40.0,
            windRadii: WindRadii(radius34kt: 270, radius50kt: 100, radius64kt: 50)
        )
        let f2 = ForecastPoint(
            validTime: iso.string(from: now.addingTimeInterval(18 * 3600)),
            center: Coordinate(lat: 25.4, lon: 127.0),
            radius: 175,
            maxWindSpeed: 36.0,
            windRadii: WindRadii(radius34kt: 230, radius50kt: 80, radius64kt: 35)
        )
        let f3 = ForecastPoint(
            validTime: iso.string(from: now.addingTimeInterval(30 * 3600)),
            center: Coordinate(lat: 26.3, lon: 127.5),
            radius: 180,
            maxWindSpeed: 31.0,
            windRadii: WindRadii(radius34kt: 190, radius50kt: 55, radius64kt: 20)
        )
        return Typhoon(
            id: "TEST-1",
            name: "TEST",
            nameJa: "テスト",
            source: "DEMO",
            status: "ACTIVE",
            currentCenter: Coordinate(lat: 22.5, lon: 126.5),
            maxWindSpeed: 43.7,
            centralPressure: 950,
            direction: 340,
            speed: 20.0,
            windRadii: WindRadii(radius34kt: 290, radius50kt: 115, radius64kt: 60),
            forecasts: [f1, f2, f3],
            lastUpdated: iso.string(from: now)
        )
    }

    private let naha = SavedLocation(
        id: "naha",
        name: "那覇市",
        lat: 26.21, lon: 127.68,
        notificationLevel: "SEVERE"
    )

    private let tokyo = SavedLocation(
        id: "tokyo",
        name: "東京",
        lat: 35.68, lon: 139.77,
        notificationLevel: "LOW"
    )

    // MARK: - determineRiskLevel

    func testRiskLevelSEVEREWhen64ktSoon() {
        XCTAssertEqual(RiskCalculator.determineRiskLevel(hours34: 2, hours50: 2, hours64: 6), "SEVERE")
    }
    func testRiskLevelHIGHWhen50ktSoon() {
        XCTAssertEqual(RiskCalculator.determineRiskLevel(hours34: 2, hours50: 6, hours64: nil), "HIGH")
    }
    func testRiskLevelHIGHWhen34ktSoon() {
        XCTAssertEqual(RiskCalculator.determineRiskLevel(hours34: 6, hours50: nil, hours64: nil), "HIGH")
    }
    func testRiskLevelMEDIUMWhen34ktWithin24h() {
        XCTAssertEqual(RiskCalculator.determineRiskLevel(hours34: 18, hours50: nil, hours64: nil), "MEDIUM")
    }
    func testRiskLevelLOWForFar34kt() {
        XCTAssertEqual(RiskCalculator.determineRiskLevel(hours34: 36, hours50: nil, hours64: nil), "LOW")
    }
    func testRiskLevelLOWForNoData() {
        XCTAssertEqual(RiskCalculator.determineRiskLevel(hours34: nil, hours50: nil, hours64: nil), "LOW")
    }

    // MARK: - radiusForKnots

    func testRadiusForKnotsReturnsCorrectBand() {
        let radii = WindRadii(radius34kt: 290, radius50kt: 115, radius64kt: 60)
        XCTAssertEqual(RiskCalculator.radiusForKnots(radii, targetKnots: 34), 290)
        XCTAssertEqual(RiskCalculator.radiusForKnots(radii, targetKnots: 50), 115)
        XCTAssertEqual(RiskCalculator.radiusForKnots(radii, targetKnots: 64), 60)
        XCTAssertNil(RiskCalculator.radiusForKnots(radii, targetKnots: 100))
    }
    func testRadiusForKnotsReturnsNilForNilInput() {
        XCTAssertNil(RiskCalculator.radiusForKnots(nil, targetKnots: 34))
    }

    // MARK: - computeDynamicDecayRate

    func testDecayRateForSinglePointStaysAtBase() {
        let iso = ISO8601DateFormatter()
        let t = Typhoon(
            id: "x", name: "X", nameJa: nil, source: "DEMO", status: "ACTIVE",
            currentCenter: Coordinate(lat: 22, lon: 126),
            maxWindSpeed: nil, centralPressure: nil, direction: nil, speed: nil,
            windRadii: nil, forecasts: [], lastUpdated: iso.string(from: Date())
        )
        XCTAssertEqual(RiskCalculator.computeDynamicDecayRate(for: t), 0.08, accuracy: 0.0001)
    }

    func testDecayRateClampedRange() {
        let r = RiskCalculator.computeDynamicDecayRate(for: makeTyphoon())
        XCTAssertGreaterThanOrEqual(r, 0.04)
        XCTAssertLessThanOrEqual(r, 0.16)
    }

    // MARK: - assess

    func testAssessProducesArrivalForNearbyLocation() {
        let typhoon = makeTyphoon()
        let assessment = RiskCalculator.assess(location: naha, typhoon: typhoon)
        XCTAssertNotNil(assessment.arrival34kt)
        if let h = assessment.arrival34kt?.hours {
            XCTAssertGreaterThan(h, 0)
            XCTAssertLessThan(h, 48)
        }
    }

    func testAssessReturnsLOWForFarLocation() {
        let typhoon = makeTyphoon()
        let assessment = RiskCalculator.assess(location: tokyo, typhoon: typhoon)
        XCTAssertEqual(assessment.riskLevel, "LOW")
    }

    func testAssessIncludesPrecisionModelNote() {
        let typhoon = makeTyphoon()
        let assessment = RiskCalculator.assess(location: naha, typhoon: typhoon)
        let hasPrecisionNote = (assessment.notes ?? []).contains(where: { $0.contains("精度モデル") })
        XCTAssertTrue(hasPrecisionNote)
    }

    func testAssessAllReturnsSameOrder() {
        let typhoon = makeTyphoon()
        let locs = [naha, tokyo]
        let result = RiskCalculator.assessAll(locations: locs, typhoon: typhoon)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].locationId, "naha")
        XCTAssertEqual(result[1].locationId, "tokyo")
    }

    // MARK: - distanceKm

    func testDistanceKmRoughlyMatches() {
        let d = RiskCalculator.distanceKm(
            from: .init(latitude: 26.21, longitude: 127.68),
            to: .init(latitude: 26.21, longitude: 127.68)
        )
        XCTAssertEqual(d, 0, accuracy: 0.01)
    }

    func testDistanceKmNonZero() {
        // 那覇 ↔ 東京 ≒ 1550 km 前後
        let d = RiskCalculator.distanceKm(
            from: .init(latitude: 26.21, longitude: 127.68),
            to: .init(latitude: 35.68, longitude: 139.77)
        )
        XCTAssertGreaterThan(d, 1400)
        XCTAssertLessThan(d, 1700)
    }
}
