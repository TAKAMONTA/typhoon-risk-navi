import type { Typhoon, ForecastPoint } from '../../types/typhoon';

/**
 * JTWCなどから来た quadrant 形式の windRadii を、
 * iOSクライアントが扱いやすい flat 形式（km単位）に変換して付与する。
 * 内部計算（リスク）は quadrant のまま残す。
 */
export function toClientFriendly(typhoon: Typhoon): Typhoon & { windRadiiFlat?: any } {
  const flat = convertQuadrantToFlat(typhoon.windRadii);
  const flatForecasts = typhoon.forecasts?.map((f: ForecastPoint) => ({
    ...f,
    windRadiiFlat: convertQuadrantToFlat(f.windRadii),
  })) ?? [];

  return {
    ...typhoon,
    // 元の quadrant 形式は保持（リスク計算など内部用）
    windRadii: typhoon.windRadii,
    // クライアント（iOSなど）向けの flat 形式を追加
    windRadiiFlat: flat,
    forecasts: flatForecasts,
  };
}

function convertQuadrantToFlat(wr: any): any {
  if (!wr) return undefined;

  // すでに flat 形式ならそのまま
  if (wr.radius34kt !== undefined || wr.radius50kt !== undefined) {
    return wr;
  }

  const getMax = (band: string) => {
    const q = wr[band] || wr[band.padStart(3, '0')];
    if (!q) return undefined;
    return Math.max(q.NE || 0, q.SE || 0, q.SW || 0, q.NW || 0) * 1.852; // NM → km
  };

  const result: any = {};
  const r34 = getMax('034') ?? getMax('34');
  const r50 = getMax('050') ?? getMax('50');
  const r64 = getMax('064') ?? getMax('64');

  if (r34 !== undefined) result.radius34kt = r34;
  if (r50 !== undefined) result.radius50kt = r50;
  if (r64 !== undefined) result.radius64kt = r64;

  return Object.keys(result).length > 0 ? result : undefined;
}
