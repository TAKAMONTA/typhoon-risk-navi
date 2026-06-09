import XCTest
@testable import TyphoonRiskNavi

final class JTWCParserTests: XCTestCase {

    /// 実 JTWC に近いサンプル警告。最新/旧形式の wind radii を両方含む。
    private let sample = """
    WTPN31 PGTW 300300
    SUBJ/TYPHOON 06W (KONG-REY) WARNING NR 012//
    1. TYPHOON 06W (KONG-REY) LOCATED AT 30.1N 127.8E AT 300000Z
       MOVEMENT PAST SIX HOURS  315 DEGREES AT 12 KTS
       MAX SUSTAINED WINDS - 065 KT, GUSTS 080 KT
       CENTRAL PRESSURE 965 MB
       RADIUS OF 034 KT WINDS - 120 NM NORTHEAST QUADRANT
       RADIUS OF 050 KT WINDS -  60 NM NORTHEAST QUADRANT
       RADIUS OF 064 KT WINDS -  25 NM NORTHEAST QUADRANT
    2. FORECASTS:
       6 HRS, VALID AT:
       300600Z --- 31.0N 126.5E
       MAX SUSTAINED WINDS - 060 KT, GUSTS 075 KT
       RADIUS OF 034 KT WINDS - 090 NM NORTHEAST QUADRANT
       RADIUS OF 050 KT WINDS -  40 NM NORTHEAST QUADRANT
       12 HRS, VALID AT:
       301200Z --- 32.2N 125.0E
       MAX SUSTAINED WINDS - 055 KT, GUSTS 070 KT
    """

    func testParsesOneTyphoonFromSample() {
        let typhoons = JTWCParser.parseWarnings(sample)
        XCTAssertEqual(typhoons.count, 1)
    }

    func testParsesNumberAndName() {
        guard let t = JTWCParser.parseWarnings(sample).first else { XCTFail(); return }
        XCTAssertEqual(t.id, "JTWC-06W")
        XCTAssertEqual(t.name, "KONG-REY")
    }

    func testParsesCurrentPosition() {
        guard let t = JTWCParser.parseWarnings(sample).first else { XCTFail(); return }
        XCTAssertEqual(t.currentCenter.lat, 30.1, accuracy: 0.001)
        XCTAssertEqual(t.currentCenter.lon, 127.8, accuracy: 0.001)
    }

    func testParsesIntensity() {
        guard let t = JTWCParser.parseWarnings(sample).first else { XCTFail(); return }
        // 65 kt → 65 * 0.51444 m/s
        XCTAssertEqual(t.maxWindSpeed ?? 0, 65 * 0.51444, accuracy: 0.01)
        XCTAssertEqual(t.centralPressure, 965)
        XCTAssertEqual(t.direction, 315)
        // 12 kt → 12 * 1.852 km/h
        XCTAssertEqual(t.speed ?? 0, 12 * 1.852, accuracy: 0.01)
    }

    func testParsesWindRadii() {
        guard let t = JTWCParser.parseWarnings(sample).first else { XCTFail(); return }
        // 120 NM → 222.24 km
        XCTAssertEqual(t.windRadii?.radius34kt ?? 0, 120 * 1.852, accuracy: 0.1)
        XCTAssertEqual(t.windRadii?.radius50kt ?? 0, 60 * 1.852, accuracy: 0.1)
        XCTAssertEqual(t.windRadii?.radius64kt ?? 0, 25 * 1.852, accuracy: 0.1)
    }

    func testParsesForecasts() {
        guard let t = JTWCParser.parseWarnings(sample).first else { XCTFail(); return }
        XCTAssertEqual(t.forecasts.count, 2)

        let f1 = t.forecasts[0]
        XCTAssertEqual(f1.center.lat, 31.0, accuracy: 0.001)
        XCTAssertEqual(f1.center.lon, 126.5, accuracy: 0.001)
        XCTAssertEqual(f1.windRadii?.radius34kt ?? 0, 90 * 1.852, accuracy: 0.1)
        XCTAssertEqual(f1.windRadii?.radius50kt ?? 0, 40 * 1.852, accuracy: 0.1)
        XCTAssertNil(f1.windRadii?.radius64kt)

        let f2 = t.forecasts[1]
        XCTAssertEqual(f2.center.lat, 32.2, accuracy: 0.001)
        XCTAssertEqual(f2.center.lon, 125.0, accuracy: 0.001)
        XCTAssertNil(f2.windRadii)
    }

    func testReturnsEmptyForGarbageInput() {
        XCTAssertEqual(JTWCParser.parseWarnings("これは関係ないテキストです").count, 0)
        XCTAssertEqual(JTWCParser.parseWarnings("").count, 0)
    }

    func testSkipsWarningWithoutPosition() {
        let noPosition = """
        WTPN31 PGTW 300300
        SUBJ/TYPHOON 07W (UNKNOWN) WARNING NR 001//
        1. TYPHOON 07W (UNKNOWN)
           MAX SUSTAINED WINDS - 045 KT
        """
        XCTAssertEqual(JTWCParser.parseWarnings(noPosition).count, 0)
    }

    func testHandlesNearFormatPosition() {
        let nearFormat = """
        WTPN31 PGTW 300300
        SUBJ/TYPHOON 08W (PLACEHOLDER) WARNING NR 001//
        300600Z --- NEAR 18.3N 129.6E
        TYPHOON 08W (PLACEHOLDER)
        MAX SUSTAINED WINDS - 030 KT
        """
        guard let t = JTWCParser.parseWarnings(nearFormat).first else { XCTFail(); return }
        XCTAssertEqual(t.currentCenter.lat, 18.3, accuracy: 0.001)
        XCTAssertEqual(t.currentCenter.lon, 129.6, accuracy: 0.001)
    }
}
