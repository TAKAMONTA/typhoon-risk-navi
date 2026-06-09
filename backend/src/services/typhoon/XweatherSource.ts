import type { Typhoon, TyphoonPosition, ForecastPoint } from '../../../types/typhoon';
import type { TyphoonDataSource, DataSourceMetadata } from './types';

/**
 * Xweather (旧 AerisWeather) を利用した信頼性の高い台風データソース
 * 
 * Western Pacific (WP basin) の台風データが安定して取得可能。
 * JTWCの公式データを構造化して提供してくれるため、非常に有用。
 * 
 * ドキュメント: https://www.xweather.com/docs/weather-api/endpoints/tropicalcyclones
 */
export class XweatherSource implements TyphoonDataSource {
  readonly metadata: DataSourceMetadata = {
    name: 'Xweather',
    priority: 200, // 最優先（信頼性が高いため）
    description: 'Xweather (AerisWeather) - Reliable commercial tropical cyclone data',
    supportsForecastCone: true,
    supportsWindRadii: true,
    supportsIntensityForecast: true,
    typicalUpdateIntervalMinutes: 360, // 6時間ごと（脅威時はより頻繁）
  };

  private readonly apiKey: string | undefined;
  private readonly clientId: string | undefined;
  private readonly baseUrl = 'https://data.api.xweather.com';

  constructor() {
    // 環境変数から取得（本番では適切に管理）
    this.apiKey = process.env.XWEATHER_API_KEY;
    this.clientId = process.env.XWEATHER_CLIENT_ID;
  }

  async fetchActiveTyphoons(): Promise<Typhoon[]> {
    if (!this.apiKey && !this.clientId) {
      console.warn('[Xweather] API credentials not configured. Skipping.');
      return [];
    }

    try {
      // Western Pacific (WP) basinのアクティブな熱帯低気圧を取得
      // 実際のエンドポイントは要確認（/tropicalcyclones など）
      const url = `${this.baseUrl}/tropicalcyclones?filter=basin=wp&limit=10`;
      
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
      };

      // 認証方式はXweatherの仕様による（client_id + client_secret または api_key）
      if (this.clientId) {
        headers['x-client-id'] = this.clientId;
      }
      if (this.apiKey) {
        headers['x-api-key'] = this.apiKey;
      }

      const response = await fetch(url, {
        headers,
        signal: AbortSignal.timeout(15000),
      });

      if (!response.ok) {
        console.warn(`[Xweather] Fetch failed: ${response.status}`);
        return [];
      }

      const json = await response.json();
      return this.normalizeXweatherData(json);
    } catch (error) {
      console.error('[Xweather] Error fetching data:', error);
      return [];
    }
  }

  /**
   * Xweatherのレスポンスをアプリの内部Typhoonモデルに正規化
   */
  private normalizeXweatherData(raw: any): Typhoon[] {
    // Xweatherの実際のレスポンス構造に合わせて実装する必要がある
    // ここは仮実装（ドキュメント確認後に本実装）
    if (!raw || !Array.isArray(raw)) {
      return [];
    }

    return raw.map((item: any) => {
      // 仮のマッピング（実際のレスポンスに合わせて調整）
      return {
        id: `XW-${item.id || item.name}`,
        name: item.name || 'Unknown',
        source: 'XWEATHER' as const,
        status: this.mapStatus(item.status),
        currentCenter: {
          lat: item.position?.lat || 0,
          lon: item.position?.lon || 0,
        },
        maxWindSpeed: item.windSpeedKts ? item.windSpeedKts * 0.51444 : undefined,
        centralPressure: item.pressureMb,
        direction: item.movement?.direction,
        speed: item.movement?.speedKts ? item.movement.speedKts * 1.852 : undefined,
        forecasts: this.normalizeForecasts(item.forecast),
        lastUpdated: new Date().toISOString(),
        rawSources: {
          xweather: item,
        },
      } as Typhoon;
    });
  }

  private normalizeForecasts(forecastData: any): ForecastPoint[] {
    if (!Array.isArray(forecastData)) return [];

    return forecastData.map((f: any) => ({
      validTime: f.validTime || new Date().toISOString(),
      center: {
        lat: f.position?.lat || 0,
        lon: f.position?.lon || 0,
      },
      maxWindSpeed: f.windSpeedKts ? f.windSpeedKts * 0.51444 : undefined,
    }));
  }

  private mapStatus(status: string): Typhoon['status'] {
    if (!status) return 'ACTIVE';
    const s = status.toLowerCase();
    if (s.includes('dissipate') || s.includes('remnant')) return 'DISSIPATED';
    if (s.includes('extratropical')) return 'EXTRATROPICAL';
    if (s.includes('weak')) return 'WEAKENING';
    return 'ACTIVE';
  }

  async isAvailable(): Promise<boolean> {
    return !!(this.apiKey || this.clientId);
  }
}
