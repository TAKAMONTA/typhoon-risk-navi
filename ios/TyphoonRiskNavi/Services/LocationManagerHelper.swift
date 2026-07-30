import CoreLocation
import Foundation

/// 現在地取得を delegate で正しく待つヘルパー（実機向け）。
@MainActor
final class LocationManagerHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// 地図に現在地（青い点）を表示してよいか。
    @Published private(set) var isAuthorized: Bool = false

    /// ユーザーが明示的に拒否済みか。設定アプリへ誘導するかの判断に使う。
    @Published private(set) var isDenied: Bool = false

    /// 許可が下りた直後に一度だけ位置を取りにいくかどうか。
    /// 地図の表示許可だけを求めたときに、不要な測位を走らせないためのフラグ。
    private var wantsOneShotLocation = false

    var onLocation: ((CLLocation) -> Void)?
    var onFailure: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        isAuthorized = Self.authorized(manager.authorizationStatus)
        isDenied = Self.denied(manager.authorizationStatus)
    }

    private static func authorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private static func denied(_ status: CLAuthorizationStatus) -> Bool {
        status == .denied || status == .restricted
    }

    /// 地図に現在地を表示するための許可要求。未決定のときだけ実際に尋ねる。
    /// 測位は行わないので、地図表示のためだけに呼んでよい。
    func requestAuthorizationIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// 現在地を1回だけ測位する。未許可なら許可要求から始める。
    func requestLocation() {
        wantsOneShotLocation = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            wantsOneShotLocation = false
            onFailure?()
        @unknown default:
            wantsOneShotLocation = false
            onFailure?()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.isAuthorized = Self.authorized(status)
            self.isDenied = Self.denied(status)
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.wantsOneShotLocation {
                    manager.requestLocation()
                }
            case .denied, .restricted:
                if self.wantsOneShotLocation {
                    self.wantsOneShotLocation = false
                    self.onFailure?()
                }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.wantsOneShotLocation = false
            self.onLocation?(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.wantsOneShotLocation = false
            self.onFailure?()
        }
    }
}
