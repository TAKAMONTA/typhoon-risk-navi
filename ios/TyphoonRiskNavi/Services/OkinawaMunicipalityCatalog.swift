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
            disasterInfoURL: URL(string: "https://www.city.naha.okinawa.jp/safety/saigai/index.html")!,
            evacuationInfoURL: URL(string: "https://www.city.naha.okinawa.jp/safety/saigai/1001598/index.html")!
        ),
        OkinawaMunicipality(
            id: "ginowan",
            name: "宜野湾市",
            lat: 26.2816, lon: 127.7786,
            disasterInfoURL: URL(string: "https://www.city.ginowan.lg.jp/soshiki/somu/4/1/saigaihenosonae/2459.html")!,
            evacuationInfoURL: URL(string: "https://www.city.ginowan.lg.jp/soshiki/somu/4/1/2468.html")!
        ),
        OkinawaMunicipality(
            id: "urasoe",
            name: "浦添市",
            lat: 26.2458, lon: 127.7219,
            disasterInfoURL: URL(string: "https://www.city.urasoe.lg.jp/category/bunya/anshin/bosai/")!,
            evacuationInfoURL: URL(string: "https://www.city.urasoe.lg.jp/faq/60d6c271b68c817b09ae35fc/")!
        ),
        OkinawaMunicipality(
            id: "okinawa-city",
            name: "沖縄市",
            lat: 26.3344, lon: 127.8056,
            disasterInfoURL: URL(string: "https://www.city.okinawa.okinawa.jp/k002-001/anshin/bousai/saigaijouhou/492.html")!,
            evacuationInfoURL: URL(string: "https://www.city.okinawa.okinawa.jp/k002-001/anshin/bousai/bousai/hinan/22150.html")!
        ),
        OkinawaMunicipality(
            id: "uruma",
            name: "うるま市",
            lat: 26.3792, lon: 127.8575,
            disasterInfoURL: URL(string: "https://www.city.uruma.lg.jp/bousaianzen/bousaibouhan/bousai/index.html")!,
            evacuationInfoURL: URL(string: "https://www.city.uruma.lg.jp/bousaianzen/bousaibouhan/bousai/hinan/index.html")!
        ),
        OkinawaMunicipality(
            id: "itoman",
            name: "糸満市",
            lat: 26.1236, lon: 127.6658,
            disasterInfoURL: URL(string: "https://www.city.itoman.lg.jp/life/2/2/")!,
            evacuationInfoURL: URL(string: "https://www.city.itoman.lg.jp/life/2/2/3/")!
        ),
        OkinawaMunicipality(
            id: "tomigusuku",
            name: "豊見城市",
            lat: 26.1611, lon: 127.6669,
            disasterInfoURL: URL(string: "https://www.city.tomigusuku.lg.jp/kurashi_tetsuzuki/anshin_anzen/1/index.html")!,
            evacuationInfoURL: URL(string: "https://www.city.tomigusuku.lg.jp/kurashi_tetsuzuki/anshin_anzen/1/2/index.html")!
        ),
        OkinawaMunicipality(
            id: "nanjo",
            name: "南城市",
            lat: 26.1447, lon: 127.7669,
            disasterInfoURL: URL(string: "https://www.city.nanjo.okinawa.jp/bousai/")!,
            evacuationInfoURL: URL(string: "https://www.city.nanjo.okinawa.jp/bousai/")!
        ),
        OkinawaMunicipality(
            id: "nago",
            name: "名護市",
            lat: 26.5917, lon: 127.9775,
            disasterInfoURL: URL(string: "https://www.city.nago.okinawa.jp/category/guide/bousai/")!,
            evacuationInfoURL: URL(string: "https://www.city.nago.okinawa.jp/kurashi/2018071900677/")!
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
            disasterInfoURL: URL(string: "https://www.city.miyakojima.lg.jp/kurashi/bousai/index.html")!,
            evacuationInfoURL: URL(string: "https://www.city.miyakojima.lg.jp/kurashi/bousai/index.html")!
        ),
        OkinawaMunicipality(
            id: "ishigaki",
            name: "石垣市",
            lat: 24.3444, lon: 124.1572,
            disasterInfoURL: URL(string: "https://www.city.ishigaki.okinawa.jp/soshiki/1/2/index.html")!,
            evacuationInfoURL: URL(string: "https://www.city.ishigaki.okinawa.jp/soshiki/1/2/index.html")!
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
        // 本島北部
        OkinawaMunicipality(
            id: "kunigami",
            name: "国頭村",
            lat: 26.7457, lon: 128.1783,
            disasterInfoURL: URL(string: "https://www.vill.kunigami.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.kunigami.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "ogimi",
            name: "大宜味村",
            lat: 26.7018, lon: 128.1201,
            disasterInfoURL: URL(string: "https://www.vill.ogimi.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.ogimi.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "higashi",
            name: "東村",
            lat: 26.6334, lon: 128.1568,
            disasterInfoURL: URL(string: "https://www.vill.higashi.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.higashi.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "nakijin",
            name: "今帰仁村",
            lat: 26.6828, lon: 127.9729,
            disasterInfoURL: URL(string: "https://www.nakijin.jp/")!,
            evacuationInfoURL: URL(string: "https://www.nakijin.jp/")!
        ),
        OkinawaMunicipality(
            id: "motobu",
            name: "本部町",
            lat: 26.6575, lon: 127.8978,
            disasterInfoURL: URL(string: "https://www.town.motobu.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.town.motobu.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "ginoza",
            name: "宜野座村",
            lat: 26.4816, lon: 127.9756,
            disasterInfoURL: URL(string: "https://www.vill.ginoza.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.ginoza.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "kin",
            name: "金武町",
            lat: 26.4562, lon: 127.9260,
            disasterInfoURL: URL(string: "https://www.town.kin.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.town.kin.okinawa.jp/")!
        ),
        // 本島中部
        OkinawaMunicipality(
            id: "yomitan",
            name: "読谷村",
            lat: 26.3961, lon: 127.7444,
            disasterInfoURL: URL(string: "https://www.vill.yomitan.okinawa.jp/kurashi/anzen_anshin/bosai/index.html")!,
            evacuationInfoURL: URL(string: "https://www.vill.yomitan.okinawa.jp/kurashi/anzen_anshin/bosai/2303.html")!
        ),
        OkinawaMunicipality(
            id: "kadena",
            name: "嘉手納町",
            lat: 26.3618, lon: 127.7554,
            disasterInfoURL: URL(string: "https://www.town.kadena.okinawa.jp/life/kur97.html")!,
            evacuationInfoURL: URL(string: "https://www.town.kadena.okinawa.jp/life/kur7673.html")!
        ),
        OkinawaMunicipality(
            id: "chatan",
            name: "北谷町",
            lat: 26.3201, lon: 127.7638,
            disasterInfoURL: URL(string: "https://www.chatan.jp/seikatsuguide/anshin_anzen/taisaku/index.html")!,
            evacuationInfoURL: URL(string: "https://www.chatan.jp/seikatsuguide/anshin_anzen/taisaku/hinannbsyohinanzyo.html")!
        ),
        OkinawaMunicipality(
            id: "kitanakagusuku",
            name: "北中城村",
            lat: 26.3007, lon: 127.7929,
            disasterInfoURL: URL(string: "https://www.vill.kitanakagusuku.lg.jp/kakuka/soumu/soumukakari/bousai/index.html")!,
            evacuationInfoURL: URL(string: "https://www.vill.kitanakagusuku.lg.jp/kakuka/soumu/soumukakari/bousai/1597.html")!
        ),
        OkinawaMunicipality(
            id: "nakagusuku",
            name: "中城村",
            lat: 26.2620, lon: 127.7896,
            disasterInfoURL: URL(string: "https://www.vill.nakagusuku.okinawa.jp/bousai/")!,
            evacuationInfoURL: URL(string: "https://www.vill.nakagusuku.okinawa.jp/bousai/emergency_info/")!
        ),
        // 本島南部
        OkinawaMunicipality(
            id: "nishihara",
            name: "西原町",
            lat: 26.2230, lon: 127.7589,
            disasterInfoURL: URL(string: "https://www.town.nishihara.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.town.nishihara.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "yonabaru",
            name: "与那原町",
            lat: 26.1996, lon: 127.7545,
            disasterInfoURL: URL(string: "https://www.town.yonabaru.okinawa.jp/life/1/1/")!,
            evacuationInfoURL: URL(string: "https://www.town.yonabaru.okinawa.jp/life/1/1/2/")!
        ),
        OkinawaMunicipality(
            id: "haebaru",
            name: "南風原町",
            lat: 26.1911, lon: 127.7285,
            disasterInfoURL: URL(string: "https://www.town.haebaru.lg.jp/life/1/8/")!,
            evacuationInfoURL: URL(string: "https://www.town.haebaru.lg.jp/soshiki/4/3230.html")!
        ),
        OkinawaMunicipality(
            id: "yaese",
            name: "八重瀬町",
            lat: 26.1583, lon: 127.7187,
            disasterInfoURL: URL(string: "https://www.town.yaese.lg.jp/docs/2014042500044/")!,
            evacuationInfoURL: URL(string: "https://www.town.yaese.lg.jp/docs/2014042500044/")!
        ),
        // 離島（本島周辺・慶良間・久米島）
        OkinawaMunicipality(
            id: "ie",
            name: "伊江村",
            lat: 26.7134, lon: 127.8071,
            disasterInfoURL: URL(string: "https://www.iejima.org/")!,
            evacuationInfoURL: URL(string: "https://www.iejima.org/")!
        ),
        OkinawaMunicipality(
            id: "iheya",
            name: "伊平屋村",
            lat: 27.0391, lon: 127.9687,
            disasterInfoURL: URL(string: "https://www.vill.iheya.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.iheya.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "izena",
            name: "伊是名村",
            lat: 26.9237, lon: 127.9413,
            disasterInfoURL: URL(string: "https://www.vill.izena.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.izena.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "tokashiki",
            name: "渡嘉敷村",
            lat: 26.1975, lon: 127.3644,
            disasterInfoURL: URL(string: "https://www.vill.tokashiki.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.tokashiki.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "zamami",
            name: "座間味村",
            lat: 26.2289, lon: 127.3032,
            disasterInfoURL: URL(string: "https://www.vill.zamami.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.zamami.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "aguni",
            name: "粟国村",
            lat: 26.5818, lon: 127.2289,
            disasterInfoURL: URL(string: "https://www.vill.aguni.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.aguni.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "tonaki",
            name: "渡名喜村",
            lat: 26.3721, lon: 127.1411,
            disasterInfoURL: URL(string: "https://www.vill.tonaki.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.tonaki.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "kumejima",
            name: "久米島町",
            lat: 26.3407, lon: 126.8049,
            disasterInfoURL: URL(string: "https://www.town.kumejima.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.town.kumejima.okinawa.jp/")!
        ),
        // 大東諸島・先島の離島
        OkinawaMunicipality(
            id: "minamidaito",
            name: "南大東村",
            lat: 25.8288, lon: 131.2321,
            disasterInfoURL: URL(string: "https://www.vill.minamidaito.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.minamidaito.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "kitadaito",
            name: "北大東村",
            lat: 25.9458, lon: 131.2990,
            disasterInfoURL: URL(string: "https://www.vill.kitadaito.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.kitadaito.okinawa.jp/")!
        ),
        OkinawaMunicipality(
            id: "tarama",
            name: "多良間村",
            lat: 24.6693, lon: 124.7016,
            disasterInfoURL: URL(string: "https://www.vill.tarama.okinawa.jp/")!,
            evacuationInfoURL: URL(string: "https://www.vill.tarama.okinawa.jp/")!
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
