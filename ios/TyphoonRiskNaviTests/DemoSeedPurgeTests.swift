import XCTest
@testable import TyphoonRiskNavi

/// 旧バージョンが初回起動時に投入していたデモ場所（那覇市 SEVERE、恩納村 LOW など）の
/// 後始末を守るテスト。
///
/// - 新規インストールでは1件も作らない（登録していない土地の危険度・通知を出さない）
/// - 既存端末に残っている未編集のデモ場所だけを、一度だけ消す
/// - ユーザーが編集した／自分で追加した場所は消さない
@MainActor
final class DemoSeedPurgeTests: XCTestCase {

    /// 実キーと衝突させないため、注入できるキー名はテスト専用のものを使う。
    /// 同時に「新しい削除済みフラグのキーが注入可能である」ことの確認も兼ねる。
    private let storeKey = "test_saved_locations"
    private let seedFlagKey = "test_has_seeded_demo_locations"
    private let purgeFlagKey = "test_has_purged_demo_locations"

    /// ユーザー自身が「現在地を追加」で登録した場所（id は UUID）。
    private let userAdded = SavedLocation(
        id: "5A4C0F0E-0000-4000-8000-000000000001",
        name: "現在地 (10:30)",
        lat: 26.2458,
        lon: 127.7219,
        notificationLevel: "MEDIUM"
    )

    /// テストごとに専用スイートを使う。標準の UserDefaults を使うとテスト同士や
    /// 実機の保存データと干渉する。開始前と終了後の両方で必ず消す。
    private func withIsolatedDefaults(
        _ testName: String = #function,
        _ body: (UserDefaults) throws -> Void
    ) rethrows {
        let suiteName = "DemoSeedPurgeTests."
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

    // MARK: - 新規インストール

    /// 新規インストール相当。起動処理を通しても保存場所は0件のまま。
    /// ここで1件でも増えると、ユーザーが登録していない土地の危険度・通知が出てしまう。
    func testFreshInstallCreatesNoLocations() {
        withIsolatedDefaults { defaults in
            let store = makeStore(defaults)
            XCTAssertTrue(store.locations.isEmpty)

            store.purgeDemoSeedsIfNeeded()
            XCTAssertTrue(store.locations.isEmpty)

            // 次回起動でも増えない（永続化側にも書かれていない）。
            let relaunched = makeStore(defaults)
            relaunched.purgeDemoSeedsIfNeeded()
            XCTAssertTrue(relaunched.locations.isEmpty)
        }
    }

    // MARK: - 既存端末のクリーンアップ

    /// 未編集のデモ場所5件は、まとめて消える。
    func testPurgesUntouchedDemoSeeds() throws {
        try withIsolatedDefaults { defaults in
            try preload(DemoData.seedLocations, into: defaults)

            let store = makeStore(defaults)
            XCTAssertEqual(store.locations.count, 5)

            store.purgeDemoSeedsIfNeeded()
            XCTAssertTrue(store.locations.isEmpty)

            // 削除は永続化される（次回起動で復活しない）。
            let relaunched = makeStore(defaults)
            XCTAssertTrue(relaunched.locations.isEmpty)
        }
    }

    /// 通知レベルだけ変えたデモ場所は「地点としては未編集」とみなして消す。
    /// 通知の設定を触っただけでは、その土地を自分の場所として使っている根拠にならないため。
    func testPurgesSeedWithChangedNotificationLevelOnly() throws {
        try withIsolatedDefaults { defaults in
            let onna = try XCTUnwrap(DemoData.seedLocations.first { $0.id == "seed-onna" })
            let levelChanged = SavedLocation(
                id: onna.id,
                name: onna.name,
                lat: onna.lat,
                lon: onna.lon,
                notificationLevel: "SEVERE"
            )
            try preload([levelChanged], into: defaults)

            let store = makeStore(defaults)
            store.purgeDemoSeedsIfNeeded()

            XCTAssertTrue(store.locations.isEmpty)
        }
    }

    // MARK: - 消してはいけないもの

    /// ユーザーが名前や座標を編集したデモ場所は残す。
    /// 自分の場所として使い続けている可能性があり、黙って消すと避難判断の材料を奪う。
    func testKeepsUserEditedSeeds() throws {
        try withIsolatedDefaults { defaults in
            let onna = try XCTUnwrap(DemoData.seedLocations.first { $0.id == "seed-onna" })
            let renamed = SavedLocation(
                id: onna.id,
                name: "自宅",
                lat: onna.lat,
                lon: onna.lon,
                notificationLevel: onna.notificationLevel
            )
            let ishigaki = try XCTUnwrap(DemoData.seedLocations.first { $0.id == "seed-ishigaki" })
            let moved = SavedLocation(
                id: ishigaki.id,
                name: ishigaki.name,
                lat: ishigaki.lat + 0.05,
                lon: ishigaki.lon,
                notificationLevel: ishigaki.notificationLevel
            )
            let untouched = DemoData.seedLocations.filter {
                $0.id != renamed.id && $0.id != moved.id
            }
            try preload(untouched + [renamed, moved], into: defaults)

            let store = makeStore(defaults)
            store.purgeDemoSeedsIfNeeded()

            XCTAssertEqual(Set(store.locations.map(\.id)), [renamed.id, moved.id])
            XCTAssertEqual(store.locations.first { $0.id == renamed.id }?.name, "自宅")
        }
    }

    /// ユーザー自身が追加した場所（id が UUID）は、デモ場所と一緒に消さない。
    func testKeepsUserCreatedLocations() throws {
        try withIsolatedDefaults { defaults in
            try preload(DemoData.seedLocations + [userAdded], into: defaults)

            let store = makeStore(defaults)
            store.purgeDemoSeedsIfNeeded()

            XCTAssertEqual(store.locations.map(\.id), [userAdded.id])
        }
    }

    /// デモ場所と同じ名前・座標でも、ユーザーが自分で登録した場所（id が UUID）は残す。
    /// 那覇市に住んでいて自分で「那覇市」を登録したユーザーを巻き込まないため。
    func testKeepsUserCreatedLocationThatLooksLikeSeed() throws {
        try withIsolatedDefaults { defaults in
            let naha = try XCTUnwrap(DemoData.seedLocations.first { $0.id == "seed-naha" })
            let ownNaha = SavedLocation(
                id: "5A4C0F0E-0000-4000-8000-000000000002",
                name: naha.name,
                lat: naha.lat,
                lon: naha.lon,
                notificationLevel: naha.notificationLevel
            )
            try preload(DemoData.seedLocations + [ownNaha], into: defaults)

            let store = makeStore(defaults)
            store.purgeDemoSeedsIfNeeded()

            XCTAssertEqual(store.locations.map(\.id), [ownNaha.id])
        }
    }

    // MARK: - 一度だけ

    /// 削除は一度きり。フラグが立ったあとは、デモ場所と同じ内容のデータが入っていても消さない。
    /// 毎起動で消し続けると、ユーザーが意図して作った場所を勝手に消し続けることになる。
    func testPurgeRunsOnlyOnce() throws {
        try withIsolatedDefaults { defaults in
            try preload(DemoData.seedLocations, into: defaults)

            let store = makeStore(defaults)
            store.purgeDemoSeedsIfNeeded()
            XCTAssertTrue(store.locations.isEmpty)
            XCTAssertTrue(defaults.bool(forKey: purgeFlagKey))

            // 削除後にユーザーが同じ内容の場所を作り直した状況を模す。
            try preload(DemoData.seedLocations, into: defaults)

            let relaunched = makeStore(defaults)
            relaunched.purgeDemoSeedsIfNeeded()
            XCTAssertEqual(relaunched.locations.count, 5)
        }
    }

    /// 消すものが無い起動でもフラグは立てる（判定を毎回走らせない）。
    func testMarksPurgeDoneEvenWhenNothingToRemove() throws {
        try withIsolatedDefaults { defaults in
            try preload([userAdded], into: defaults)

            let store = makeStore(defaults)
            store.purgeDemoSeedsIfNeeded()

            XCTAssertEqual(store.locations.map(\.id), [userAdded.id])
            XCTAssertTrue(defaults.bool(forKey: purgeFlagKey))
        }
    }

    // MARK: - 判定条件

    /// isUntouchedDemoSeed の条件（id が定義にあり、name・lat・lon が一致）を固定する。
    func testIsUntouchedDemoSeedConditions() throws {
        for seed in DemoData.seedLocations {
            XCTAssertTrue(seed.isUntouchedDemoSeed, "\(seed.id) は未編集のデモ地点のはず")
        }
        XCTAssertFalse(userAdded.isUntouchedDemoSeed)

        let onna = try XCTUnwrap(DemoData.seedLocations.first { $0.id == "seed-onna" })
        let renamed = SavedLocation(
            id: onna.id,
            name: "自宅",
            lat: onna.lat,
            lon: onna.lon,
            notificationLevel: onna.notificationLevel
        )
        XCTAssertFalse(renamed.isUntouchedDemoSeed)

        let moved = SavedLocation(
            id: onna.id,
            name: onna.name,
            lat: onna.lat,
            lon: onna.lon + 0.01,
            notificationLevel: onna.notificationLevel
        )
        XCTAssertFalse(moved.isUntouchedDemoSeed)

        // "seed-" で始まっていても、定義に無い id は消さない。
        let unknownSeed = SavedLocation(
            id: "seed-unknown",
            name: "どこか",
            lat: 26.0,
            lon: 127.0,
            notificationLevel: nil
        )
        XCTAssertFalse(unknownSeed.isUntouchedDemoSeed)
    }

    /// JSON へ保存して読み戻しても未編集判定が変わらないこと。
    /// 実機のデータは必ず UserDefaults の JSON を経由するため、Double が
    /// 往復で一致しなくなると削除がまったく効かなくなる。
    func testUntouchedJudgementSurvivesJSONRoundTrip() throws {
        let data = try JSONEncoder().encode(DemoData.seedLocations)
        let decoded = try JSONDecoder().decode([SavedLocation].self, from: data)
        XCTAssertEqual(decoded.count, DemoData.seedLocations.count)
        for location in decoded {
            XCTAssertTrue(location.isUntouchedDemoSeed, "\(location.id) が JSON 往復で不一致になった")
        }
    }
}
