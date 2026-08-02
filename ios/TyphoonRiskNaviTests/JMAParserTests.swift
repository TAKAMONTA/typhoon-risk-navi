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

    // MARK: - 熱帯低気圧（typhoonNumber が英字仮番号）の防御

    func testTropicalDepressionNameJaIsNotTyphoonNumberFormat() {
        let tdJSON: [[String: Any]] = [
            [
                "part": "title",
                "issue": ["JST": "2026-08-02T10:15:00+09:00"],
                "typhoonNumber": "b",
                "category": ["jp": "熱帯低気圧", "en": "TD"],
            ],
            [
                "part": ["jp": "実況", "en": "Analysis"],
                "advancedHours": 0,
                "position": ["deg": [20.0, 130.0]],
            ],
        ]
        guard let t = JMAParser.parseSpecificationsArray(tdJSON, eventId: "TC2616") else {
            XCTFail("Expected typhoon-shaped model even for TD")
            return
        }
        XCTAssertEqual(t.nameJa, "熱帯低気圧")
        XCTAssertNotEqual(t.nameJa, "台風第ｂ号")
        XCTAssertEqual(t.name, "TD")
    }
}

final class JMAFetcherTargetParsingTests: XCTestCase {

    /// ユーザー提供の実データそのまま（TD "b" + TY "2613"）。
    private let realTargetTcJSON: [[String: Any]] = [
        [
            "tropicalCyclone": "TC2616",
            "typhoonNumber": "b",
            "category": "TD",
            "issue": "2026-08-02T10:15:00+09:00",
        ],
        [
            "tropicalCyclone": "TC2615",
            "typhoonNumber": "2613",
            "category": "TY",
            "issue": "2026-08-02T09:45:00+09:00",
        ],
    ]

    func testParseActiveTargetsExcludesTropicalDepression() {
        let result = JMAFetcher.parseActiveTargets(realTargetTcJSON)
        XCTAssertEqual(result, ["TC2615"])
    }

    func testParseActiveTargetsReturnsEmptyWhenAllAreTropicalDepressions() {
        let allTD: [[String: Any]] = [
            ["tropicalCyclone": "TC2616", "typhoonNumber": "b", "category": "TD"],
            ["tropicalCyclone": "TC2617", "typhoonNumber": "c", "category": "TD"],
        ]
        XCTAssertEqual(JMAFetcher.parseActiveTargets(allTD), [])
    }

    // MARK: - 沖縄本島に近い順のソート

    private func makeTyphoon(id: String, lat: Double, lon: Double) -> Typhoon {
        Typhoon(
            id: id,
            name: "TEST",
            nameJa: nil,
            source: "JMA",
            status: "ACTIVE",
            currentCenter: Coordinate(lat: lat, lon: lon),
            maxWindSpeed: nil,
            centralPressure: nil,
            direction: nil,
            speed: nil,
            windRadii: nil,
            forecasts: [],
            lastUpdated: "2026-08-02T10:15:00+09:00"
        )
    }

    func testSortByProximityToOkinawaOrdersNearestFirst() {
        // 沖縄本島から遠い台風と近い台風を用意し、近い順に並ぶことを確認する。
        let far = makeTyphoon(id: "JMA-FAR", lat: 10.0, lon: 130.0)
        let near = makeTyphoon(id: "JMA-NEAR", lat: 26.0, lon: 127.5)
        let sorted = JMAFetcher.sortByProximityToOkinawa([far, near])
        XCTAssertEqual(sorted.map(\.id), ["JMA-NEAR", "JMA-FAR"])
    }
}
