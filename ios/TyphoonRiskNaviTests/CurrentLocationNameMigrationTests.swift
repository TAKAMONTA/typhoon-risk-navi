import XCTest
@testable import TyphoonRiskNavi

/// 旧バージョンの「現在地を追加」が生成していた時刻入りの名前（例: 「現在地 (11:49)」）を、
/// 「何時何分に登録したか」がひと目で分かる表記（例: 「現在地（11時49分に登録）」）に
/// 書き換える後始末のテスト。
///
/// - 自動生成パターンに完全一致する名前だけを対象にする（前後に余計な文字があれば対象外）
/// - ユーザーが編集した名前（「現在地 (自宅)」など）は絶対に変更しない
/// - 時刻表記は捨てず、パースできれば「H時mm分」に正規化し、できなければそのまま差し込む
/// - 名前以外のフィールド（id・座標・通知レベル）は変更しない
/// - 実行済みフラグを持たない（毎回の呼び出しで再評価する）ので、複数回実行しても結果は変わらない
@MainActor
final class CurrentLocationNameMigrationTests: XCTestCase {

    /// 実キーと衝突させないため、注入できるキー名はテスト専用のものを使う。
    private let storeKey = "test_saved_locations_migration"
    private let seedFlagKey = "test_has_seeded_demo_locations_migration"
    private let purgeFlagKey = "test_has_purged_demo_locations_migration"

    /// テストごとに専用スイートを使う。標準の UserDefaults を使うとテスト同士や
    /// 実機の保存データと干渉する。開始前と終了後の両方で必ず消す。
    private func withIsolatedDefaults(
        _ testName: String = #function,
        _ body: (UserDefaults) throws -> Void
    ) rethrows {
        let suiteName = "CurrentLocationNameMigrationTests."
            + testName.replacingOccurrences(of: "()", with: "")
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("テスト用の UserDefaults スイートを作れませんでした: \(suiteName)")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    /// 「アプリを起動した」状態に相当するストアを作る。
    /// 永続化を跨いだ挙動を見たいので、起動のたびに新しいインスタンスを作る。
    private func makeStore(_ defaults: UserDefaults) -> LocalLocationStore {
        LocalLocationStore(
            defaults: defaults,
            storeKey: storeKey,
            seedFlagKey: seedFlagKey,
            purgeFlagKey: purgeFlagKey
        )
    }

    /// 既に端末へ保存されている状態（＝アップデート前から残っているデータ）を用意する。
    private func preload(_ locations: [SavedLocation], into defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(locations)
        defaults.set(data, forKey: storeKey)
    }

    /// 1件だけ投入して移行を実行し、書き換え後の名前を返すヘルパー。
    private func clarifiedName(for originalName: String, in defaults: UserDefaults) throws -> String? {
        let location = SavedLocation(id: "loc-0", name: originalName, lat: 26.2, lon: 127.7, notificationLevel: "MEDIUM")
        try preload([location], into: defaults)
        let store = makeStore(defaults)
        store.clarifyCurrentLocationNamesIfNeeded()
        return store.locations.first?.name
    }

    // MARK: - 純粋な時刻表記は H時mm分 に正規化される

    /// 午前/午後・AM/PM を含まない純粋な時刻表記（半角コロン・ピリオド区切り）は、
    /// 新規登録と同じ「H時mm分」形式に正規化される。
    func testClarifiesPureTimeFormatsToHourMinuteFormat() throws {
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(try clarifiedName(for: "現在地 (11:49)", in: defaults), "現在地（11時49分に登録）")
        }
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(try clarifiedName(for: "現在地 (9:05)", in: defaults), "現在地（9時05分に登録）")
        }
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(try clarifiedName(for: "現在地 (15:05)", in: defaults), "現在地（15時05分に登録）")
        }
        try withIsolatedDefaults { defaults in
            // fi/da/id ロケールが生成しうるピリオド区切りも同じ形式に正規化される。
            XCTAssertEqual(try clarifiedName(for: "現在地 (11.49)", in: defaults), "現在地（11時49分に登録）")
        }
    }

    // MARK: - 解析できない表記は元のままカッコの中に差し込まれる

    /// 午前/午後・AM/PM を含む表記や、狭幅ノーブレークスペース区切りの表記は、
    /// 無理に解析せずキャプチャした文字列をそのまま「に登録」の前に差し込む。
    func testKeepsUnparsableTimeFormatsAsCaptured() throws {
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(try clarifiedName(for: "現在地 (午前11:49)", in: defaults), "現在地（午前11:49に登録）")
        }
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(try clarifiedName(for: "現在地 (午後3:05)", in: defaults), "現在地（午後3:05に登録）")
        }
        try withIsolatedDefaults { defaults in
            // U+202F（狭幅ノーブレークスペース）区切り。iOS 16+/ICU 72+ の en_US が実際に生成する表記。
            XCTAssertEqual(try clarifiedName(for: "現在地 (11:49\u{202F}AM)", in: defaults), "現在地（11:49\u{202F}AMに登録）")
        }
        try withIsolatedDefaults { defaults in
            // 半角スペース区切り（実機が生成しない可能性はあるが、両方カバーしておく）。
            XCTAssertEqual(try clarifiedName(for: "現在地 (11:49 AM)", in: defaults), "現在地（11:49 AMに登録）")
        }
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(try clarifiedName(for: "現在地 (3:05 pm)", in: defaults), "現在地（3:05 pmに登録）")
        }
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(try clarifiedName(for: "現在地 (11:49 am)", in: defaults), "現在地（11:49 amに登録）")
        }
    }

    // MARK: - 変更されないもの

    /// ユーザーが編集した名前や、そもそも自動生成パターンに一致しない名前は変更しない。
    /// 前後に余計な文字が付いているだけでも「完全一致」ではなくなるので対象外にする
    /// （アンカー ^ $ が効いていることの確認を兼ねる）。
    func testKeepsNonMatchingNamesUnchanged() throws {
        try withIsolatedDefaults { defaults in
            let untouched = [
                SavedLocation(id: "loc-home-edited", name: "現在地 (自宅)", lat: 26.21, lon: 127.68, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-home", name: "自宅", lat: 26.22, lon: 127.69, notificationLevel: "HIGH"),
                SavedLocation(id: "loc-onna", name: "恩納村", lat: 26.50, lon: 127.83, notificationLevel: "LOW"),
                SavedLocation(id: "loc-suffix-space", name: "現在地 (11:49) 追記", lat: 26.23, lon: 127.70, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-suffix", name: "現在地 (11:49)集合", lat: 26.24, lon: 127.71, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-no-space", name: "現在地(11:49)", lat: 26.25, lon: 127.72, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-fullwidth-space", name: "現在地　(11:49)", lat: 26.26, lon: 127.73, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-leading-space", name: " 現在地 (11:49)", lat: 26.27, lon: 127.74, notificationLevel: "MEDIUM"),
            ]
            try preload(untouched, into: defaults)

            let store = makeStore(defaults)
            store.clarifyCurrentLocationNamesIfNeeded()

            XCTAssertEqual(store.locations.map(\.name), untouched.map(\.name))
        }
    }

    /// 名前以外のフィールド（id・座標・通知レベル）は書き換え後も保持される。
    func testPreservesNonNameFieldsWhenClarifying() throws {
        try withIsolatedDefaults { defaults in
            let original = SavedLocation(
                id: "5A4C0F0E-0000-4000-8000-000000000009",
                name: "現在地 (11:49)",
                lat: 26.2458,
                lon: 127.7219,
                notificationLevel: "SEVERE"
            )
            try preload([original], into: defaults)

            let store = makeStore(defaults)
            store.clarifyCurrentLocationNamesIfNeeded()

            let clarified = try XCTUnwrap(store.locations.first)
            XCTAssertEqual(clarified.id, original.id)
            XCTAssertEqual(clarified.lat, original.lat)
            XCTAssertEqual(clarified.lon, original.lon)
            XCTAssertEqual(clarified.notificationLevel, original.notificationLevel)
            XCTAssertEqual(clarified.name, "現在地（11時49分に登録）")
        }
    }

    // MARK: - 冪等性（最重要）

    /// 実行済みフラグを持たないため、何度実行しても（＝何度アプリを起動しても）結果は変わらない。
    func testClarifyIsIdempotentAcrossRuns() throws {
        try withIsolatedDefaults { defaults in
            let locations = [
                SavedLocation(id: "loc-0", name: "現在地 (11:49)", lat: 26.2, lon: 127.7, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-1", name: "自宅", lat: 26.21, lon: 127.68, notificationLevel: "HIGH"),
            ]
            try preload(locations, into: defaults)

            let store = makeStore(defaults)
            store.clarifyCurrentLocationNamesIfNeeded()
            let afterFirstRun = store.locations.map(\.name)
            XCTAssertEqual(afterFirstRun, ["現在地（11時49分に登録）", "自宅"])

            // 同一インスタンスで連続実行しても結果は変わらない。
            store.clarifyCurrentLocationNamesIfNeeded()
            XCTAssertEqual(store.locations.map(\.name), afterFirstRun)

            // 新しいストアインスタンス（＝次回起動相当）で実行しても同じ結果になる。
            let relaunched = makeStore(defaults)
            relaunched.clarifyCurrentLocationNamesIfNeeded()
            XCTAssertEqual(relaunched.locations.map(\.name), ["現在地（11時49分に登録）", "自宅"])
        }
    }

    /// マイグレーション後の名前（全角カッコ・「に登録」を含む）が最初から保存されていても、
    /// 二重に「に登録」が付くなどの退行が起きないことを直接検証する。
    /// 新しい表記は半角カッコを使う旧パターンには一致しないはず、という不変条件そのものを見る。
    ///
    /// 特に、時刻表記をそのまま保持したパス（カッコ内に半角の "H:mm" や AM/PM が残る形）は
    /// 見た目上は旧パターンに近く、再マッチのリスクが高いので個別に確認する。
    /// 「現在地（11:49）」（全角カッコだが「に登録」が無い形）はユーザーが手で打ちうる名前として含める。
    func testAlreadyClarifiedNameIsNotRewrittenAgain() throws {
        try withIsolatedDefaults { defaults in
            let alreadyClarified = [
                SavedLocation(id: "loc-pure", name: "現在地（11時49分に登録）", lat: 26.2, lon: 127.7, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-am-pm-prefix", name: "現在地（午前11:49に登録）", lat: 26.21, lon: 127.71, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-narrow-space-am", name: "現在地（11:49\u{202F}AMに登録）", lat: 26.22, lon: 127.72, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-pm-dotted", name: "現在地（3:05 p.m.に登録）", lat: 26.23, lon: 127.73, notificationLevel: "MEDIUM"),
                SavedLocation(id: "loc-fullwidth-no-suffix", name: "現在地（11:49）", lat: 26.24, lon: 127.74, notificationLevel: "MEDIUM"),
            ]
            try preload(alreadyClarified, into: defaults)

            let store = makeStore(defaults)
            store.clarifyCurrentLocationNamesIfNeeded()

            XCTAssertEqual(store.locations.map(\.name), alreadyClarified.map(\.name))
        }
    }
}
