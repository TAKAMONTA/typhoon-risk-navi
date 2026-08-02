import Foundation

/// 実データ取得に失敗したときのデモ台風と、旧バージョンが投入していたデモ地点の定義。
/// backend/src/data/demo.ts を Swift に移植したもの。
enum DemoData {

    /// 沖縄接近を想定したデモ台風。Windradii は km 単位の flat 形式。
    static var demoTyphoon: Typhoon {
        let now = Date()
        let iso = ISO8601DateFormatter()

        let f1 = ForecastPoint(
            validTime: iso.string(from: now.addingTimeInterval(6 * 3600)),
            center: Coordinate(lat: 24.2, lon: 126.8),
            radius: 165,
            maxWindSpeed: 40.0,
            windRadii: WindRadii(radius34kt: 270, radius50kt: 100, radius64kt: 50)
        )
        let f2 = ForecastPoint(
            validTime: iso.string(from: now.addingTimeInterval(18 * 3600)),
            center: Coordinate(lat: 25.4, lon: 127.0),
            radius: 175,
            maxWindSpeed: 36.0,
            windRadii: WindRadii(radius34kt: 230, radius50kt: 80, radius64kt: 35)
        )
        let f3 = ForecastPoint(
            validTime: iso.string(from: now.addingTimeInterval(30 * 3600)),
            center: Coordinate(lat: 26.3, lon: 127.5),
            radius: 180,
            maxWindSpeed: 31.0,
            windRadii: WindRadii(radius34kt: 190, radius50kt: 55, radius64kt: 20)
        )
        let f4 = ForecastPoint(
            validTime: iso.string(from: now.addingTimeInterval(42 * 3600)),
            center: Coordinate(lat: 27.8, lon: 128.8),
            radius: 185,
            maxWindSpeed: 27.0,
            windRadii: WindRadii(radius34kt: 130, radius50kt: 35, radius64kt: nil)
        )

        return Typhoon(
            id: "DEMO-JANGMI",
            name: "JANGMI",
            nameJa: "台風6号",
            source: "DEMO",
            status: "ACTIVE",
            currentCenter: Coordinate(lat: 22.5, lon: 126.5),
            maxWindSpeed: 43.7,        // m/s ≒ 85 kt
            centralPressure: 950,
            direction: 340,
            speed: 20.0,               // km/h
            windRadii: WindRadii(radius34kt: 290, radius50kt: 115, radius64kt: 60),
            forecasts: [f1, f2, f3, f4],
            lastUpdated: iso.string(from: now)
        )
    }

    /// デモ地点の id につける接頭辞。
    /// 「ユーザー自身が登録した場所」とデモ地点を後から見分けるために使う。
    /// seedLocations に地点を足すときは必ずこの接頭辞をつけること。
    static let seedIdPrefix = "seed-"

    /// 旧バージョンが初回起動時に投入していた沖縄の主要地点。
    ///
    /// **初回投入には使わない。** ユーザーが登録していない土地の危険度を「あなたの危険度」に
    /// 出したり、その土地について通知を飛ばしたりするのは防災アプリとして不適切なため。
    /// 現在の用途は次の2つだけ:
    /// 1. 既存端末に残っているデモ地点のクリーンアップ判定（isUntouchedDemoSeed の照合元）
    /// 2. App Store 用スクリーンショット撮影モードの表示データ（永続化しない）
    static let seedLocations: [SavedLocation] = [
        SavedLocation(id: "seed-naha", name: "那覇市", lat: 26.21, lon: 127.68, notificationLevel: "SEVERE"),
        SavedLocation(id: "seed-ginowan", name: "宜野湾市", lat: 26.28, lon: 127.72, notificationLevel: "HIGH"),
        SavedLocation(id: "seed-miyako", name: "宮古島", lat: 24.81, lon: 125.28, notificationLevel: "HIGH"),
        SavedLocation(id: "seed-ishigaki", name: "石垣島", lat: 24.34, lon: 124.16, notificationLevel: "MEDIUM"),
        SavedLocation(id: "seed-onna", name: "恩納村", lat: 26.50, lon: 127.83, notificationLevel: "LOW"),
    ]
}

extension SavedLocation {
    /// 初回起動時に投入したデモ地点か。
    /// ユーザー自身が登録した場所をデモ地点より優先したい場面で使う。
    /// SavedLocation の Codable 構造を変えると既存の保存データが壊れるため、
    /// フィールドを増やさず id の接頭辞だけで判別する。
    var isDemoSeed: Bool {
        id.hasPrefix(DemoData.seedIdPrefix)
    }

    /// 旧バージョンが投入したまま、ユーザーが一度も編集していないデモ地点か。
    /// 既存端末のクリーンアップで「消してよい地点」を判定するために使う。
    ///
    /// id が一致するだけでは消さない。名前か座標が元の定義と違えば、ユーザーが
    /// 自分の場所として編集して使っている可能性があるので残す。
    /// 通知レベルは地点そのものではなく通知の設定なので、比較対象に含めない。
    var isUntouchedDemoSeed: Bool {
        guard let original = DemoData.seedLocations.first(where: { $0.id == id }) else {
            return false
        }
        return name == original.name && lat == original.lat && lon == original.lon
    }
}
