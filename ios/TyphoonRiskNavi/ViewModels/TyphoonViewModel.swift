import Foundation
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

    private var cancellables: Set<AnyCancellable> = []

    init() {
        // 通知デリゲートを起動時にセット
        _ = LocalNotificationService.shared

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

        // 初回シード（冪等）
        locationStore.seedDemoLocationsIfNeeded()

        // スクショ撮影モードでは JTWC を呼ばず、即デモ状態で表示
        if isScreenshotMode {
            let typhoon = DemoData.demoTyphoon
            let locs = locationStore.locations
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

    /// 地図サマリーカード用。SEVERE > HIGH > MEDIUM > LOW、同順位は到達時間が近い地点を優先。
    var topRiskAssessment: RiskAssessment? {
        let risks = displayRisks
        guard !risks.isEmpty else { return nil }
        let priority: [String: Int] = ["SEVERE": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1]
        return risks.max { lhs, rhs in
            let p1 = priority[lhs.riskLevel] ?? 0
            let p2 = priority[rhs.riskLevel] ?? 0
            if p1 != p2 { return p1 < p2 }
            let h1 = lhs.earliestArrivalHours ?? .infinity
            let h2 = rhs.earliestArrivalHours ?? .infinity
            return h1 > h2
        }
    }

    /// 起動時サマリーの「自分の危険度」に使う代表地点。
    /// 台風リスクがあるときは最優先地点、なければ通知レベルが高い保存場所を選ぶ。
    var representativeLocation: SavedLocation? {
        let locations = state?.savedLocations ?? locationStore.locations
        guard !locations.isEmpty else { return nil }

        if let top = topRiskAssessment,
           let matched = locations.first(where: { $0.id == top.locationId }) {
            return matched
        }

        let priority: [String: Int] = ["SEVERE": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1]
        return locations.max { lhs, rhs in
            let p1 = priority[lhs.notificationLevel ?? ""] ?? 0
            let p2 = priority[rhs.notificationLevel ?? ""] ?? 0
            if p1 != p2 { return p1 < p2 }
            return lhs.name > rhs.name
        }
    }

    /// 代表地点から見た最寄り自治体と距離。
    var nearestMunicipalityInfo: (municipality: OkinawaMunicipality, distanceKm: Double)? {
        guard let location = representativeLocation else { return nil }
        return OkinawaMunicipalityCatalog.nearest(to: location)
    }
}
