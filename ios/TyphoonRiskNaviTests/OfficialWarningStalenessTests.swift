import XCTest
@testable import TyphoonRiskNavi

final class OfficialWarningStalenessTests: XCTestCase {

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func makeWarning(reportDatetime: String) -> OfficialWarning {
        OfficialWarning(
            id: "471000",
            areaName: "沖縄本島地方",
            headline: "強風に注意してください。",
            warningNames: ["強風注意報"],
            reportDatetime: reportDatetime,
            detailURL: URL(string: "https://www.jma.go.jp/bosai/warning/")!
        )
    }

    func testFreshReportIsNotStale() {
        let warning = makeWarning(reportDatetime: isoFormatter.string(from: Date()))
        XCTAssertFalse(warning.isStale)
    }

    func test48HoursOldReportIsStale() {
        let oldDate = Date().addingTimeInterval(-48 * 60 * 60)
        let warning = makeWarning(reportDatetime: isoFormatter.string(from: oldDate))
        XCTAssertTrue(warning.isStale)
    }

    func testEmptyReportDatetimeIsStale() {
        let warning = makeWarning(reportDatetime: "")
        XCTAssertTrue(warning.isStale)
    }

    func testUnparsableReportDatetimeIsStale() {
        let warning = makeWarning(reportDatetime: "not-a-date")
        XCTAssertTrue(warning.isStale)
    }

    func testReportDateDescriptionFormatsAsJapanese() {
        let date = Date().addingTimeInterval(-3 * 60 * 60)
        let warning = makeWarning(reportDatetime: isoFormatter.string(from: date))

        let expectedFormatter = DateFormatter()
        expectedFormatter.locale = Locale(identifier: "ja_JP")
        expectedFormatter.dateFormat = "M月d日"
        let expectedDatePart = expectedFormatter.string(from: date)

        let description = warning.reportDateDescription
        XCTAssertNotNil(description)
        XCTAssertTrue(description?.contains(expectedDatePart) ?? false)
        XCTAssertTrue(description?.hasSuffix(" 発表") ?? false)
    }

    func testReportDateDescriptionNilWhenUnparsable() {
        let warning = makeWarning(reportDatetime: "invalid")
        XCTAssertNil(warning.reportDateDescription)
    }
}
