import Foundation

/// 気象庁（JMA）の specifications.json を既存 Typhoon モデルへ変換する純関数群。
/// ネットワーク I/O を持たないので、ユニットテストで JSON サンプルを直接渡せる。
enum JMAParser {

    /// specifications.json の生データから Typhoon を組み立てる。
    static func parseSpecifications(_ data: Data, eventId: String) throws -> Typhoon {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let array = json as? [[String: Any]] else {
            throw JMAFetcher.FetchError.decoding
        }
        guard let typhoon = parseSpecificationsArray(array, eventId: eventId) else {
            throw JMAFetcher.FetchError.decoding
        }
        return typhoon
    }

    /// パース済み JSON 配列から Typhoon を組み立てる（テスト用にも公開）。
    static func parseSpecificationsArray(_ array: [[String: Any]], eventId: String) -> Typhoon? {
        guard let title = array.first(where: { isTitlePart($0["part"]) }),
              let analysis = array.first(where: { isAnalysisPart($0) }),
              let position = analysis["position"] as? [String: Any],
              let deg = position["deg"] as? [Double], deg.count >= 2 else {
            return nil
        }

        let typhoonNumber = title["typhoonNumber"] as? String ?? eventId
        let nameInfo = title["name"] as? [String: String] ?? [:]
        let nameEn = nameInfo["en"] ?? "TYPHOON"
        let nameJp = nameInfo["jp"].map { "台風第\(typhoonNumberSuffix(typhoonNumber))号（\($0)）" }
            ?? "台風第\(typhoonNumberSuffix(typhoonNumber))号"

        let issueTime = (title["issue"] as? [String: String])?["UTC"]
            ?? (title["issue"] as? [String: String])?["JST"]
            ?? ISO8601DateFormatter().string(from: Date())

        let maxWindMS = parseMaxWindMS(from: analysis)
        let pressure = parseIntString(analysis["pressure"])
        let course = analysis["course"] as? String
        let speedKmh = parseSpeedKmh(from: analysis)
        let windRadii = parseWindRadii(from: analysis)

        let forecasts = array
            .filter { isForecastPart($0) }
            .compactMap { parseForecastPoint($0) }

        return Typhoon(
            id: "JMA-\(eventId)",
            name: nameEn.uppercased(),
            nameJa: nameJp,
            source: "JMA",
            status: "ACTIVE",
            currentCenter: Coordinate(lat: deg[0], lon: deg[1]),
            maxWindSpeed: maxWindMS,
            centralPressure: pressure,
            direction: courseToDegrees(course),
            speed: speedKmh,
            windRadii: windRadii,
            forecasts: forecasts,
            lastUpdated: issueTime
        )
    }

    // MARK: - Part detection

    static func isTitlePart(_ part: Any?) -> Bool {
        if let s = part as? String { return s == "title" }
        return false
    }

    static func isAnalysisPart(_ dict: [String: Any]) -> Bool {
        guard dict["part"] != nil else { return false }
        if let hours = dict["advancedHours"] as? Int, hours == 0 { return true }
        if let partObj = dict["part"] as? [String: String] {
            return partObj["jp"] == "実況" || partObj["en"] == "Analysis"
        }
        return false
    }

    static func isForecastPart(_ dict: [String: Any]) -> Bool {
        guard let hours = dict["advancedHours"] as? Int, hours > 0 else { return false }
        guard dict["position"] != nil else { return false }
        if let partObj = dict["part"] as? [String: String] {
            return partObj["jp"]?.contains("予報") == true || partObj["en"]?.contains("Forecast") == true
        }
        return true
    }

    // MARK: - Field parsing

    static func parseForecastPoint(_ dict: [String: Any]) -> ForecastPoint? {
        guard let position = dict["position"] as? [String: Any],
              let deg = position["deg"] as? [Double], deg.count >= 2 else {
            return nil
        }

        let validTime: String
        if let vt = dict["validtime"] as? [String: String], let utc = vt["UTC"] {
            validTime = utc
        } else if let vt = dict["validtime"] as? [String: String], let jst = vt["JST"] {
            validTime = jst
        } else {
            validTime = ISO8601DateFormatter().string(from: Date())
        }

        let radiusKm: Double? = {
            guard let range = dict["probabilityCircleRadius"] as? [String: Any] else { return nil }
            if let km = range["km"] as? Int { return Double(km) }
            if let km = range["km"] as? Double { return km }
            return nil
        }()

        return ForecastPoint(
            validTime: validTime,
            center: Coordinate(lat: deg[0], lon: deg[1]),
            radius: radiusKm,
            maxWindSpeed: parseMaxWindMS(from: dict),
            windRadii: parseWindRadii(from: dict)
        )
    }

    static func parseMaxWindMS(from dict: [String: Any]) -> Double? {
        guard let wind = dict["maximumWind"] as? [String: Any],
              let sustained = wind["sustained"] as? [String: Any] else { return nil }
        if let msStr = sustained["m/s"] as? String, let ms = Double(msStr) { return ms }
        if let ktStr = sustained["kt"] as? String, let kt = Double(ktStr) { return kt * 0.51444 }
        return nil
    }

    static func parseSpeedKmh(from dict: [String: Any]) -> Double? {
        guard let speed = dict["speed"] as? [String: Any] else { return nil }
        if let kmhStr = speed["km/h"] as? String, let kmh = Double(kmhStr) { return kmh }
        if let ktStr = speed["kt"] as? String, let kt = Double(ktStr) { return kt * 1.852 }
        return nil
    }

    static func parseWindRadii(from dict: [String: Any]) -> WindRadii? {
        let r34 = maxRangeKm(from: dict["galeWarning"] as? [[String: Any]])
        let r64 = maxRangeKm(from: dict["stormWarning"] as? [[String: Any]])
        let r50: Double?
        if let r34, let r64, r34 > 0, r64 > 0 {
            r50 = (r34 + r64) / 2.0
        } else {
            r50 = nil
        }
        if r34 == nil && r50 == nil && r64 == nil { return nil }
        return WindRadii(radius34kt: r34, radius50kt: r50, radius64kt: r64)
    }

    static func maxRangeKm(from warnings: [[String: Any]]?) -> Double? {
        guard let warnings, !warnings.isEmpty else { return nil }
        let kms = warnings.compactMap { warning -> Double? in
            guard let range = warning["range"] as? [String: Any] else { return nil }
            if let km = range["km"] as? Int { return Double(km) }
            if let km = range["km"] as? Double { return km }
            return nil
        }
        return kms.max()
    }

    static func parseIntString(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let s = value as? String { return Int(s) }
        return nil
    }

    static func typhoonNumberSuffix(_ number: String) -> String {
        if number.count >= 2 {
            let suffix = number.suffix(2)
            if let n = Int(suffix), n > 0 { return String(n) }
        }
        return number
    }

    /// 気象庁の進行方向（日本語）をおおよその方位角（度）へ変換。
    static func courseToDegrees(_ course: String?) -> Int? {
        guard let course else { return nil }
        let trimmed = course.trimmingCharacters(in: .whitespacesAndNewlines)
        let map: [String: Int] = [
            "北": 0, "北北東": 22, "北東": 45, "東北東": 67,
            "東": 90, "東南東": 112, "南東": 135, "南南東": 157,
            "南": 180, "南南西": 202, "南西": 225, "西南西": 247,
            "西": 270, "西北西": 292, "北西": 315, "北北西": 337,
        ]
        return map[trimmed]
    }
}
