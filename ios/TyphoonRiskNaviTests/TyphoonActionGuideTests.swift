import XCTest
@testable import TyphoonRiskNavi

final class TyphoonActionGuideTests: XCTestCase {

    func testSevereHasMostUrgentFirst() {
        let steps = TyphoonActionGuide.steps(forRiskLevel: "SEVERE")
        XCTAssertGreaterThanOrEqual(steps.count, 3)
        XCTAssertTrue(steps[0].text.contains("避難") || steps[0].text.lowercased().contains("evacuat"))
    }

    func testQuietPeriodHasPrepSteps() {
        let steps = TyphoonActionGuide.quietPeriodSteps
        XCTAssertEqual(steps.count, 3)
    }

    func testLowLevelReturnsSteps() {
        let steps = TyphoonActionGuide.steps(forRiskLevel: "LOW")
        XCTAssertFalse(steps.isEmpty)
    }
}
