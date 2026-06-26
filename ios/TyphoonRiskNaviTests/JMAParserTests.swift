import XCTest
@testable import TyphoonRiskNavi

final class JMAParserTests: XCTestCase {

    /// TC2608 specifications.json に近い最小サンプル（個人情報・生産値は含まない）。
    private let sampleJSON: [[String: Any]] = [
        [
            "part": "title",
            "issue": ["JST": "2026-06-22T06:45:00+09:00", "UTC": "2026-06-21T21:45:00Z"],
            "typhoonNumber": "2607",
            "name": ["jp": "サンプル", "en": "Sample"],
            "category": ["jp": "台風", "en": "TY"],
        ],
        [
            "part": ["jp": "実況", "en": "Analysis"],
            "advancedHours": 0,
            "position": ["deg": [17.1, 128.2]],
            "maximumWind": ["sustained": ["m/s": "40", "kt": "80"]],
            "galeWarning": [
                ["area": "北", "range": ["km": 280, "nm": 150]],
                ["area": "南", "range": ["km": 220, "nm": 120]],
            ],
            "stormWarning": [
                ["area": ["jp": "全域", "en": "All"], "range": ["km": 110, "nm": 60]],
            ],
            "course": "西",
            "speed": ["km/h": "30", "kt": "15"],
            "pressure": "955",
            "validtime": ["JST": "2026-06-22T06:00:00+09:00", "UTC": "2026-06-21T21:00:00Z"],
        ],
        [
            "part": ["jp": "予報　１２時間後", "en": "Forecast for 12 hours ahead"],
            "advancedHours": 12,
            "position": ["deg": [18.0, 126.4]],
            "probabilityCircleRadius": ["km": 75, "nm": 40],
            "maximumWind": ["sustained": ["m/s": "45", "kt": "85"]],
            "stormWarning": [
                ["area": ["jp": "全域", "en": "All"], "range": ["km": 185, "nm": 100]],
            ],
            "validtime": ["JST": "2026-06-22T18:00:00+09:00", "UTC": "2026-06-22T09:00:00Z"],
        ],
    ]

    func testParsesTyphoonFromSample() {
        guard let t = JMAParser.parseSpecificationsArray(sampleJSON, eventId: "TC2608") else {
            XCTFail("Expected typhoon")
            return
        }
        XCTAssertEqual(t.id, "JMA-TC2608")
        XCTAssertEqual(t.source, "JMA")
        XCTAssertEqual(t.name, "SAMPLE")
        XCTAssertTrue(t.nameJa?.contains("サンプル") == true)
    }

    func testParsesCurrentPosition() {
        guard let t = JMAParser.parseSpecificationsArray(sampleJSON, eventId: "TC2608") else {
            XCTFail()
            return
        }
        XCTAssertEqual(t.currentCenter.lat, 17.1, accuracy: 0.001)
        XCTAssertEqual(t.currentCenter.lon, 128.2, accuracy: 0.001)
    }

    func testParsesWindRadii() {
        guard let t = JMAParser.parseSpecificationsArray(sampleJSON, eventId: "TC2608") else {
            XCTFail()
            return
        }
        XCTAssertEqual(t.windRadii?.radius34kt ?? 0, 280, accuracy: 0.1)
        XCTAssertEqual(t.windRadii?.radius64kt ?? 0, 110, accuracy: 0.1)
        XCTAssertEqual(t.windRadii?.radius50kt ?? 0, 195, accuracy: 0.1)
    }

    func testParsesForecasts() {
        guard let t = JMAParser.parseSpecificationsArray(sampleJSON, eventId: "TC2608") else {
            XCTFail()
            return
        }
        XCTAssertEqual(t.forecasts.count, 1)
        XCTAssertEqual(t.forecasts[0].center.lat, 18.0, accuracy: 0.001)
        XCTAssertEqual(t.forecasts[0].radius ?? 0, 75, accuracy: 0.1)
    }

    func testCourseToDegrees() {
        XCTAssertEqual(JMAParser.courseToDegrees("西"), 270)
        XCTAssertEqual(JMAParser.courseToDegrees("北"), 0)
        XCTAssertNil(JMAParser.courseToDegrees(nil))
    }

    func testReturnsNilForInvalidInput() {
        XCTAssertNil(JMAParser.parseSpecificationsArray([], eventId: "TC0000"))
    }
}
