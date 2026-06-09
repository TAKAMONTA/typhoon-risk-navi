import Foundation

/// JTWC (Joint Typhoon Warning Center) の警告テキストをパースする純関数群。
/// ネットワーク I/O を持たないので、ユニットテストでサンプルテキストを直接渡せる。
///
/// 入力例:
///   WTPN31 PGTW 300300
///   SUBJ/TYPHOON 06W (KONG-REY) WARNING NR 012//
///   1. TYPHOON 06W (KONG-REY) LOCATED AT 30.1N 127.8E AT 300000Z
///      MAX SUSTAINED WINDS - 065 KT
///      RADIUS OF 034 KT WINDS - 120 NM NORTHEAST QUADRANT
///      ...
///   2. FORECASTS:
///      6 HRS, VALID AT: 300600Z --- 31.0N 126.5E
///      MAX SUSTAINED WINDS - 060 KT
///      RADIUS OF 034 KT WINDS - 090 NM NORTHEAST QUADRANT
enum JTWCParser {

    /// 複数の台風警告が含まれる生テキストをパース
    static func parseWarnings(_ rawText: String) -> [Typhoon] {
        let warnings = splitWarnings(rawText)
        return warnings.compactMap { parseSingleWarning($0) }
    }

    /// 警告テキストを WTPN ヘッダで分割
    static func splitWarnings(_ rawText: String) -> [String] {
        let pattern = #"WTPN\d{2}"#
        guard let re = try? NSRegularExpression(pattern: pattern) else {
            return [rawText]
        }
        let ns = rawText as NSString
        let matches = re.matches(in: rawText, range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty {
            return [rawText]
        }
        var result: [String] = []
        for (i, m) in matches.enumerated() {
            let start = m.range.location
            let end: Int = (i + 1 < matches.count) ? matches[i + 1].range.location : ns.length
            let chunk = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                result.append(chunk)
            }
        }
        return result
    }

    /// 単一の警告テキストから Typhoon を組み立てる。位置が取れない場合は nil。
    static func parseSingleWarning(_ text: String) -> Typhoon? {
        guard let (number, name) = matchNumberAndName(in: text) else { return nil }
        guard let center = matchCurrentPosition(in: text) else { return nil }

        // 現在位置のメタ情報は "FORECASTS:" より前のセクションだけ見る。
        // 予報ブロックの数値で上書きされないようにするため。
        let currentSection = currentPositionSection(of: text)

        let maxWindKt = matchInt(in: currentSection, pattern: #"MAX SUSTAINED WINDS\s*-\s*(\d+)\s*KT"#)
        let pressure = matchInt(in: currentSection, pattern: #"CENTRAL PRESSURE\s+(\d+)\s*MB"#)
        let movement = matchTwoNumbers(in: currentSection, pattern: #"MOVEMENT PAST SIX HOURS\s+(\d+)\s+DEGREES AT\s+([\d.]+)"#)

        let quadrantRadii = parseWindRadii(currentSection)
        let flatRadii = quadrantToFlat(quadrantRadii)

        let forecasts = parseForecasts(text)

        let now = ISO8601DateFormatter().string(from: Date())

        // 型推論を軽くするために中間変数で組み立てる
        let id = "JTWC-\(number)"
        let maxWindMS: Double? = maxWindKt.map { Double($0) * 0.51444 }   // kt → m/s
        let direction: Int? = movement?.0
        let speedKmh: Double? = movement.map { _, kts in kts * 1.852 }    // kt → km/h

        return Typhoon(
            id: id,
            name: name,
            nameJa: nil,
            source: "JTWC",
            status: "ACTIVE",
            currentCenter: center,
            maxWindSpeed: maxWindMS,
            centralPressure: pressure,
            direction: direction,
            speed: speedKmh,
            windRadii: flatRadii,
            forecasts: forecasts,
            lastUpdated: now
        )
    }

    // MARK: - Internal helpers (exposed for testing)

    static func matchNumberAndName(in text: String) -> (String, String)? {
        let pattern = #"TYPHOON\s+(\d{2}W)\s*\(([^)]+)\)"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 3 else { return nil }
        let number = ns.substring(with: m.range(at: 1))
        let name = ns.substring(with: m.range(at: 2))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (number, name)
    }

    static func matchCurrentPosition(in text: String) -> Coordinate? {
        if let coord = matchPosition(in: text, pattern: #"LOCATED AT\s+([\d.]+)([NS])\s+([\d.]+)([EW])"#) {
            return coord
        }
        if let coord = matchPosition(in: text, pattern: #"(?:\d{6}Z\s*---\s*)?NEAR\s+([\d.]+)([NS])\s+([\d.]+)([EW])"#) {
            return coord
        }
        return nil
    }

    static func matchPosition(in text: String, pattern: String) -> Coordinate? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 5 else { return nil }
        let latStr = ns.substring(with: m.range(at: 1))
        let latHemi = ns.substring(with: m.range(at: 2)).uppercased()
        let lonStr = ns.substring(with: m.range(at: 3))
        let lonHemi = ns.substring(with: m.range(at: 4)).uppercased()
        guard let latVal = Double(latStr), let lonVal = Double(lonStr) else { return nil }
        let lat = latVal * (latHemi == "S" ? -1 : 1)
        let lon = lonVal * (lonHemi == "W" ? -1 : 1)
        return Coordinate(lat: lat, lon: lon)
    }

    static func matchInt(in text: String, pattern: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2 else { return nil }
        return Int(ns.substring(with: m.range(at: 1)))
    }

    static func matchTwoNumbers(in text: String, pattern: String) -> (Int, Double)? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 3 else { return nil }
        guard let a = Int(ns.substring(with: m.range(at: 1))),
              let b = Double(ns.substring(with: m.range(at: 2))) else { return nil }
        return (a, b)
    }

    /// "RADIUS OF NNN KT WINDS - NNN NM XXX QUADRANT" 表記を抽出
    static func parseWindRadii(_ text: String) -> [String: [String: Int]] {
        var radii: [String: [String: Int]] = [:]

        let newPattern = #"RADIUS OF\s+(\d+)\s*KT WINDS\s*-\s*(\d+)\s*NM\s+(\w+)\s+QUADRANT"#
        appendQuadrants(into: &radii, text: text, pattern: newPattern)

        let oldPattern = #"(\d+)\s*KT WINDS\s+(\d+)\s*NM\s+(\w+)\s+QUADRANT"#
        appendQuadrants(into: &radii, text: text, pattern: oldPattern)

        return radii
    }

    private static func appendQuadrants(into radii: inout [String: [String: Int]], text: String, pattern: String) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for m in matches where m.numberOfRanges >= 4 {
            let knots = ns.substring(with: m.range(at: 1))
            guard let nm = Int(ns.substring(with: m.range(at: 2))) else { continue }
            let q = ns.substring(with: m.range(at: 3)).uppercased()
            let quadrant: String
            if q.hasPrefix("NO") { quadrant = "NE" }
            else if q.hasPrefix("SO") { quadrant = "SE" }
            else if q.hasPrefix("SW") { quadrant = "SW" }
            else { quadrant = "NW" }
            radii[knots, default: [:]][quadrant] = nm
        }
    }

    /// quadrant 形式 (NM) を flat 形式 (km) に変換。各バンドの最大値を採用。
    static func quadrantToFlat(_ q: [String: [String: Int]]) -> WindRadii? {
        let r34 = bandMaxKm(q, band: "034") ?? bandMaxKm(q, band: "34")
        let r50 = bandMaxKm(q, band: "050") ?? bandMaxKm(q, band: "50")
        let r64 = bandMaxKm(q, band: "064") ?? bandMaxKm(q, band: "64")
        if r34 == nil && r50 == nil && r64 == nil { return nil }
        return WindRadii(radius34kt: r34, radius50kt: r50, radius64kt: r64)
    }

    private static func bandMaxKm(_ q: [String: [String: Int]], band: String) -> Double? {
        guard let quadrants = q[band], !quadrants.isEmpty else { return nil }
        let maxNm = quadrants.values.max() ?? 0
        if maxNm <= 0 { return nil }
        return Double(maxNm) * 1.852
    }

    // MARK: - Section split

    /// "FORECASTS:" の手前までを「現在位置のセクション」として返す。
    /// 見つからなければ元のテキストをそのまま返す（保守的なフォールバック）。
    static func currentPositionSection(of text: String) -> String {
        guard let re = try? NSRegularExpression(pattern: #"FORECASTS?:"#, options: .caseInsensitive) else {
            return text
        }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return text
        }
        return ns.substring(to: m.range.location)
    }

    // MARK: - Forecasts

    /// "FORECASTS:" 以降から、各予報ブロックを抽出
    static func parseForecasts(_ text: String) -> [ForecastPoint] {
        // セクションを切り出す
        guard let re = try? NSRegularExpression(pattern: #"FORECASTS?:"#, options: .caseInsensitive) else { return [] }
        let ns = text as NSString
        guard let firstMatch = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return [] }
        let sectionStart = firstMatch.range.location + firstMatch.range.length
        guard sectionStart < ns.length else { return [] }
        let section = ns.substring(from: sectionStart)

        let pattern = #"(\d+)\s*HRS.*?VALID AT:\s*(\d{6})Z\s*---\s*([\d.]+)([NS])\s+([\d.]+)([EW])([\s\S]*?)(?=\d+\s*HRS|FORECAST|$)"#
        guard let blockRe = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let sNs = section as NSString
        let matches = blockRe.matches(in: section, range: NSRange(location: 0, length: sNs.length))

        var out: [ForecastPoint] = []
        let isoFormatter = ISO8601DateFormatter()
        let now = Date()

        for m in matches where m.numberOfRanges >= 8 {
            guard let hours = Int(sNs.substring(with: m.range(at: 1))),
                  let latVal = Double(sNs.substring(with: m.range(at: 3))),
                  let lonVal = Double(sNs.substring(with: m.range(at: 5))) else { continue }
            let latHemi = sNs.substring(with: m.range(at: 4)).uppercased()
            let lonHemi = sNs.substring(with: m.range(at: 6)).uppercased()
            let lat = latVal * (latHemi == "S" ? -1 : 1)
            let lon = lonVal * (lonHemi == "W" ? -1 : 1)
            let center = Coordinate(lat: lat, lon: lon)

            let blockText = sNs.substring(with: m.range(at: 7))
            let blockRadii = quadrantToFlat(parseWindRadii(blockText))
            let blockMaxKt = matchInt(in: blockText, pattern: #"MAX SUSTAINED WINDS\s*-\s*(\d+)\s*KT"#)

            let validTime = isoFormatter.string(from: now.addingTimeInterval(TimeInterval(hours) * 3600))

            out.append(ForecastPoint(
                validTime: validTime,
                center: center,
                radius: nil,
                maxWindSpeed: blockMaxKt.map { Double($0) * 0.51444 },
                windRadii: blockRadii
            ))
        }

        return out
    }
}
