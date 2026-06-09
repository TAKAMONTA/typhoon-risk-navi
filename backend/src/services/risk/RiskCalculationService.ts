import type { Typhoon, ForecastPoint, TyphoonPosition } from '../../../types/typhoon';

export interface RiskAssessment {
  locationId: string;
  locationName: string;
  typhoonId: string;
  typhoonName: string;

  // 風速別到達時間（最も重要な情報）
  arrival34kt?: { time: string; hours: number };
  arrival50kt?: { time: string; hours: number };
  arrival64kt?: { time: string; hours: number };

  // 台風中心の最接近情報
  estimatedClosestApproach?: string;
  distanceToClosestKm?: number;

  currentDistanceKm: number;

  riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' | 'SEVERE';
  source: string;
  calculatedAt: string;

  notes?: string[];
}

/**
 * リスク計算サービス
 * 将来的にここにAIモデルを組み込む
 */
export class RiskCalculationService {
  // 風速閾値（ノット）
  private readonly STRONG_WIND_KT = 34;   // 強風域の目安
  private readonly VERY_STRONG_WIND_KT = 50;
  private readonly VIOLENT_WIND_KT = 64;

  /**
   * 単一の保存場所に対するリスクを計算（改善版）
   */
  calculateRiskForLocation(
    location: { id: string; name: string; lat: number; lon: number },
    typhoon: Typhoon
  ): RiskAssessment {
    const now = new Date().toISOString();

    const currentDistance = this.calculateDistanceKm(
      location.lat, location.lon,
      typhoon.currentCenter.lat, typhoon.currentCenter.lon
    );

    // 1. 予報トラック全体から最接近ポイントを探す
    const closest = this.findClosestPointOnTrack(location, typhoon);

    // 2. 風速別到達時間を計算（本気版）
    const arrival34kt = this.estimateArrivalToWindSpeed(location, typhoon, this.STRONG_WIND_KT);
    const arrival50kt = this.estimateArrivalToWindSpeed(location, typhoon, this.VERY_STRONG_WIND_KT);
    const arrival64kt = this.estimateArrivalToWindSpeed(location, typhoon, this.VIOLENT_WIND_KT);

    // 3. リスクレベル判定（風速別到達時間ベース）
    const riskLevel = this.determineRiskLevelFromWindArrival(
      arrival34kt?.hours,
      arrival50kt?.hours,
      arrival64kt?.hours
    );

    return {
      locationId: location.id,
      locationName: location.name,
      typhoonId: typhoon.id,
      typhoonName: typhoon.name,
      arrival34kt: arrival34kt ? { time: arrival34kt.time, hours: arrival34kt.hours } : undefined,
      arrival50kt: arrival50kt ? { time: arrival50kt.time, hours: arrival50kt.hours } : undefined,
      arrival64kt: arrival64kt ? { time: arrival64kt.time, hours: arrival64kt.hours } : undefined,
      estimatedClosestApproach: closest.time,
      distanceToClosestKm: Math.round(closest.distanceKm),
      currentDistanceKm: Math.round(currentDistance),
      riskLevel,
      source: typhoon.source,
      calculatedAt: now,
      notes: this.generateNotesAdvanced(typhoon, arrival34kt, arrival50kt, arrival64kt),
    };
  }

  /**
   * 複数の保存場所に対するリスクを一括計算
   */
  calculateRisksForLocations(
    locations: Array<{ id: string; name: string; lat: number; lon: number }>,
    typhoons: Typhoon[]
  ): RiskAssessment[] {
    if (typhoons.length === 0) return [];

    // 最も影響が大きそうな台風を1つ選ぶ（風速が最も強いものを優先）
    const primaryTyphoon = typhoons.reduce((prev, current) =>
      (current.maxWindSpeed || 0) > (prev.maxWindSpeed || 0) ? current : prev
    );

    return locations.map(loc => 
      this.calculateRiskForLocation(loc, primaryTyphoon)
    );
  }

  // --- 以下ヘルパーメソッド ---

  /**
   * 予報トラック上でユーザーの場所に最も近いポイントを探す
   */
  private findClosestPointOnTrack(
    location: { lat: number; lon: number },
    typhoon: Typhoon
  ): { distanceKm: number; time?: string } {
    let minDist = this.calculateDistanceKm(
      location.lat, location.lon,
      typhoon.currentCenter.lat, typhoon.currentCenter.lon
    );
    let closestTime: string | undefined;

    const allPoints: Array<{ point: ForecastPoint | { validTime?: string; center: any } }> = [
      { point: { validTime: undefined, center: typhoon.currentCenter } },
      ...typhoon.forecasts.map((f: ForecastPoint) => ({ point: f }))
    ];

    for (const item of allPoints) {
      const dist = this.calculateDistanceKm(
        location.lat, location.lon,
        item.point.center.lat, item.point.center.lon
      );
      if (dist < minDist) {
        minDist = dist;
        closestTime = (item.point as ForecastPoint).validTime;
      }
    }

    return {
      distanceKm: Math.round(minDist),
      time: closestTime,
    };
  }

  /**
   * 風速半径を考慮した到達時間推定（本気版）
   * 優先的にJTWCなどの風速半径データを使う
   */
  private estimateArrivalToWindSpeed(
    location: { lat: number; lon: number },
    typhoon: Typhoon,
    targetKnots: number
  ): { hours: number; time: string; expectedWindKt?: number } | undefined {
    const now = Date.now();

    // 動的減衰率を台風データから算出（クライアントと完全同期）
    const decayRatePerDay = this.computeDynamicDecayRate(typhoon);

    // 1. まず現在の風速半径で判定（targetKnots に対応したバンドでチェック）
    const currentRadius = this.getWindRadiusAtPoint(typhoon.windRadii, typhoon.currentCenter, location, targetKnots);
    if (currentRadius != null) {
      return { hours: 0, time: new Date().toISOString(), expectedWindKt: typhoon.maxWindSpeed ? typhoon.maxWindSpeed / 0.51444 : undefined };
    }

    // 2. 予報ポイントを順番に見て、初めてtargetKnots以上の風速半径に入るポイントを探す
    //    未来ポイントには時間減衰を適用（台風の北上・弱体化を反映）
    const trackPoints = [
      { time: now, center: typhoon.currentCenter, windRadii: typhoon.windRadii, maxWindKt: typhoon.maxWindSpeed ? typhoon.maxWindSpeed / 0.51444 : 0 },
      ...typhoon.forecasts.map((f: ForecastPoint) => ({
        time: new Date(f.validTime).getTime(),
        center: f.center,
        windRadii: f.windRadii,
        maxWindKt: f.maxWindSpeed ? f.maxWindSpeed / 0.51444 : 0,
      }))
    ];

    for (let i = 1; i < trackPoints.length; i++) {
      const prev = trackPoints[i - 1];
      const curr = trackPoints[i];

      const hoursPrev = Math.max(0, (prev.time - now) / (1000 * 3600));
      const hoursCurr = Math.max(0, (curr.time - now) / (1000 * 3600));

      // 減衰適用版で半径を取得（未来ほど小さくなる）
      const prevRadius = this.getDecayedWindRadiusAtPoint(prev.windRadii, prev.center, location, targetKnots, hoursPrev, decayRatePerDay);
      const currRadius = this.getDecayedWindRadiusAtPoint(curr.windRadii, curr.center, location, targetKnots, hoursCurr, decayRatePerDay);

      const prevHasWind = prevRadius !== null && prevRadius >= targetKnots;
      const currHasWind = currRadius !== null && currRadius >= targetKnots;

      if (!prevHasWind && currHasWind) {
        // この区間でtargetKnotsの風に入った
        const ratio = this.calculateEntryRatio(prev, curr, location, targetKnots, decayRatePerDay, hoursPrev, hoursCurr);
        const interpolatedTime = prev.time + (curr.time - prev.time) * ratio;
        const hours = (interpolatedTime - now) / (1000 * 3600);

        return {
          hours: Math.max(0, hours),
          time: new Date(interpolatedTime).toISOString(),
          expectedWindKt: Math.max(prev.maxWindKt, curr.maxWindKt),
        };
      }
    }

    // 3. 予報内で入らなかった場合、最後のポイントの風速で簡易推定（targetKnots 対応）
    const last = trackPoints[trackPoints.length - 1]!;
    if (last.maxWindKt >= targetKnots) {
      const hoursLast = Math.max(0, (last.time - now) / (1000 * 3600));
      const lastRadius = this.getDecayedWindRadiusAtPoint(last.windRadii, last.center, location, targetKnots, hoursLast, decayRatePerDay) || 0;
      const distance = this.calculateDistanceKm(location.lat, location.lon, last.center.lat, last.center.lon);
      if (typhoon.speed && typhoon.speed > 0 && lastRadius < targetKnots) {
        const hours = (distance - lastRadius) / typhoon.speed;
        return {
          hours: Math.max(0, hours),
          time: new Date(last.time + hours * 3600 * 1000).toISOString(),
          expectedWindKt: last.maxWindKt,
        };
      }
    }

    return undefined;
  }

  /**
   * prev → curr の間で、targetKnots の風速域に地点が入る時刻の補間比率 (0〜1) を返す。
   * 風速半径データがある場合の線形近似（時間減衰対応版）。
   */
  private calculateEntryRatio(
    prev: { center: TyphoonPosition; windRadii?: any },
    curr: { center: TyphoonPosition; windRadii?: any },
    location: { lat: number; lon: number },
    targetKnots: number,
    decayRatePerDay = 0.08,
    hoursPrev = 0,
    hoursCurr = 0
  ): number {
    const dPrev = this.calculateDistanceKm(location.lat, location.lon, prev.center.lat, prev.center.lon);
    const dCurr = this.calculateDistanceKm(location.lat, location.lon, curr.center.lat, curr.center.lon);

    // 減衰を考慮した有効半径で excess を計算（クライアントと同期）
    const rPrev = this.getDecayedWindRadiusAtPoint(prev.windRadii, prev.center, location, targetKnots, hoursPrev, decayRatePerDay) || 0;
    const rCurr = this.getDecayedWindRadiusAtPoint(curr.windRadii, curr.center, location, targetKnots, hoursCurr, decayRatePerDay) || 0;

    const excessPrev = dPrev - rPrev;
    const excessCurr = dCurr - rCurr;

    if (excessPrev <= 0) return 0;
    if (excessCurr <= 0) return 1;

    const total = excessPrev - excessCurr;
    if (total <= 0) return 0.5;

    return Math.min(1, Math.max(0, excessPrev / total));
  }

  /**
   * 指定地点における風速半径を推定（簡易）
   * flat 形式（radius34kt など、km単位）と quadrant 形式（JTWC生データ）の両方をサポート。
   */
  private getWindRadiusAtPoint(
    windRadii: any,
    center: TyphoonPosition,
    location: { lat: number; lon: number },
    targetKnots?: number
  ): number | null {
    if (!windRadii) return null;

    const distance = this.calculateDistanceKm(location.lat, location.lon, center.lat, center.lon);

    // --- Flat format (demo + iOS で現在採用): { radius34kt, radius50kt, radius64kt } in km ---
    if (
      typeof windRadii.radius34kt === 'number' ||
      typeof windRadii.radius50kt === 'number' ||
      typeof windRadii.radius64kt === 'number'
    ) {
      let r: number | undefined;
      if (targetKnots === 34) r = windRadii.radius34kt;
      else if (targetKnots === 50) r = windRadii.radius50kt;
      else if (targetKnots === 64) r = windRadii.radius64kt;
      else r = Math.max(windRadii.radius34kt || 0, windRadii.radius50kt || 0, windRadii.radius64kt || 0);

      if (typeof r === 'number' && distance <= r) return r;
      return null;
    }

    // --- Quadrant format (JTWC実データ): { "034": {NE,SE,SW,NW}, ... } in NM ---
    // 実データでは予報ごとにバンドが揃っていないことが多いので、targetKnots を尊重しつつ柔軟に扱う
    if (targetKnots) {
      const bandKey = String(targetKnots).padStart(3, '0');
      const q = windRadii[bandKey] || windRadii[String(targetKnots)];
      if (q) {
        const rNm = Math.max(q.NE || 0, q.SE || 0, q.SW || 0, q.NW || 0);
        if (rNm > 0) {
          const rKm = rNm * 1.852;
          return distance <= rKm ? rKm : null;
        }
      }
      // 該当バンドがその予報にない場合（台風が弱まっているケースなど）は、
      // 利用可能な最も強いバンドの半径を保守的に使う
      const availableBands = Object.keys(windRadii)
        .map(k => parseInt(k))
        .filter(n => !isNaN(n))
        .sort((a, b) => b - a); // 強い順

      for (const band of availableBands) {
        if (band >= targetKnots) {
          const q2 = windRadii[String(band).padStart(3, '0')] || windRadii[String(band)];
          if (q2) {
            const rNm = Math.max(q2.NE || 0, q2.SE || 0, q2.SW || 0, q2.NW || 0);
            if (rNm > 0) {
              const rKm = rNm * 1.852;
              return distance <= rKm ? rKm : null;
            }
          }
        }
      }
    }

    // バンド指定なし、または該当なし → 利用可能な最大半径で判定（フォールバック）
    let maxRadiusNm = 0;
    for (const knots in windRadii) {
      const r = windRadii[knots];
      const maxInQuadrant = Math.max(r?.NE || 0, r?.SE || 0, r?.SW || 0, r?.NW || 0);
      if (maxInQuadrant > maxRadiusNm) maxRadiusNm = maxInQuadrant;
    }
    if (maxRadiusNm <= 0) return null;

    const maxRadiusKm = maxRadiusNm * 1.852;
    return distance <= maxRadiusKm ? maxRadiusKm : null;
  }

  private determineRiskLevelFromWindArrival(
    hours34kt?: number,
    hours50kt?: number,
    hours64kt?: number
  ): RiskAssessment['riskLevel'] {
    if (hours64kt !== undefined && hours64kt < 12) return 'SEVERE';
    if (hours50kt !== undefined && hours50kt < 12) return 'HIGH';
    if (hours34kt !== undefined && hours34kt < 12) return 'HIGH';
    if (hours34kt !== undefined && hours34kt < 24) return 'MEDIUM';
    if (hours34kt !== undefined) return 'LOW';

    return 'LOW';
  }

  private generateNotesAdvanced(
    typhoon: Typhoon,
    arrival34?: any,
    arrival50?: any,
    arrival64?: any
  ): string[] {
    const notes: string[] = [];

    if (arrival64?.hours !== undefined && arrival64.hours < 12) {
      notes.push('非常に強い風が短時間で到達する可能性があります。');
    } else if (arrival50?.hours !== undefined && arrival50.hours < 12) {
      notes.push('強い風が短時間で到達する可能性があります。早めの備えを。');
    } else if (arrival34?.hours !== undefined && arrival34.hours < 6) {
      notes.push('強風域が非常に近くまで迫っています。');
    }

    if (typhoon.source === 'JTWC') {
      notes.push('米軍JTWCの予報に基づく推定です。');
    } else if (typhoon.source === 'JMA') {
      notes.push('気象庁の予報に基づく推定です。');
    } else if (typhoon.source === 'COMBINED') {
      notes.push('複数の情報源を統合した推定です。');
    }

    // 精度モデルの情報を技術ノートとして追加（クライアントと同一ロジック）
    const decay = this.computeDynamicDecayRate(typhoon);
    notes.push(`精度モデル: ${(decay * 100).toFixed(1)}%（緯度・風速トレンドベース）`);

    return notes;
  }

  private calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * 減衰率を台風自身の予報データから動的に算出（クライアント側と完全同期）
   * - 緯度進行（北上）：北緯18°以上で北上する台風は風速半径の縮小が加速
   * - 最大風速の減少率：実測で急激に弱っている台風は半径も早く縮む
   * 結果は 4%〜16%/日 の範囲にクランプ（クライアント Swift 実装と同一ロジック）
   * UI/APIでは「精度モデル XX%」として表示
   */
  private computeDynamicDecayRate(typhoon: Typhoon): number {
    let rate = 0.08;

    const points: Array<{ time: number; lat: number; maxWindKt?: number }> = [];

    // 現在位置
    points.push({
      time: Date.now(),
      lat: typhoon.currentCenter.lat,
      maxWindKt: typhoon.maxWindSpeed ? typhoon.maxWindSpeed / 0.51444 : undefined,
    });

    // 予報ポイント
    for (const fp of typhoon.forecasts) {
      const t = new Date(fp.validTime).getTime();
      if (isNaN(t)) continue;
      points.push({
        time: t,
        lat: fp.center.lat,
        maxWindKt: fp.maxWindSpeed ? fp.maxWindSpeed / 0.51444 : undefined,
      });
    }

    if (points.length < 2) return rate;

    const first = points[0]!;
    const last = points[points.length - 1]!;
    const timeSpanHours = (last.time - first.time) / (1000 * 3600);

    // 1. 緯度進行（北西太平洋で北上する台風の典型的な弱体化パターン）
    if (timeSpanHours > 3) {
      const dLat = last.lat - first.lat;
      const dLatPerDay = dLat * (24 / timeSpanHours);
      const avgLat = (first.lat + last.lat) / 2;

      if (dLatPerDay > 1.2 && avgLat > 18) {
        const latBoost = Math.min(0.045, (dLatPerDay - 1.2) * 0.018);
        rate += latBoost;
      }
      if (avgLat > 30) {
        rate += 0.025;
      }
    }

    // 2. 最大風速の減少トレンド
    const windPoints = points
      .filter(p => typeof p.maxWindKt === 'number')
      .map(p => ({ time: p.time, wind: p.maxWindKt as number }));

    if (windPoints.length >= 2) {
      const wFirst = windPoints[0]!;
      const wLast = windPoints[windPoints.length - 1]!;
      const wHours = (wLast.time - wFirst.time) / (1000 * 3600);

      if (wHours > 2) {
        const dWindKt = wLast.wind - wFirst.wind; // 負 = 弱体化
        const dWindPerDay = (dWindKt / wHours) * 24;
        const weakeningPerDay = Math.max(0, -dWindPerDay);

        if (weakeningPerDay > 8) {
          const windBoost = Math.min(0.05, (weakeningPerDay - 8) * 0.0028);
          rate += windBoost;
        }
      }
    }

    return Math.max(0.04, Math.min(0.16, rate));
  }

  /**
   * 時間減衰を適用した有効風速半径を返す（クライアント側と同一の減衰モデル）
   */
  private getDecayedWindRadiusAtPoint(
    windRadii: any,
    center: TyphoonPosition,
    location: { lat: number; lon: number },
    targetKnots: number,
    hoursSinceNow: number,
    decayRatePerDay: number
  ): number | null {
    const base = this.getWindRadiusAtPoint(windRadii, center, location, targetKnots);
    if (base == null || hoursSinceNow <= 0) return base;

    const decayFactor = Math.max(0.4, 1.0 - decayRatePerDay * (hoursSinceNow / 24.0));
    return base * decayFactor;
  }
}
