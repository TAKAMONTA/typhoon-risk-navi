import type { Typhoon } from '../../types/typhoon';
import type { TyphoonDataSource, DataSourceMetadata } from './types';
import { parseJTWCWarnings } from './JTWCParser';

/**
 * 米軍 JTWC (Joint Typhoon Warning Center) からのデータ取得
 */
export class JTWCSource implements TyphoonDataSource {
  readonly metadata: DataSourceMetadata = {
    name: 'JTWC',
    priority: 100,
    description: 'Joint Typhoon Warning Center (US Military) - Western Pacific',
    supportsForecastCone: true,
    supportsWindRadii: true,
    supportsIntensityForecast: true,
    typicalUpdateIntervalMinutes: 360, // 通常6時間ごと
  };

  private readonly baseUrl = 'https://www.metoc.navy.mil/jtwc/products';

  async fetchActiveTyphoons(): Promise<Typhoon[]> {
    try {
      // 注意: 2026年現在、JTWCの直接ファイルアクセスは制限されていることが多い。
      const response = await fetch(`${this.baseUrl}/wpacprod.txt`, {
        signal: AbortSignal.timeout(10000),
      });

      if (!response.ok) {
        console.warn(`[JTWC] Fetch failed with status ${response.status}`);
        return [];
      }

      const text = await response.text();
      return parseJTWCWarnings(text);
    } catch (error) {
      console.error('[JTWC] Data fetch error:', error);
      return [];
    }
  }
}



