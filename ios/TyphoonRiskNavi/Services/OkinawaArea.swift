import Foundation

/// 沖縄の体感投稿エリア。気象庁の細分区域（class15）に従って10区分。
/// 慶良間・粟国は気象庁が本島中南部の中でも別区域として扱うため独立させる
/// （那覇に混ぜると4村の体感が市街の投稿に埋もれる）。
/// スペック: docs/superpowers/specs/2026-08-15-area-mood-posts-design.md §4
enum OkinawaArea: String, CaseIterable, Codable, Identifiable {
    case naha
    case south
    case central
    case north
    case keramaAguni
    case kumejima
    case miyako
    case ishigaki
    case yonaguni
    case daito

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .naha: return "那覇"
        case .south: return "南部"
        case .central: return "中部"
        case .north: return "北部"
        case .keramaAguni: return "慶良間・粟国"
        case .kumejima: return "久米島"
        case .miyako: return "宮古"
        case .ishigaki: return "石垣"
        case .yonaguni: return "与那国"
        case .daito: return "大東"
        }
    }

    /// 自治体ID（OkinawaMunicipalityCatalog の id）→ エリアの対応表。
    /// 気象庁 area.json の class15 区分に従う。浦添は地理的には中部寄りだが気象庁区分では南部。
    static let municipalityAreaMap: [String: OkinawaArea] = [
        "naha": .naha,
        // 南部
        "urasoe": .south, "itoman": .south, "tomigusuku": .south, "nanjo": .south,
        "nishihara": .south, "yonabaru": .south, "haebaru": .south, "yaese": .south,
        // 中部
        "ginowan": .central, "okinawa-city": .central, "uruma": .central, "yomitan": .central,
        "kadena": .central, "chatan": .central, "kitanakagusuku": .central, "nakagusuku": .central,
        // 北部（伊平屋・伊是名・伊江は離島だが気象庁も本島北部に含める）
        "nago": .north, "kunigami": .north, "ogimi": .north, "higashi": .north,
        "nakijin": .north, "motobu": .north, "ie": .north, "onna": .north,
        "ginoza": .north, "kin": .north, "iheya": .north, "izena": .north,
        // 慶良間・粟国諸島
        "tokashiki": .keramaAguni, "zamami": .keramaAguni, "aguni": .keramaAguni, "tonaki": .keramaAguni,
        // その他離島
        "kumejima": .kumejima,
        "miyakojima": .miyako, "tarama": .miyako,
        "ishigaki": .ishigaki, "taketomi": .ishigaki,
        "yonaguni": .yonaguni,
        "minamidaito": .daito, "kitadaito": .daito,
    ]
}

extension OkinawaMunicipality {
    /// この自治体が属する体感エリア。カタログ全41自治体が対応表に載っていることは
    /// OkinawaAreaTests が全数検査で保証する。
    var area: OkinawaArea? {
        OkinawaArea.municipalityAreaMap[id]
    }
}
