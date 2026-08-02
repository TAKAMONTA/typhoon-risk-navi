import XCTest
import CoreLocation
@testable import TyphoonRiskNavi

/// 「最寄り自治体の情報」は、代表地点（あなたの危険度用）ではなく
/// 端末の実測現在地を優先すべき、というバグ修正を守るテスト。
@MainActor
final class NearestMunicipalityAnchorTests: XCTestCase {

    /// 石垣島付近の保存場所のみ。deviceLocation が無いときのフォールバック確認に使う。
    private let ishigaki = SavedLocation(
        id: "ishigaki-only",
        name: "石垣島の別荘",
        lat: 24.34,
        lon: 124.16,
        notificationLevel: "MEDIUM"
    )

    /// ユーザーが「現在地を追加」で登録した浦添市内の場所（id は "seed-" で始まらない）。
    private let urasoeHome = SavedLocation(
        id: "5A4C0F0E-0000-4000-8000-000000000001",
        name: "現在地 (10:30)",
        lat: 26.2458,
        lon: 127.7219,
        notificationLevel: "MEDIUM"
    )

    /// 那覇市付近の座標。deviceLocation に使う。
    private let nahaCoordinate = CLLocationCoordinate2D(latitude: 26.21, longitude: 127.68)

    /// 浦添市付近の座標。永続化の確認に使う。
    private let urasoeCoordinate = CLLocationCoordinate2D(latitude: 26.2458, longitude: 127.7219)

    private func makeViewModel(
        locations: [SavedLocation],
        defaults: UserDefaults
    ) -> TyphoonViewModel {
        let viewModel = TyphoonViewModel(defaults: defaults)
        viewModel.state = DemoStateResponse(
            typhoon: nil,
            risks: [],
            savedLocations: locations,
            lastUpdated: "2026-08-01T00:00:00Z"
        )
        return viewModel
    }

    /// deviceLocation を永続化するようになったので、標準の UserDefaults を使うと
    /// テスト同士（および実機の実データ）が干渉する。テストごとに専用スイートを使い、
    /// 開始前と終了後の両方で必ず消す。
    private func withIsolatedDefaults(
        _ testName: String = #function,
        _ body: (UserDefaults) throws -> Void
    ) rethrows {
        let suiteName = "NearestMunicipalityAnchorTests."
            + testName.replacingOccurrences(of: "()", with: "")
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("テスト用の UserDefaults スイートを作れませんでした: \(suiteName)")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    /// deviceLocation が未設定なら、従来どおり representativeLocation 基準の自治体になる。
    func testFallsBackToRepresentativeLocationWhenNoDeviceLocation() throws {
        try withIsolatedDefaults { defaults in
            let viewModel = makeViewModel(locations: [ishigaki], defaults: defaults)

            XCTAssertNil(viewModel.deviceLocation)
            XCTAssertFalse(viewModel.isMunicipalityFromDeviceLocation)

            let expected = try XCTUnwrap(OkinawaMunicipalityCatalog.nearest(to: ishigaki))
            let info = try XCTUnwrap(viewModel.nearestMunicipalityInfo)
            XCTAssertEqual(info.municipality.id, expected.municipality.id)
        }
    }

    /// deviceLocation を設定すると、保存場所の内容にかかわらず deviceLocation 基準の
    /// 自治体が返る（石垣島だけ保存していても那覇市付近を返す）。
    func testUsesDeviceLocationOverSavedLocationsWhenSet() throws {
        try withIsolatedDefaults { defaults in
            let viewModel = makeViewModel(locations: [ishigaki], defaults: defaults)
            viewModel.updateDeviceLocation(nahaCoordinate)

            let expected = try XCTUnwrap(OkinawaMunicipalityCatalog.nearest(to: nahaCoordinate))
            let info = try XCTUnwrap(viewModel.nearestMunicipalityInfo)
            XCTAssertEqual(info.municipality.id, expected.municipality.id)

            // 石垣島基準の結果とは異なることも確認し、「別の市町村が出る」バグの再発を防ぐ。
            let ishigakiBased = try XCTUnwrap(OkinawaMunicipalityCatalog.nearest(to: ishigaki))
            XCTAssertNotEqual(info.municipality.id, ishigakiBased.municipality.id)
        }
    }

    /// isMunicipalityFromDeviceLocation は deviceLocation の有無に連動して切り替わる。
    func testIsMunicipalityFromDeviceLocationTracksState() {
        withIsolatedDefaults { defaults in
            let viewModel = makeViewModel(locations: [ishigaki], defaults: defaults)

            XCTAssertFalse(viewModel.isMunicipalityFromDeviceLocation)

            viewModel.updateDeviceLocation(nahaCoordinate)
            XCTAssertTrue(viewModel.isMunicipalityFromDeviceLocation)
        }
    }

    /// 測位できていなくても、ユーザー自身が登録した場所があればそちらを基準にする。
    /// デモシード（那覇市 SEVERE）が通知レベルで勝ってしまい、浦添市在住のユーザーに
    /// 那覇市が出る、という報告された不具合の再発防止。
    func testPrefersUserCreatedLocationOverDemoSeedsWhenNoDeviceLocation() throws {
        try withIsolatedDefaults { defaults in
            let viewModel = makeViewModel(
                locations: DemoData.seedLocations + [urasoeHome],
                defaults: defaults
            )

            XCTAssertNil(viewModel.deviceLocation)

            let info = try XCTUnwrap(viewModel.nearestMunicipalityInfo)
            XCTAssertEqual(info.municipality.id, "urasoe")
            XCTAssertEqual(info.municipality.name, "浦添市")

            // 「あなたの危険度」の代表地点もユーザー登録の場所になる。
            // 登録していない那覇市（デモシード SEVERE）を代表にすると、身に覚えのない
            // 市町村の危険度・距離が出てしまうため。
            XCTAssertEqual(viewModel.representativeLocation?.id, urasoeHome.id)
        }
    }

    /// ユーザー登録の場所が1つもなければ、従来どおり representativeLocation 基準に戻る。
    func testFallsBackToRepresentativeLocationWhenOnlyDemoSeedsExist() throws {
        try withIsolatedDefaults { defaults in
            let viewModel = makeViewModel(locations: DemoData.seedLocations, defaults: defaults)

            let representative = try XCTUnwrap(viewModel.representativeLocation)
            XCTAssertEqual(representative.id, "seed-naha")

            let expected = try XCTUnwrap(OkinawaMunicipalityCatalog.nearest(to: representative))
            let info = try XCTUnwrap(viewModel.nearestMunicipalityInfo)
            XCTAssertEqual(info.municipality.id, expected.municipality.id)
        }
    }

    /// deviceLocation は UserDefaults に残り、次の起動（＝別インスタンス）で復元される。
    /// 復元されないと毎回デモシード基準に戻ってしまう。
    func testDeviceLocationIsRestoredByNewViewModelInstance() throws {
        try withIsolatedDefaults { defaults in
            let first = makeViewModel(
                locations: DemoData.seedLocations + [ishigaki],
                defaults: defaults
            )
            first.updateDeviceLocation(urasoeCoordinate)

            // アプリを再起動した状態に相当する。
            let restarted = TyphoonViewModel(defaults: defaults)
            let restored = try XCTUnwrap(restarted.deviceLocation)
            XCTAssertEqual(restored.latitude, urasoeCoordinate.latitude, accuracy: 0.0001)
            XCTAssertEqual(restored.longitude, urasoeCoordinate.longitude, accuracy: 0.0001)
            XCTAssertTrue(restarted.isMunicipalityFromDeviceLocation)

            restarted.state = DemoStateResponse(
                typhoon: nil,
                risks: [],
                savedLocations: DemoData.seedLocations + [ishigaki],
                lastUpdated: "2026-08-01T00:00:00Z"
            )
            let info = try XCTUnwrap(restarted.nearestMunicipalityInfo)
            XCTAssertEqual(info.municipality.id, "urasoe")
        }
    }

    /// 保存していない状態では復元しない。未保存を 0 と取り違えて (0, 0) を
    /// 現在地として復元すると、常に同じ自治体が出る不可解な挙動になる。
    func testDeviceLocationIsNilWhenNothingPersisted() {
        withIsolatedDefaults { defaults in
            let viewModel = TyphoonViewModel(defaults: defaults)
            XCTAssertNil(viewModel.deviceLocation)
        }
    }

    /// isDemoSeed は id の接頭辞で判別している。接頭辞のないシードが混ざると
    /// ユーザー登録の場所と区別できなくなるため、規約をテストで固定する。
    func testAllSeedLocationsAreRecognizedAsDemoSeed() {
        for location in DemoData.seedLocations {
            XCTAssertTrue(
                location.isDemoSeed,
                "\(location.id) に \(DemoData.seedIdPrefix) 接頭辞がない"
            )
        }
        XCTAssertFalse(urasoeHome.isDemoSeed)
        XCTAssertFalse(ishigaki.isDemoSeed)
    }
}
