import Foundation

/// 気象庁の警報・注意報（沖縄4地方）。
/// 注: 自治体の「避難指示」そのものは公開APIが限られるため、
/// ここでは公式の気象警報・注意報を自動取得し、避難指示は自治体リンクで補完する。
struct OfficialWarning: Identifiable, Equatable {
    let id: String
    let areaName: String
    let headline: String
    let warningNames: [String]
    let reportDatetime: String
    let detailURL: URL

    var hasActiveWarning: Bool {
        !warningNames.isEmpty
    }

    /// `reportDatetime`（ISO8601, 例: "2026-05-28T10:13:00+09:00"）をパースした発表日時。
    var reportDate: Date? {
        ISO8601DateFormatter.internetDateTime.date(from: reportDatetime)
    }

    /// 気象庁側の警報エンドポイントが更新停止するなどして情報が古いまま止まっている場合、
    /// 現在の警報として誤解させないための鮮度しきい値。台風接近時は数時間単位で状況が変わるため、
    /// 24時間より古い発表は「最新情報ではない」とみなす。
    static let stalenessThreshold: TimeInterval = 24 * 60 * 60

    /// 発表日時が取得できない、またはしきい値より古い場合に true。
    var isStale: Bool {
        guard let reportDate else { return true }
        return Date().timeIntervalSince(reportDate) > Self.stalenessThreshold
    }

    /// 発表時刻を日本語で読める形（例: "5月28日 10:13 発表"）に整形。パース不能なら nil。
    var reportDateDescription: String? {
        guard let reportDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: reportDate) + " 発表"
    }
}

private extension ISO8601DateFormatter {
    static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

enum JMAWarningFetcher {

    enum FetchError: LocalizedError {
        case invalidResponse
        case http(statusCode: Int)
        case decoding

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "警報データの応答が不正です"
            case .http(let code): return "警報データの取得に失敗しました (\(code))"
            case .decoding: return "警報データを解釈できませんでした"
            }
        }
    }

    /// 沖縄の予報区（本島・大東・宮古・八重山）
    static let okinawaOffices: [(code: String, name: String)] = [
        ("471000", "沖縄本島地方"),
        ("472000", "大東島地方"),
        ("473000", "宮古島地方"),
        ("474000", "八重山地方"),
    ]

    /// 気象庁の警報コード（主要なもの）
    private static let warningCodeNames: [String: String] = [
        "02": "暴風雪警報",
        "03": "大雨警報",
        "04": "洪水警報",
        "05": "暴風警報",
        "06": "大雪警報",
        "07": "波浪警報",
        "08": "高潮警報",
        "10": "大雨注意報",
        "12": "大雪注意報",
        "13": "風雪注意報",
        "14": "雷注意報",
        "15": "強風注意報",
        "16": "波浪注意報",
        "17": "融雪注意報",
        "18": "洪水注意報",
        "19": "高潮注意報",
        "20": "濃霧注意報",
        "21": "乾燥注意報",
        "22": "なだれ注意報",
        "23": "低温注意報",
        "24": "霜注意報",
        "25": "着氷注意報",
        "26": "着雪注意報",
        "27": "その他の注意報",
        "32": "暴風警報",
        "33": "大雨特別警報",
        "35": "暴風特別警報",
        "36": "大雪特別警報",
        "37": "波浪特別警報",
        "38": "高潮特別警報",
    ]

    static func warningURL(officeCode: String) -> URL {
        URL(string: "https://www.jma.go.jp/bosai/warning/data/warning/\(officeCode).json")!
    }

    static func detailPageURL(officeCode: String) -> URL {
        URL(string: "https://www.jma.go.jp/bosai/warning/#area_type=offices&area_code=\(officeCode)&lang=ja")!
    }

    /// 沖縄4地方の警報・注意報を取得。失敗した地方はスキップ。
    static func fetchOkinawaWarnings(
        session: URLSession = .shared
    ) async -> [OfficialWarning] {
        var results: [OfficialWarning] = []
        for office in okinawaOffices {
            if let warning = try? await fetchWarning(officeCode: office.code, areaName: office.name, session: session) {
                results.append(warning)
            }
        }
        return results
    }

    /// 代表地点に近い地方を優先して並べた一覧。
    static func prioritized(
        warnings: [OfficialWarning],
        nearMunicipalityId: String?
    ) -> [OfficialWarning] {
        let preferredOffice: String?
        switch nearMunicipalityId {
        case "miyakojima":
            preferredOffice = "473000"
        case "ishigaki", "taketomi", "yonaguni":
            preferredOffice = "474000"
        default:
            preferredOffice = "471000"
        }

        return warnings.sorted { lhs, rhs in
            let lActive = lhs.hasActiveWarning ? 0 : 1
            let rActive = rhs.hasActiveWarning ? 0 : 1
            if lActive != rActive { return lActive < rActive }
            if let preferredOffice {
                let lPref = lhs.id == preferredOffice ? 0 : 1
                let rPref = rhs.id == preferredOffice ? 0 : 1
                if lPref != rPref { return lPref < rPref }
            }
            return lhs.areaName < rhs.areaName
        }
    }

    static func fetchWarning(
        officeCode: String,
        areaName: String,
        session: URLSession = .shared
    ) async throws -> OfficialWarning {
        let data = try await fetchData(from: warningURL(officeCode: officeCode), session: session)
        return try parseWarning(data: data, officeCode: officeCode, areaName: areaName)
    }

    static func parseWarning(
        data: Data,
        officeCode: String,
        areaName: String
    ) throws -> OfficialWarning {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else { throw FetchError.decoding }

        let headline = (dict["headlineText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reportDatetime = dict["reportDatetime"] as? String ?? ""

        var activeNames = Set<String>()
        if let areaTypes = dict["areaTypes"] as? [[String: Any]] {
            for areaType in areaTypes {
                guard let areas = areaType["areas"] as? [[String: Any]] else { continue }
                for area in areas {
                    guard let warnings = area["warnings"] as? [[String: Any]] else { continue }
                    for warning in warnings {
                        let status = warning["status"] as? String ?? ""
                        guard status != "解除" else { continue }
                        guard let code = warning["code"] as? String else { continue }
                        if let name = warningCodeNames[code] {
                            activeNames.insert(name)
                        } else {
                            activeNames.insert("気象情報(\(code))")
                        }
                    }
                }
            }
        }

        let cleanedHeadline: String
        if activeNames.isEmpty, headline.contains("解除") {
            cleanedHeadline = "現在、発表中の警報・注意報はありません"
        } else if headline.isEmpty {
            cleanedHeadline = activeNames.isEmpty
                ? "現在、発表中の警報・注意報はありません"
                : activeNames.sorted().joined(separator: "・")
        } else {
            cleanedHeadline = headline
        }

        return OfficialWarning(
            id: officeCode,
            areaName: areaName,
            headline: cleanedHeadline,
            warningNames: activeNames.sorted(),
            reportDatetime: reportDatetime,
            detailURL: detailPageURL(officeCode: officeCode)
        )
    }

    private static func fetchData(from url: URL, session: URLSession) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 OkinawaTyphoonNavi/0.9",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json, */*;q=0.1", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.http(statusCode: http.statusCode)
        }
        return data
    }
}
