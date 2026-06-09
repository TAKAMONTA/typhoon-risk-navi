import type { Typhoon } from '../../types/typhoon';
import type { TyphoonDataSource, DataSourceMetadata } from './types';
import { fetchAndParseJMA } from './JMAParser';

/**
 * 気象庁（JMA）からの台風データ取得
 */
export class JMASource implements TyphoonDataSource {
  readonly metadata: DataSourceMetadata = {
    name: 'JMA',
    priority: 90,
    description: 'Japan Meteorological Agency (RSMC Tokyo) - 公式台風情報',
    supportsForecastCone: true,
    supportsWindRadii: true, // 改善中：強風域・暴風域の抽出を強化中
    supportsIntensityForecast: true,
    typicalUpdateIntervalMinutes: 180,
  };

  async fetchActiveTyphoons(): Promise<Typhoon[]> {
    return fetchAndParseJMA();
  }
}



