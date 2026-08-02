import Foundation
import CoreLocation
import MapKit
import SwiftUI
import Combine

@MainActor
class TyphoonViewModel: ObservableObject {
    @Published var state: DemoStateResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 現在何を読み込もうとしているかの文脈（ユーザー向け表示用）
    @Published var loadingContext: String? = nil

    /// 現在のデータソース状況
    enum DataSourceStatus {
        case real
        case demo
        /// 台風シーズン外など、進行中の台風がない正常状態（デモ表示で操作確認可能）
        case noTyphoon
        case demoDueToError(String)
    }

    @Published var dataSourceStatus: DataSourceStatus = .demo

    /// 最後に実データを正常に取得できた時刻
    @Published var lastSuccessfulRealData: Date? = nil

    /// 気象庁の沖縄警報・注意報（自動取得）
    @Published var officialWarnings: [OfficialWarning] = []

    /// 端末ローカルの保存場所ストア（観察可能）
    let locationStore = LocalLocationStore.shared

    /// 端末の実測現在地。保存場所（デモシード等）に紛れず「今ユーザーがいる場所」を
    /// 自治体判定に使えるよう、測位に成功したときだけ別枠で保持する。
    @Published var deviceLocation: CLLocationCoordinate2D?

    private var cancellables: Set<AnyCancellable> = []

    /// deviceLocation の保存先。テストで専用スイートに差し替えられるよう注入可能にしている。
    private let defaults: UserDefaults
    private let deviceLocationLatKey: String
    private let deviceLocationLonKey: String

    /// キー名は LocalLocationStore（saved_locations_v1 など）の *_v1 命名に合わせる。
    init(
        defaults: UserDefaults = .standard,
        deviceLocationLatKey: String = "device_location_lat_v1",
        deviceLocationLonKey: String = "device_location_lon_v1"
    ) {
        self.defaults = defaults
        self.deviceLocationLatKey = deviceLocationLatKey
        self.deviceLocationLonKey = deviceLocationLonKey

        // 通知デリゲートを起動時にセット
        _ = LocalNotificationService.shared

        // 前回測位できた現在地を復元する。永続化しないと再起動のたびに nil に戻り、
        // 「最寄り自治体の情報」がデモシード（那覇市など）基準にフォールバックして、
        // ユーザーが住んでいる市町村とは別の市が表示されてしまう。
        deviceLocation = loadPersistedDeviceLocation()

        // 場所一覧が変更されたらリスクを再計算
        locationStore.$locations
            .dropFirst()    // 初期値は loadData() 側で扱う
            .sink { [weak self] newLocations in
                self?.recomputeRisks(with: newLocations)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Computed

    var isUsingRealData: Bool {
        if case .real = dataSourceStatus { return true }
        return false
    }

    var realDataErrorMessage: String? {
        if case .demoDueToError(let msg) = dataSourceStatus { return msg }
        return nil
    }

    var currentDynamicDecayRate: Double? {
        guard let typhoon = state?.typhoon else { return nil }
        return RiskCalculator.computeDynamicDecayRate(for: typhoon)
    }

    var lastRealDataDescription: String? {
        guard let date = lastSuccessfulRealData else { return nil }
        let elapsed = Date().timeIntervalSince(date)
        // 直後は RelativeDateTimeFormatter が「0 秒後」と未来形で返すので、自前で潰す。
        if elapsed < 60 {
            return L10n.lastRealDataJustNow
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return L10n.lastRealData(formatter.localizedString(for: date, relativeTo: Date()))
    }

    var hasData: Bool {
        state != nil
    }

    // MARK: - Load

    /// スクリーンショット撮影モード。`-screenshotMode YES` で起動すると true。
    /// 通常起動では false。JTWC fetch をスキップしてクリーンなデモ表示にし、
    /// エラーバナーが映らないようにする（App Store スクショ用）。
    private var isScreenshotMode: Bool {
        UserDefaults.standard.bool(forKey: "screenshotMode")
    }

    /// JTWC から実データを取り、取れなければデモにフォールバックする。
    /// 場所は LocalLocationStore（UserDefaults）から読む。リスクは on-device 計算。
    func loadData() async {
        isLoading = true
        errorMessage = nil
        loadingContext = "実データを取得しています..."

        // スクショ撮影モードでは JTWC を呼ばず、即デモ状態で表示
        if isScreenshotMode {
            let typhoon = DemoData.demoTyphoon
            // 撮影用の地点はその場限りの表示データ。locationStore には一切書き込まない
            // （撮影用のデモ地点がユーザーの保存場所として残ると、登録していない土地の
            // 危険度・通知が出てしまうため）。
            let locs = DemoData.seedLocations
            let risks = RiskCalculator.assessAll(locations: locs, typhoon: typhoon)
            state = DemoStateResponse(
                typhoon: typhoon,
                risks: risks,
                savedLocations: locs,
                lastUpdated: ISO8601DateFormatter().string(from: Date())
            )
            dataSourceStatus = .demo
            loadingContext = nil
            isLoading = false
            return
        }

        // 旧バージョンが投入したデモ場所の後始末（実行は一度きり。撮影モードでは書き換えない）
        locationStore.purgeDemoSeedsIfNeeded()

        // 気象庁を優先、失敗時のみ JTWC を試す
        var realTyphoon: Typhoon?
        var fetchError: String?

        do {
            let typhoons = try await JMAFetcher.fetchActive()
            realTyphoon = typhoons.first
        } catch JMAFetcher.FetchError.noActiveTyphoons {
            // 台風なしは正常状態。エラー扱いしない。
        } catch {
            fetchError = error.localizedDescription
            do {
                let typhoons = try await JTWCFetcher.fetchActive()
                realTyphoon = typhoons.first
                fetchError = nil
            } catch JTWCFetcher.FetchError.noActiveTyphoons {
                fetchError = nil
            } catch let jtwcError {
                fetchError = fetchError ?? jtwcError.localizedDescription
            }
        }

        loadingContext = "リスク情報を計算しています..."

        // 表示する台風を決める。
        // - 実データあり: その台風
        // - 台風なし(.noTyphoon): nil（地図・リスクに何も描かず、テキスト表示と整合させる）
        // - 取得失敗/デモ: デモ台風で操作確認できるようにする
        let typhoon: Typhoon?
        let status: DataSourceStatus
        if let real = realTyphoon {
            typhoon = real
            status = .real
            lastSuccessfulRealData = Date()
        } else if fetchError == nil {
            // 台風なしは正常状態。以前のデモ台風を残さないため nil にする。
            typhoon = nil
            status = .noTyphoon
        } else {
            typhoon = DemoData.demoTyphoon
            if let err = fetchError {
                status = .demoDueToError(err)
            } else {
                status = .demo
            }
        }

        let locs = locationStore.locations
        // 台風がないときはリスクも作らない（デモ台風基準のリスクが残るのを防ぐ）。
        let risks = typhoon.map { RiskCalculator.assessAll(locations: locs, typhoon: $0) } ?? []

        state = DemoStateResponse(
            typhoon: typhoon,
            risks: risks,
            savedLocations: locs,
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        )
        dataSourceStatus = status

        // 警報・注意報は台風の有無に関わらず取得（避難判断の補助情報）
        if !isScreenshotMode {
            loadingContext = "警報・注意報を取得しています..."
            let warnings = await JMAWarningFetcher.fetchOkinawaWarnings()
            let preferredId = representativeLocation.flatMap {
                OkinawaMunicipalityCatalog.nearest(to: $0)?.municipality.id
            }
            officialWarnings = JMAWarningFetcher.prioritized(warnings: warnings, nearMunicipalityId: preferredId)

            let isReal: Bool
            if case .real = status { isReal = true } else { isReal = false }
            await LocalNotificationService.shared.refreshNotifications(
                risks: risks,
                typhoon: typhoon,
                dataSourceIsReal: isReal
            )
        } else {
            officialWarnings = []
        }

        loadingContext = nil
        isLoading = false
    }

    /// 場所一覧だけが変わったときに、現在の台風データを使ってリスクだけ作り直す
    private func recomputeRisks(with locations: [SavedLocation]) {
        guard let current = state else { return }
        // 台風がないときはリスクを計算しない（場所ピンだけ更新する）。
        let risks = current.typhoon.map {
            RiskCalculator.assessAll(locations: locations, typhoon: $0)
        } ?? []
        state = DemoStateResponse(
            typhoon: current.typhoon,
            risks: risks,
            savedLocations: locations,
            lastUpdated: current.lastUpdated
        )

        let municipalityId = representativeLocation.flatMap {
            OkinawaMunicipalityCatalog.nearest(to: $0)?.municipality.id
        }
        officialWarnings = JMAWarningFetcher.prioritized(
            warnings: officialWarnings,
            nearMunicipalityId: municipalityId
        )

        Task {
            await LocalNotificationService.shared.refreshNotifications(
                risks: risks,
                typhoon: current.typhoon,
                dataSourceIsReal: isUsingRealData
            )
        }
    }

    /// 起動カード用。最寄り地方の警報を1件返す。
    var primaryOfficialWarning: OfficialWarning? {
        officialWarnings.first
    }

    // MARK: - Map Geometry

    /// 沖縄本島（那覇周辺）。保存場所が1つもないときの地図基準点。
    static let okinawaCenter = CLLocationCoordinate2D(latitude: 26.2, longitude: 127.7)

    /// これを超えて離れた台風は、同一画面に収めると沖縄側が潰れて何も読み取れなくなる。
    private static let farTyphoonThresholdKm: Double = 1200

    /// 地図の基準点。保存場所があれば代表地点、なければ沖縄本島。
    var mapAnchor: CLLocationCoordinate2D {
        if let location = representativeLocation {
            return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
        }
        return Self.okinawaCenter
    }

    /// 距離を示すときに使う基準点の呼び名。「現在地」と誤認させないため実際の地点名を出す。
    var mapAnchorName: String {
        representativeLocation?.name ?? L10n.mapAnchorOkinawa
    }

    /// 基準点から台風中心までの距離 (km)。台風がなければ nil。
    var typhoonDistanceKm: Double? {
        guard let typhoon = state?.typhoon else { return nil }
        let anchor = CLLocation(latitude: mapAnchor.latitude, longitude: mapAnchor.longitude)
        let center = CLLocation(latitude: typhoon.currentCenter.lat, longitude: typhoon.currentCenter.lon)
        return anchor.distance(from: center) / 1000
    }

    /// 台風が遠方にあり、地図の初期表示を沖縄側に留めるべきか。
    var isTyphoonFarAway: Bool {
        guard let distance = typhoonDistanceKm else { return false }
        return distance > Self.farTyphoonThresholdKm
    }

    /// 基準点から見た台風の方角（8方位）。
    var typhoonDirectionFromAnchor: String? {
        guard let typhoon = state?.typhoon else { return nil }
        let anchor = mapAnchor
        let dLat = typhoon.currentCenter.lat - anchor.latitude
        let dLon = (typhoon.currentCenter.lon - anchor.longitude) * cos(anchor.latitude * .pi / 180)
        guard dLat != 0 || dLon != 0 else { return nil }

        var degrees = atan2(dLon, dLat) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        let index = Int((degrees / 45).rounded()) % 8
        return L10n.compassDirection(index)
    }

    /// 沖縄（または代表地点）を中心にした通常表示。
    var homeRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: mapAnchor,
            span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
        )
    }

    /// 台風中心に寄せた表示。台風がなければ homeRegion。
    var typhoonRegion: MKCoordinateRegion {
        guard let typhoon = state?.typhoon else { return homeRegion }
        return MKCoordinateRegion(
            center: typhoon.currentCenter.clLocation,
            span: MKCoordinateSpan(latitudeDelta: 5.5, longitudeDelta: 5.5)
        )
    }

    /// 地図の初期表示。
    /// - 台風なし / 遠方の台風: 沖縄側を維持する（太平洋の真ん中を映さない）
    /// - 接近中の台風: 台風と基準点の両方が入る範囲
    var mapRegion: MKCoordinateRegion {
        guard let typhoon = state?.typhoon, !isTyphoonFarAway else {
            return homeRegion
        }

        let anchor = mapAnchor
        let center = typhoon.currentCenter.clLocation
        let midLat = (anchor.latitude + center.latitude) / 2
        let midLon = (anchor.longitude + center.longitude) / 2
        let latDelta = min(max(abs(anchor.latitude - center.latitude) * 1.8, 4.0), 60.0)
        let lonDelta = min(max(abs(anchor.longitude - center.longitude) * 1.8, 4.0), 60.0)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    /// 地図カメラを再設定すべきタイミングを表すキー。
    /// 台風の入れ替わりと基準点の移動だけに反応し、単なる再読み込みではカメラを動かさない。
    var mapFocusKey: String {
        let typhoonId = state?.typhoon?.id ?? "none"
        let anchor = mapAnchor
        return "\(typhoonId)|\(String(format: "%.2f,%.2f", anchor.latitude, anchor.longitude))"
    }

    var trackCoordinates: [CLLocationCoordinate2D] {
        guard let typhoon = state?.typhoon else { return [] }
        var coords: [CLLocationCoordinate2D] = [typhoon.currentCenter.clLocation]
        coords += typhoon.forecasts.map { $0.center.clLocation }
        return coords
    }

    struct ForecastCircle: Identifiable {
        let id: String
        let center: CLLocationCoordinate2D
        let radius: Double // meters
        let validTime: String
    }

    var forecastCircles: [ForecastCircle] {
        guard let typhoon = state?.typhoon else { return [] }
        return typhoon.forecasts.enumerated().map { index, forecast in
            let radiusKm: Double = forecast.radius ?? 150
            return ForecastCircle(
                id: "forecast-\(index)",
                center: forecast.center.clLocation,
                radius: radiusKm * 1000,
                validTime: forecast.validTime
            )
        }
    }

    struct WindRadiusCircle: Identifiable {
        let id: String
        let center: CLLocationCoordinate2D
        let radius: Double // meters
        let windSpeedKt: Int
        let color: Color
    }

    var currentWindRadii: [WindRadiusCircle] {
        guard let typhoon = state?.typhoon else { return [] }
        var circles: [WindRadiusCircle] = []
        let center = typhoon.currentCenter.clLocation

        if let r = typhoon.windRadii?.radius34kt {
            circles.append(WindRadiusCircle(id: "34kt-current", center: center, radius: r * 1000, windSpeedKt: 34, color: .yellow))
        }
        if let r = typhoon.windRadii?.radius50kt {
            circles.append(WindRadiusCircle(id: "50kt-current", center: center, radius: r * 1000, windSpeedKt: 50, color: .orange))
        }
        if let r = typhoon.windRadii?.radius64kt {
            circles.append(WindRadiusCircle(id: "64kt-current", center: center, radius: r * 1000, windSpeedKt: 64, color: .red))
        }

        // データが完全に欠けている場合のみフォールバック
        if circles.isEmpty {
            circles.append(WindRadiusCircle(id: "34kt-demo", center: center, radius: 180_000, windSpeedKt: 34, color: .yellow))
            circles.append(WindRadiusCircle(id: "50kt-demo", center: center, radius: 100_000, windSpeedKt: 50, color: .orange))
            circles.append(WindRadiusCircle(id: "64kt-demo", center: center, radius: 60_000, windSpeedKt: 64, color: .red))
        }
        return circles
    }

    /// 未来の風速半径（精度モデル「動的減衰」を適用）
    var forecastWindRadii: [WindRadiusCircle] {
        guard let typhoon = state?.typhoon, !typhoon.forecasts.isEmpty else { return [] }

        let decayRatePerDay = RiskCalculator.computeDynamicDecayRate(for: typhoon)
        let currentTime = Date()
        let formatter = ISO8601DateFormatter()

        var circles: [WindRadiusCircle] = []
        let futureCandidates = typhoon.forecasts.prefix(3).suffix(2)

        for (index, fp) in futureCandidates.enumerated() {
            guard let validDate = formatter.date(from: fp.validTime) else { continue }

            let hoursSinceNow = validDate.timeIntervalSince(currentTime) / 3600
            let decayFactor = max(0.4, 1.0 - decayRatePerDay * (hoursSinceNow / 24.0))

            let center = fp.center.clLocation
            let baseOpacity = max(0.35, 0.85 - Double(index) * 0.25)

            if let r34 = fp.windRadii?.radius34kt {
                let decayed = r34 * decayFactor
                circles.append(WindRadiusCircle(id: "34kt-f\(index)", center: center, radius: decayed * 1000, windSpeedKt: 34, color: .yellow.opacity(baseOpacity)))
            } else if index == 0 {
                let fallback = 150.0 * decayFactor
                circles.append(WindRadiusCircle(id: "34kt-f\(index)", center: center, radius: fallback * 1000, windSpeedKt: 34, color: .yellow.opacity(baseOpacity * 0.6)))
            }
            if let r50 = fp.windRadii?.radius50kt {
                let decayed = r50 * decayFactor
                circles.append(WindRadiusCircle(id: "50kt-f\(index)", center: center, radius: decayed * 1000, windSpeedKt: 50, color: .orange.opacity(baseOpacity)))
            }
            if let r64 = fp.windRadii?.radius64kt, r64 > 20 {
                let decayed = r64 * decayFactor
                circles.append(WindRadiusCircle(id: "64kt-f\(index)", center: center, radius: decayed * 1000, windSpeedKt: 64, color: .red.opacity(baseOpacity)))
            }
        }
        return circles
    }

    // MARK: - Risks (alias)

    /// 場所ごとのリスク評価。on-device 計算なので、実データ・デモを問わず常に一貫した結果を返す。
    var displayRisks: [RiskAssessment] {
        state?.risks ?? []
    }

    /// 後方互換のため残す。displayRisks と同じ。
    var computedUserRisks: [RiskAssessment] {
        displayRisks
    }

    /// リスクレベル・通知レベルの強さ比較に使う共通の優先度表。
    private static let levelPriority: [String: Int] = ["SEVERE": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1]

    /// 地図サマリーカード用。SEVERE > HIGH > MEDIUM > LOW、同順位は到達時間が近い地点を優先。
    var topRiskAssessment: RiskAssessment? {
        highestRisk(among: displayRisks)
    }

    /// 与えられたリスク評価から最も危険な1件を選ぶ。
    private func highestRisk(among risks: [RiskAssessment]) -> RiskAssessment? {
        guard !risks.isEmpty else { return nil }
        return risks.max { lhs, rhs in
            let p1 = Self.levelPriority[lhs.riskLevel] ?? 0
            let p2 = Self.levelPriority[rhs.riskLevel] ?? 0
            if p1 != p2 { return p1 < p2 }
            let h1 = lhs.earliestArrivalHours ?? .infinity
            let h2 = rhs.earliestArrivalHours ?? .infinity
            return h1 > h2
        }
    }

    /// 現在参照すべき保存場所一覧。読み込み済みの state を優先し、無ければストアの値を使う。
    private var currentSavedLocations: [SavedLocation] {
        state?.savedLocations ?? locationStore.locations
    }

    /// 起動時サマリーの「自分の危険度」に使う代表地点。
    /// 台風リスクがあるときは最優先地点、なければ通知レベルが高い保存場所を選ぶ。
    ///
    /// ユーザーが自分で登録した場所が1つでもあれば、その中からだけ選ぶ。
    /// 旧バージョンのデモシード（恩納村 LOW や那覇市 SEVERE など）は、ユーザーが
    /// 現在地を登録したあとも代表として居座り続け、「自分の危険度」や距離の基準に
    /// 身に覚えのない市町村が出てしまうため。
    /// シードしか残っていない端末（＝名前や座標を編集して自分の場所として使っており、
    /// クリーンアップでも消さなかったケース）では、従来どおり全体から選ぶ。
    var representativeLocation: SavedLocation? {
        userCreatedRepresentativeLocation ?? representative(of: currentSavedLocations)
    }

    /// 与えられた場所集合から代表地点を1つ選ぶ。
    /// 台風リスクが最も高い場所 → 通知レベルが高い場所 → 名前順、の優先度。
    /// 集合を絞って呼べるようにしてあるのは、「ユーザーが登録した場所だけ」から
    /// 同じ基準で代表を選びたい場面があるため。
    private func representative(of locations: [SavedLocation]) -> SavedLocation? {
        guard !locations.isEmpty else { return nil }

        let ids = Set(locations.map(\.id))
        if let top = highestRisk(among: displayRisks.filter { ids.contains($0.locationId) }),
           let matched = locations.first(where: { $0.id == top.locationId }) {
            return matched
        }

        return locations.max { lhs, rhs in
            let p1 = Self.levelPriority[lhs.notificationLevel ?? ""] ?? 0
            let p2 = Self.levelPriority[rhs.notificationLevel ?? ""] ?? 0
            if p1 != p2 { return p1 < p2 }
            return lhs.name > rhs.name
        }
    }

    /// ユーザー自身が登録した場所だけから選んだ代表地点（デモシードは除外）。
    /// 1つも無ければ nil。
    private var userCreatedRepresentativeLocation: SavedLocation? {
        representative(of: currentSavedLocations.filter { !$0.isDemoSeed })
    }

    /// 端末の実測現在地を更新する。「現在地」ボタンや「現在地を追加」での測位成功時に呼ばれる。
    /// 再起動後も「最寄り自治体の情報」を実際の居場所基準に保つため UserDefaults にも書く。
    func updateDeviceLocation(_ coordinate: CLLocationCoordinate2D) {
        // 壊れた座標を保存すると、以降ずっと誤った自治体を指し続けるので弾く。
        guard Self.isUsableCoordinate(coordinate) else { return }
        deviceLocation = coordinate
        defaults.set(coordinate.latitude, forKey: deviceLocationLatKey)
        defaults.set(coordinate.longitude, forKey: deviceLocationLonKey)
    }

    /// 保存済みの現在地を読み出す。未保存・値が壊れている場合は nil。
    private func loadPersistedDeviceLocation() -> CLLocationCoordinate2D? {
        // double(forKey:) は未保存でも 0 を返してしまい、(0, 0) という実在しない
        // 現在地を復元してしまうため、object(forKey:) で「未保存」を区別する。
        guard let lat = defaults.object(forKey: deviceLocationLatKey) as? Double,
              let lon = defaults.object(forKey: deviceLocationLonKey) as? Double else {
            return nil
        }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        guard Self.isUsableCoordinate(coordinate) else { return nil }
        return coordinate
    }

    /// 自治体判定に使える座標か（NaN や緯度経度の範囲外を除く）。
    private static func isUsableCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude.isFinite
            && coordinate.longitude.isFinite
            && CLLocationCoordinate2DIsValid(coordinate)
    }

    /// 最寄り自治体判定の基準座標。
    /// 「最寄り自治体の情報」はユーザーが今いる場所の避難情報へ導くためのものなので、
    /// 1. 端末の実測現在地 → 2. ユーザー自身が登録した場所の代表 → 3. 代表地点（従来どおり）
    /// の順に使う。2 を挟むのは、測位できないときに初回起動時のデモシード（那覇市 SEVERE など）が
    /// ユーザーの登録地点に勝ってしまい、住んでいる市町村と別の市が出るのを防ぐため。
    private var municipalityAnchorCoordinate: CLLocationCoordinate2D? {
        if let deviceLocation { return deviceLocation }
        guard let location = userCreatedRepresentativeLocation ?? representativeLocation else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
    }

    /// 最寄り自治体の判定基準が端末の実測現在地かどうか。View 側の表示文言の出し分けに使う。
    var isMunicipalityFromDeviceLocation: Bool {
        deviceLocation != nil
    }

    /// 基準座標（現在地優先、なければ代表地点）から見た最寄り自治体と距離。
    var nearestMunicipalityInfo: (municipality: OkinawaMunicipality, distanceKm: Double)? {
        guard let anchor = municipalityAnchorCoordinate else { return nil }
        return OkinawaMunicipalityCatalog.nearest(to: anchor)
    }
}
