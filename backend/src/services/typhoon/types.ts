import type { Typhoon } from '../../../types/typhoon';

/**
 * データソースのメタ情報
 */
export interface DataSourceMetadata {
  name: string;
  priority: number;           // 高いほど優先
  description?: string;
  supportsForecastCone: boolean;
  supportsWindRadii: boolean;
  supportsIntensityForecast: boolean;
  typicalUpdateIntervalMinutes: number;
}

/**
 * データソースが持つべき基本インターフェース
 */
export interface TyphoonDataSource {
  readonly metadata: DataSourceMetadata;

  /**
   * 現在進行中の台風を取得
   */
  fetchActiveTyphoons(): Promise<Typhoon[]>;

  /**
   * 特定の台風の詳細を取得（任意実装）
   */
  fetchTyphoonById?(id: string): Promise<Typhoon | null>;

  /**
   * ソースが現在利用可能かどうか
   */
  isAvailable?(): Promise<boolean>;
}

/**
 * 各ソースからの生取得結果（デバッグ・監視用）
 */
export interface TyphoonFetchResult {
  source: string;
  typhoons: Typhoon[];
  fetchedAt: string;
  error?: string;
  durationMs?: number;
}

/**
 * 複数ソースを統合した結果
 */
export interface AggregatedTyphoonResult {
  typhoons: Typhoon[];
  sourcesUsed: string[];
  primarySource?: string;
  fetchedAt: string;
  mergeStrategy: string;
}
