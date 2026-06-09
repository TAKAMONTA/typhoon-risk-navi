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
        case demoDueToError(String)
    }

    @Published var dataSourceStatus: DataSourceStatus = .demo

    /// 最後に実データを正常に取得できた時刻
    @Published var lastSuccessfulRealData: Date? = nil

    /// 端末ローカルの保存場所ストア（観察可能）
    let locationStore = LocalLocationStore.shared

    private var cancellables: Set<AnyCancellable> = []

    init() {
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
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        return "最終実データ: \(formatter.localizedString(for: date, relativeTo: Date()))"
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

        // JTWC を試す
        var realTyphoon: Typhoon? = nil
        var realError: String? = nil
        do {
            let typhoons = try await JTWCFetcher.fetchActive()
            realTyphoon = typhoons.first
        } catch {
            realError = error.localizedDescription
        }

        loadingContext = "リスク情報を計算しています..."

        let typhoon: Typhoon
        let status: DataSourceStatus
        if let real = realTyphoon {
            typhoon = real
            status = .real
            lastSuccessfulRealData = Date()
        } else {
            typhoon = DemoData.demoTyphoon
            if let err = realError {
                status = .demoDueToError(err)
            } else {
                status = .demo
            }
        }

        let locs = locationStore.locations
        let risks = RiskCalculator.assessAll(locations: locs, typhoon: typhoon)

        state = DemoStateResponse(
            typhoon: typhoon,
            risks: risks,
            savedLocations: locs,
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        )
        dataSourceStatus = status

        loadingContext = nil
        isLoading = false
    }

    /// 場所一覧だけが変わったときに、現在の台風データを使ってリスクだけ作り直す
    private func recomputeRisks(with locations: [SavedLocation]) {
        guard let current = state else { return }
        let risks = RiskCalculator.assessAll(locations: locations, typhoon: current.typhoon)
        state = DemoStateResponse(
            typhoon: current.typhoon,
            risks: risks,
            savedLocations: locations,
            lastUpdated: current.lastUpdated
        )
    }

    // MARK: - Map Geometry

    var mapRegion: MKCoordinateRegion {
        guard let typhoon = state?.typhoon else {
            // 沖縄本島を中心に表示
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 26.2, longitude: 127.7),
                span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 6.0)
            )
        }
        return MKCoordinateRegion(
            center: typhoon.currentCenter.clLocation,
            span: MKCoordinateSpan(latitudeDelta: 5.5, longitudeDelta: 5.5)
        )
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
}
