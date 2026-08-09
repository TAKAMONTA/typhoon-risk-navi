import XCTest
@testable import TyphoonRiskNavi

/// 「現在地を追加」の名前の書式（CurrentLocationNaming）のテスト。
///
/// - 新規登録時の書式（"H時mm分"）が固定 Date に対して期待通りになること（ゼロ埋め・境界値を含む）
/// - タイムゾーンをテストから注入できること（CI 実行環境のタイムゾーンに結果が左右されない）
/// - 新規登録（name(at:)）と移行（name(timeText:)）が同じ入力に対して同じ文字列を返すこと
///   （書式が2箇所で食い違う退行を防ぐための回帰テスト）
final class CurrentLocationNamingTests: XCTestCase {

    /// テストをタイムゾーンに依存させないよう、JST (UTC+9) に固定する。
    private let jst = TimeZone(identifier: "Asia/Tokyo")!

    /// JST での年月日時分を指定して Date を作るヘルパー。
    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.timeZone = jst
        components.year = 2026
        components.month = 8
        components.day = 7
        components.hour = hour
        components.minute = minute
        components.second = 0
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)!
    }

    // MARK: - name(at:) の書式

    func testNameAtProducesHourMinuteFormat() {
        XCTAssertEqual(
            CurrentLocationNaming.name(at: date(hour: 11, minute: 49), timeZone: jst),
            "現在地（11時49分に登録）"
        )
    }

    /// 時は1桁のままゼロ埋めしないが、分は2桁にゼロ埋めする（"H時mm分" の仕様どおり）。
    func testNameAtZeroPadsMinuteButNotHour() {
        XCTAssertEqual(
            CurrentLocationNaming.name(at: date(hour: 9, minute: 5), timeZone: jst),
            "現在地（9時05分に登録）"
        )
    }

    func testNameAtMidnightBoundary() {
        XCTAssertEqual(
            CurrentLocationNaming.name(at: date(hour: 0, minute: 0), timeZone: jst),
            "現在地（0時00分に登録）"
        )
    }

    func testNameAtLastMinuteOfDayBoundary() {
        XCTAssertEqual(
            CurrentLocationNaming.name(at: date(hour: 23, minute: 59), timeZone: jst),
            "現在地（23時59分に登録）"
        )
    }

    // MARK: - 登録側と移行側の一致

    /// name(at:)（新規登録）と name(timeText:)（旧名からの移行）が、同じ時刻に対して
    /// 同じ文字列を返すことを複数の時刻で突き合わせる。
    /// 実装を2箇所で独立に持つと、片方だけ書式を変えたときに気づけない
    /// （例: リストに「09時05分」と「9時05分」が混在する）ため、この一致を直接固定する。
    func testRegistrationAndMigrationProduceSameStringForSameTime() {
        let cases: [(hour: Int, minute: Int, capturedTime: String)] = [
            (11, 49, "11:49"),
            (9, 5, "9:05"),
            (0, 0, "0:00"),
            (23, 59, "23:59"),
            (15, 5, "15:05"),
        ]
        for c in cases {
            let registered = CurrentLocationNaming.name(at: date(hour: c.hour, minute: c.minute), timeZone: jst)
            let migrated = CurrentLocationNaming.name(timeText: c.capturedTime)
            XCTAssertEqual(registered, migrated, "hour=\(c.hour) minute=\(c.minute) で登録側と移行側の表記が食い違っている")
        }
    }
}
