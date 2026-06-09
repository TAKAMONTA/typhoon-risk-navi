import { test, expect, describe } from 'bun:test';
import { RiskCalculationService } from './RiskCalculationService';
import type { Typhoon } from '../../../types/typhoon';

// 那覇市（地図上の代表地点）
const NAHA = { id: 'loc-naha', name: '那覇市', lat: 26.21, lon: 127.68 };

/** デモ用ベース台風（那覇の少し南、北上中、強風域たっぷり） */
function baseTyphoon(overrides: Partial<Typhoon> = {}): Typhoon {
  return {
    id: 'T-test',
    name: 'TESTSTORM',
    source: 'JTWC',
    status: 'ACTIVE',
    currentCenter: { lat: 22.5, lon: 126.5 },
    maxWindSpeed: 43.7, // m/s ≒ 85kt
    centralPressure: 950,
    direction: 340,
    speed: 20, // km/h
    windRadii: {
      radius34kt: 290,
      radius50kt: 115,
      radius64kt: 60,
    } as any,
    forecasts: [
      { validTime: new Date(Date.now() + 6 * 3600_000).toISOString(),  center: { lat: 24.2, lon: 126.8 }, windRadii: { radius34kt: 270, radius50kt: 100, radius64kt: 50 } as any, maxWindSpeed: 41 },
      { validTime: new Date(Date.now() + 18 * 3600_000).toISOString(), center: { lat: 25.4, lon: 127.0 }, windRadii: { radius34kt: 230, radius50kt: 80,  radius64kt: 35 } as any, maxWindSpeed: 37 },
      { validTime: new Date(Date.now() + 30 * 3600_000).toISOString(), center: { lat: 26.3, lon: 127.5 }, windRadii: { radius34kt: 190, radius50kt: 55,  radius64kt: 20 } as any, maxWindSpeed: 32 },
      { validTime: new Date(Date.now() + 42 * 3600_000).toISOString(), center: { lat: 27.8, lon: 128.8 }, windRadii: { radius34kt: 130, radius50kt: 35,  radius64kt: 0  } as any, maxWindSpeed: 27 },
    ],
    lastUpdated: new Date().toISOString(),
    ...overrides,
  };
}

describe('RiskCalculationService', () => {
  const service = new RiskCalculationService();

  test('未来に強風域が那覇を覆うので arrival34kt が定義される', () => {
    const t = baseTyphoon();
    const risks = service.calculateRisksForLocations([NAHA], [t]);

    expect(risks).toHaveLength(1);
    const r = risks[0]!;
    expect(r.locationName).toBe('那覇市');
    expect(r.typhoonName).toBe('TESTSTORM');
    expect(r.arrival34kt).toBeDefined();
    expect(r.arrival34kt!.hours).toBeGreaterThanOrEqual(0);
    expect(r.arrival34kt!.hours).toBeLessThan(48);
  });

  test('riskLevel は到達時間に応じて段階的に決まる', () => {
    const t = baseTyphoon();
    const r = service.calculateRiskForLocation(NAHA, t);
    expect(['LOW', 'MEDIUM', 'HIGH', 'SEVERE']).toContain(r.riskLevel);
  });

  test('遠方の地点（東京）は LOW のまま', () => {
    const tokyo = { id: 'loc-tokyo', name: '東京', lat: 35.68, lon: 139.77 };
    const r = service.calculateRiskForLocation(tokyo, baseTyphoon());

    expect(r.riskLevel).toBe('LOW');
    expect(r.currentDistanceKm).toBeGreaterThan(1500);
  });

  test('現在位置の距離が正しく計算される（那覇 vs 台風中心）', () => {
    const r = service.calculateRiskForLocation(NAHA, baseTyphoon());
    // 那覇 (26.21,127.68) ↔ 台風 (22.5,126.5) ≒ 425km 前後
    expect(r.currentDistanceKm).toBeGreaterThan(380);
    expect(r.currentDistanceKm).toBeLessThan(470);
  });

  test('quadrant 形式 (JTWC生データ風) の windRadii からも到達時間が計算できる', () => {
    const t = baseTyphoon({
      windRadii: {
        '034': { NE: 160, SE: 160, SW: 160, NW: 160 }, // NM (≒ 296km)
        '050': { NE: 62,  SE: 62,  SW: 62,  NW: 62  },
        '064': { NE: 32,  SE: 32,  SW: 32,  NW: 32  },
      } as any,
      forecasts: [
        {
          validTime: new Date(Date.now() + 12 * 3600_000).toISOString(),
          center: { lat: 25.0, lon: 127.0 },
          windRadii: {
            '034': { NE: 140, SE: 140, SW: 140, NW: 140 },
            '050': { NE: 50,  SE: 50,  SW: 50,  NW: 50 },
          } as any,
        },
      ],
    });

    const r = service.calculateRiskForLocation(NAHA, t);
    expect(r.arrival34kt).toBeDefined();
  });

  test('動的減衰率は 4%〜16%/日 の範囲にクランプされる', () => {
    const service = new RiskCalculationService();
    const compute = (service as any).computeDynamicDecayRate.bind(service);

    // 超急速に北上＋急速弱体化 → クランプ上限 16% 以下
    const fastNorth = baseTyphoon({
      currentCenter: { lat: 18, lon: 130 },
      maxWindSpeed: 50,
      forecasts: [
        { validTime: new Date(Date.now() + 12 * 3600_000).toISOString(), center: { lat: 28, lon: 132 }, maxWindSpeed: 25 },
        { validTime: new Date(Date.now() + 24 * 3600_000).toISOString(), center: { lat: 36, lon: 138 }, maxWindSpeed: 15 },
      ],
    });
    expect(compute(fastNorth)).toBeLessThanOrEqual(0.16);
    expect(compute(fastNorth)).toBeGreaterThanOrEqual(0.04);

    // ほぼ停滞して強い台風 → クランプ下限 4% 以上
    const stalled = baseTyphoon({
      currentCenter: { lat: 22, lon: 130 },
      maxWindSpeed: 50,
      forecasts: [
        { validTime: new Date(Date.now() + 24 * 3600_000).toISOString(), center: { lat: 22.1, lon: 130.1 }, maxWindSpeed: 50 },
      ],
    });
    expect(compute(stalled)).toBeGreaterThanOrEqual(0.04);
    expect(compute(stalled)).toBeLessThanOrEqual(0.16);
  });

  test('typhoons が空のときは空配列を返す', () => {
    const result = service.calculateRisksForLocations([NAHA], []);
    expect(result).toEqual([]);
  });

  test('最も強い台風が primary として選ばれる', () => {
    const weak = baseTyphoon({ id: 'WEAK', name: 'WEAK', maxWindSpeed: 20 });
    const strong = baseTyphoon({ id: 'STRONG', name: 'STRONG', maxWindSpeed: 50 });

    const result = service.calculateRisksForLocations([NAHA], [weak, strong]);
    expect(result[0]!.typhoonName).toBe('STRONG');
  });

  test('flat と quadrant が混在しても破綻しない（forecast に flat のみ）', () => {
    const t = baseTyphoon({
      windRadii: {
        '034': { NE: 150, SE: 150, SW: 150, NW: 150 },
      } as any,
      forecasts: [
        {
          validTime: new Date(Date.now() + 12 * 3600_000).toISOString(),
          center: { lat: 26.0, lon: 127.5 },
          windRadii: { radius34kt: 200 } as any,
        },
      ],
    });

    expect(() => service.calculateRiskForLocation(NAHA, t)).not.toThrow();
  });
});
