import XCTest
@testable import TyphoonRiskNavi

final class JMAWarningFetcherTests: XCTestCase {

    func testParsesActiveWarningsAndSkipsCancelled() throws {
        let json = """
        {
          "reportDatetime": "2026-07-22T12:00:00+09:00",
          "publishingOffice": "沖縄気象台",
          "headlineText": "強風と高波に注意してください。",
          "areaTypes": [
            {
              "areas": [
                {
                  "code": "471010",
                  "warnings": [
                    { "code": "15", "status": "発表" },
                    { "code": "20", "status": "解除" }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let warning = try JMAWarningFetcher.parseWarning(
            data: json,
            officeCode: "471000",
            areaName: "沖縄本島地方"
        )

        XCTAssertEqual(warning.areaName, "沖縄本島地方")
        XCTAssertTrue(warning.warningNames.contains("強風注意報"))
        XCTAssertFalse(warning.warningNames.contains("濃霧注意報"))
        XCTAssertTrue(warning.hasActiveWarning)
    }

    func testCancelledOnlyHasNoActiveWarnings() throws {
        let json = """
        {
          "reportDatetime": "2026-07-22T12:00:00+09:00",
          "headlineText": "注意報を解除します。",
          "areaTypes": [
            {
              "areas": [
                {
                  "code": "473000",
                  "warnings": [
                    { "code": "20", "status": "解除" }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let warning = try JMAWarningFetcher.parseWarning(
            data: json,
            officeCode: "473000",
            areaName: "宮古島地方"
        )

        XCTAssertFalse(warning.hasActiveWarning)
        XCTAssertTrue(warning.warningNames.isEmpty)
    }
}
