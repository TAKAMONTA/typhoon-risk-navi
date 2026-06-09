import Foundation
import CoreLocation

/// 台風と保存場所からリスクを計算する純関数群。
/// backend/src/services/risk/RiskCalculationService.ts を Swift へ移植。
/// 副作用なし／テスト容易。
enum RiskCalculator {

    // MARK: - Public API

    /// 単一の場所に対するリスク評価を返す
    static func assess(
        location: SavedLocation,
        typhoon: Typhoon,
        now: Date = Date()
    ) -> RiskAssessment {
        let currentDistance = distanceKm(
            from: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon),
            to: typhoon.currentCenter.clLocation
        )

        let arrival34 = estimateArrival(location: location, typhoon: typhoon, targetKnots: 34, now: now)
        let arrival50 = estimateArrival(location: location, typhoon: typhoon, targetKnots: 50, now: now)
        let arrival64 = estimateArrival(location: location, typhoon: typhoon, targetKnots: 64, now: now)

        let riskLevel = determineRiskLevel(
            hours34: arrival34?.hours,
            hours50: arrival50?.hours,
            hours64: arrival64?.hours
        )

        let closest = findClosestApproach(location: location, typhoon: typhoon)

        var notes: [String] = []
        if let h64 = arrival64?.hours, h64 < 12 {
            notes.append("非常に強い風が短時間で到達する可能性があります。")
        } else if let h50 = arrival50?.hours, h50 < 12 {
            notes.append("強い風が短時間で到達する可能性があります。早めの備えを。")
        } else if let h34 = arrival34?.hours, h34 < 6 {
            notes.append("強風域が非常に近くまで迫っています。")
        }

        switch typhoon.source {
        case "JTWC":
            notes.append("米軍JTWCの予報に基づく推定です。")
        case "JMA":
            notes.append("気象庁の予報に基づく推定です。")
        case "DEMO":
            notes.append("デモデータによる推定です。実データではありません。")
        default:
            break
        }

        let decay = computeDynamicDecayRate(for: typhoon, now: now)
        notes.append(String(format: "精度モデル: %.1f%%（緯度・風速トレンドベース）", decay * 100))

        return RiskAssessment(
            locationId: location.id,
            locationName: location.name,
            typhoonId: typhoon.id,
            typhoonName: typhoon.name,
            arrival34kt: arrival34,
            arrival50kt: arrival50,
            arrival64kt: arrival64,
            estimatedClosestApproach: closest.time,
            distanceToClosestKm: closest.distanceKm.map { Int($0.rounded()) },
            currentDistanceKm: Int(currentDistance.rounded()),
            riskLevel: riskLevel,
            source: typhoon.source,
            calculatedAt: ISO8601DateFormatter().string(from: now),
            notes: notes
        )
    }

    /// 複数の場所をまとめて評価
    static func assessAll(
        locations: [SavedLocation],
        typhoon: Typhoon,
        now: Date = Date()
    ) -> [RiskAssessment] {
        return locations.map { assess(location: $0, typhoon: typhoon, now: now) }
    }

    // MARK: - Dynamic Decay Rate

    /// 動的減衰率を台風自身の予報から算出（4〜16%/日）。
    /// 緯度進行（北上）と最大風速の弱体化トレンドに基づく。
    static func computeDynamicDecayRate(for typhoon: Typhoon, now: Date = Date()) -> Double {
        var rate: Double = 0.08
        let iso = ISO8601DateFormatter()

        struct Point { let time: Date; let lat: Double; let maxWindKt: Double? }
        var points: [Point] = []

        // 現在位置（maxWindSpeed は m/s なので kt に換算）
        let currentKt: Double? = typhoon.maxWindSpeed.map { $0 / 0.51444 }
        points.append(Point(time: now, lat: typhoon.currentCenter.lat, maxWindKt: currentKt))

        for fp in typhoon.forecasts {
            guard let t = iso.date(from: fp.validTime) else { continue }
            let kt: Double? = fp.maxWindSpeed.map { $0 / 0.51444 }
            points.append(Point(time: t, lat: fp.center.lat, maxWindKt: kt))
        }

        guard points.count >= 2 else { return rate }
        let first = points.first!
        let last = points.last!
        let timeSpanHours = last.time.timeIntervalSince(first.time) / 3600.0

        if timeSpanHours > 3.0 {
            let dLat = last.lat - first.lat
            let dLatPerDay = dLat * (24.0 / timeSpanHours)
            let avgLat = (first.lat + last.lat) / 2.0

            if dLatPerDay > 1.2 && avgLat > 18.0 {
                let latBoost = min(0.045, (dLatPerDay - 1.2) * 0.018)
                rate += latBoost
            }
            if avgLat > 30.0 {
                rate += 0.025
            }
        }

        let windPoints: [(Date, Double)] = points.compactMap { p in
            guard let w = p.maxWindKt else { return nil }
            return (p.time, w)
        }

        if windPoints.count >= 2 {
            let wFirst = windPoints.first!
            let wLast = windPoints.last!
            let wHours = wLast.0.timeIntervalSince(wFirst.0) / 3600.0
            if wHours > 2.0 {
                let dWindKt = wLast.1 - wFirst.1
                let dWindPerDay = (dWindKt / wHours) * 24.0
                let weakeningPerDay = max(0.0, -dWindPerDay)
                if weakeningPerDay > 8.0 {
                    let windBoost = min(0.05, (weakeningPerDay - 8.0) * 0.0028)
                    rate += windBoost
                }
            }
        }

        return max(0.04, min(0.16, rate))
    }

    // MARK: - Arrival Time Estimation

    /// 指定 knots（34/50/64）の風速域に到達する時刻を推定。風速半径＋減衰モデルを使う。
    static func estimateArrival(
        location: SavedLocation,
        typhoon: Typhoon,
        targetKnots: Int,
        now: Date = Date()
    ) -> RiskAssessment.ArrivalInfo? {
        let userCoord = CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
        let decayRatePerDay = computeDynamicDecayRate(for: typhoon, now: now)

        // 1. 現在位置で既に target knots の風域内なら hours=0
        if let r = radiusForKnots(typhoon.windRadii, targetKnots: targetKnots) {
            let d = distanceKm(from: userCoord, to: typhoon.currentCenter.clLocation)
            if d <= r {
                return RiskAssessment.ArrivalInfo(time: ISO8601DateFormatter().string(from: now), hours: 0)
            }
        }

        // 2. 予報ポイントごとに減衰を適用してタイムラインを構築
        let iso = ISO8601DateFormatter()
        var timeline: [(time: Date, center: Coordinate, radiusKm: Double?)] = [
            (now, typhoon.currentCenter, radiusForKnots(typhoon.windRadii, targetKnots: targetKnots))
        ]
        for fp in typhoon.forecasts {
            guard let date = iso.date(from: fp.validTime) else { continue }
            var r = radiusForKnots(fp.windRadii, targetKnots: targetKnots)
            if let r0 = r {
                let hoursSinceNow = date.timeIntervalSince(now) / 3600
                let decay = max(0.4, 1.0 - decayRatePerDay * (hoursSinceNow / 24.0))
                r = r0 * decay
            }
            timeline.append((date, fp.center, r))
        }
        timeline.sort { $0.time < $1.time }

        var previous: (time: Date, center: Coordinate, radiusKm: Double)?
        for point in timeline {
            guard let radiusKm = point.radiusKm else { continue }
            let dist = distanceKm(from: userCoord, to: point.center.clLocation)

            if dist <= radiusKm {
                if let prev = previous {
                    let prevDist = distanceKm(from: userCoord, to: prev.center.clLocation)
                    let prevExcess = max(0, prevDist - prev.radiusKm)
                    let currExcess = max(0, dist - radiusKm)

                    var ratio = 0.5
                    let total = prevExcess + currExcess
                    if total > 0 { ratio = prevExcess / total }

                    let timeDelta = point.time.timeIntervalSince(prev.time)
                    let interpolatedTime = prev.time.timeIntervalSince1970 + timeDelta * ratio
                    let hours = (interpolatedTime - now.timeIntervalSince1970) / 3600

                    if hours > 0 {
                        let arrivalDate = Date(timeIntervalSince1970: interpolatedTime)
                        return RiskAssessment.ArrivalInfo(
                            time: iso.string(from: arrivalDate),
                            hours: hours
                        )
                    }
                }
                let hours = max(0, point.time.timeIntervalSince(now) / 3600)
                return RiskAssessment.ArrivalInfo(time: iso.string(from: point.time), hours: hours)
            }
            previous = (point.time, point.center, radiusKm)
        }

        // 3. fallback: 最後の予報時点の風域距離 + 台風速度から推定
        if let lastPoint = timeline.last,
           let lastRadius = lastPoint.radiusKm,
           let speedKmh = typhoon.speed,
           speedKmh > 1
        {
            let lastDist = distanceKm(from: userCoord, to: lastPoint.center.clLocation)
            if lastDist > lastRadius {
                let excessKm = lastDist - lastRadius
                let hours = excessKm / speedKmh
                if hours > 0 {
                    let arrivalTime = lastPoint.time.addingTimeInterval(hours * 3600)
                    return RiskAssessment.ArrivalInfo(
                        time: iso.string(from: arrivalTime),
                        hours: arrivalTime.timeIntervalSince(now) / 3600
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Risk Level

    /// 到達時間からリスクレベルを決定（backend の determineRiskLevelFromWindArrival と同じロジック）
    static func determineRiskLevel(hours34: Double?, hours50: Double?, hours64: Double?) -> String {
        if let h64 = hours64, h64 < 12 { return "SEVERE" }
        if let h50 = hours50, h50 < 12 { return "HIGH" }
        if let h34 = hours34, h34 < 12 { return "HIGH" }
        if let h34 = hours34, h34 < 24 { return "MEDIUM" }
        if hours34 != nil { return "LOW" }
        return "LOW"
    }

    // MARK: - Helpers

    static func radiusForKnots(_ windRadii: WindRadii?, targetKnots: Int) -> Double? {
        guard let r = windRadii else { return nil }
        switch targetKnots {
        case 34: return r.radius34kt
        case 50: return r.radius50kt
        case 64: return r.radius64kt
        default: return nil
        }
    }

    static func distanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2) / 1000.0
    }

    private static func findClosestApproach(location: SavedLocation, typhoon: Typhoon) -> (distanceKm: Double?, time: String?) {
        let userCoord = CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon)
        var minDist = distanceKm(from: userCoord, to: typhoon.currentCenter.clLocation)
        var closestTime: String? = nil
        for fp in typhoon.forecasts {
            let d = distanceKm(from: userCoord, to: fp.center.clLocation)
            if d < minDist {
                minDist = d
                closestTime = fp.validTime
            }
        }
        return (minDist, closestTime)
    }
}
