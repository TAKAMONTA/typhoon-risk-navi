import Foundation
import CoreLocation

/// 沖縄の主要自治体と、公式の防災・避難情報ページ。
/// 端末内の静的カタログなので通信不要。最寄り判定は座標の距離で行う。
struct OkinawaMunicipality: Identifiable, Equatable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    /// 自治体の防災・災害情報ページ
    let disasterInfoURL: URL
    /// 避難所・避難情報ページ（無い場合は防災ページと同じ）
    let evacuationInfoURL: URL

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

enum OkinawaMunicipalityCatalog {

    /// 沖縄県防災情報ポータル（全自治体共通の補助リンク）
    static let prefectureDisasterURL = URL(string: "https://www.bousai.okinawa.jp/")!

    /// 気象庁の台風ページ（沖縄周辺を見やすい初期表示）
    static let jmaTyphoonURL = URL(string: "https://www.jma.go.jp/bosai/map.html#5/26.212/127.681/&elem=root&typhoon=on&contents=typhoon")!

    /// 主要市町村・村。中心付近の代表座標で最寄り判定する。
    static let all: [OkinawaMunicipality] = [
        OkinawaMunicipality(
            id: "naha",
            name: "那覇市",
            lat: 26.2124, lon: 127.6809,
            disasterInfoURL: URL(string: "https://www.city.naha.okinawa.jp/safety/")!,
            evacuationInfoURL: URL(string: "https://www.city.naha.okinawa.jp/safety/")!
        ),
        OkinawaMunicipality(
            id: "ginowan",
            name: "宜野湾市",
            lat: 26.2816, lon: 127.7786,
            disasterInfoURL: URL(string: "https://www.city.ginowan.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.ginowan.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "urasoe",
            name: "浦添市",
            lat: 26.2458, lon: 127.7219,
            disasterInfoURL: URL(string: "https://www.city.urasoe.lg.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.urasoe.lg.jp/")!
        ),
        OkinawaMunicipality(
            id: "okinawa-city",
            name: "沖縄市",
            lat: 26.3344, lon: 127.8056,
            disasterInfoURL: URL(string: "https://www.city.okinawa.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.okinawa.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "uruma",
            name: "うるま市",
            lat: 26.3792, lon: 127.8575,
            disasterInfoURL: URL(string: "https://www.city.uruma.lg.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.uruma.lg.jp/")!
        ),
        OkinawaMunicipality(
            id: "itoman",
            name: "糸満市",
            lat: 26.1236, lon: 127.6658,
            disasterInfoURL: URL(string: "https://www.city.itoman.lg.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.itoman.lg.jp/")!
        ),
        OkinawaMunicipality(
            id: "tomigusuku",
            name: "豊見城市",
            lat: 26.1611, lon: 127.6669,
            disasterInfoURL: URL(string: "https://www.city.tomigusuku.lg.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.tomigusuku.lg.jp/")!
        ),
        OkinawaMunicipality(
            id: "nanjo",
            name: "南城市",
            lat: 26.1447, lon: 127.7669,
            disasterInfoURL: URL(string: "https://www.city.nanjo.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.nanjo.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "nago",
            name: "名護市",
            lat: 26.5917, lon: 127.9775,
            disasterInfoURL: URL(string: "https://www.city.nago.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.nago.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "onna",
            name: "恩納村",
            lat: 26.4975, lon: 127.8536,
            disasterInfoURL: URL(string: "https://www.vill.onna.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.onna.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "miyakojima",
            name: "宮古島市",
            lat: 24.8056, lon: 125.2811,
            disasterInfoURL: URL(string: "https://www.city.miyakojima.lg.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.miyakojima.lg.jp/")!
        ),
        OkinawaMunicipality(
            id: "ishigaki",
            name: "石垣市",
            lat: 24.3444, lon: 124.1572,
            disasterInfoURL: URL(string: "https://www.city.ishigaki.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.city.ishigaki.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "taketomi",
            name: "竹富町",
            lat: 24.2875, lon: 123.8819,
            disasterInfoURL: URL(string: "https://www.town.taketomi.lg.jp/")!,
            evacuationInfoURL: URL(string: "https://www.town.taketomi.lg.jp/")!
        ),
        OkinawaMunicipality(
            id: "yonaguni",
            name: "与那国町",
            lat: 24.4681, lon: 122.9975,
            disasterInfoURL: URL(string: "https://www.town.yonaguni.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.town.yonaguni.okinawa.jp/")!
        ),
    ]

    /// 指定座標から最も近い自治体を返す。距離（km）も一緒に返す。
    static func nearest(to coordinate: CLLocationCoordinate2D) -> (municipality: OkinawaMunicipality, distanceKm: Double)? {
        guard !all.isEmpty else { return nil }
        var best = all[0]
        var bestDistance = RiskCalculator.distanceKm(from: coordinate, to: best.coordinate)
        for municipality in all.dropFirst() {
            let distance = RiskCalculator.distanceKm(from: coordinate, to: municipality.coordinate)
            if distance < bestDistance {
                best = municipality
                bestDistance = distance
            }
        }
        return (best, bestDistance)
    }

    static func nearest(to location: SavedLocation) -> (municipality: OkinawaMunicipality, distanceKm: Double)? {
        nearest(to: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon))
    }
}
