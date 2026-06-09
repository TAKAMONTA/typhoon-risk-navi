import type { Typhoon } from '../../../types/typhoon';
import type {
  TyphoonDataSource,
  TyphoonFetchResult,
  AggregatedTyphoonResult,
} from './types';
import { toClientFriendly } from './normalize';

/**
 * 複数の台風データソースを統合・管理するコアクラス
 * 将来的に JTWC直叩き / Xweather / Azure Maps / JMA などを同じように扱えるようにする
 */
export class TyphoonDataAggregator {
  private sources: Map<string, TyphoonDataSource> = new Map();

  /**
   * データソースを登録
   */
  registerSource(source: TyphoonDataSource): void {
    const name = source.metadata.name;
    if (this.sources.has(name)) {
      console.warn(`[TyphoonDataAggregator] Source "${name}" is already registered. Overwriting.`);
    }
    this.sources.set(name, source);
  }

  /**
   * ソースを優先度順に取得
   */
  getSourcesByPriority(): TyphoonDataSource[] {
    return Array.from(this.sources.values()).sort(
      (a, b) => b.metadata.priority - a.metadata.priority
    );
  }

  /**
   * 登録されているソース一覧を取得
   */
  getRegisteredSources(): TyphoonDataSource[] {
    return Array.from(this.sources.values());
  }

  /**
   * 現在進行中の台風を複数ソースから取得し、統合して返す
   * 
   * 優先順位:
   * 1. 信頼できる商用ソース（Xweatherなど）が成功したらそれを最優先
   * 2. 公式ソース（JTWC/JMA）でフォールバック
   */
  async getActiveTyphoons(options?: {
    mergeStrategy?: 'priority' | 'all' | 'best-available';
  }): Promise<AggregatedTyphoonResult> {
    const strategy = options?.mergeStrategy ?? 'best-available';
    const fetchedAt = new Date().toISOString();

    const results = await this.fetchAllSourcesDetailed();

    const successfulSources = results
      .filter(r => !r.error && r.typhoons.length > 0)
      .map(r => r.source);

    let mergedTyphoons: Typhoon[] = [];
    let primarySource: string | undefined;

    if (strategy === 'best-available') {
      // 信頼できる商用ソースを最優先で探す
      const reliableSource = results.find(r => 
        !r.error && 
        r.typhoons.length > 0 && 
        ['Xweather', 'Azure', 'Commercial'].some(name => r.source.includes(name))
      );

      if (reliableSource) {
        mergedTyphoons = reliableSource.typhoons;
        primarySource = reliableSource.source;
      } else {
        // 商用ソースが取れなければ公式ソースでマージ
        mergedTyphoons = this.mergeByPriority(results);
        primarySource = successfulSources[0];
      }
    } else if (strategy === 'priority') {
      mergedTyphoons = this.mergeByPriority(results);
      primarySource = successfulSources[0];
    } else {
      mergedTyphoons = results.flatMap(r => r.typhoons);
      primarySource = successfulSources[0];
    }

    const deduped = this.removeDuplicates(mergedTyphoons);
    const normalized = this.normalizeAll(deduped);

    return {
      typhoons: normalized,
      sourcesUsed: successfulSources,
      primarySource,
      fetchedAt,
      mergeStrategy: strategy,
    };
  }

  /**
   * 各ソースの生の取得結果を返す（デバッグ・監視用）
   */
  async fetchAllSourcesDetailed(): Promise<TyphoonFetchResult[]> {
    const sources = Array.from(this.sources.values());
    const promises = sources.map(source => this.fetchWithTiming(source));
    return Promise.all(promises);
  }

  private async fetchWithTiming(source: TyphoonDataSource): Promise<TyphoonFetchResult> {
    const start = Date.now();
    const fetchedAt = new Date().toISOString();

    try {
      const typhoons = await source.fetchActiveTyphoons();
      return {
        source: source.metadata.name,
        typhoons,
        fetchedAt,
        durationMs: Date.now() - start,
      };
    } catch (error) {
      return {
        source: source.metadata.name,
        typhoons: [],
        fetchedAt,
        error: error instanceof Error ? error.message : String(error),
        durationMs: Date.now() - start,
      };
    }
  }

  private mergeByPriority(results: TyphoonFetchResult[]): Typhoon[] {
    // 優先度が高いソースのデータを優先しつつ、JTWCとJMAを賢く統合
    const sorted = [...results].sort((a, b) => {
      const sourceA = this.sources.get(a.source);
      const sourceB = this.sources.get(b.source);
      return (sourceB?.metadata.priority ?? 0) - (sourceA?.metadata.priority ?? 0);
    });

    const merged: Typhoon[] = [];
    const seen = new Set<string>();

    for (const result of sorted) {
      for (const t of result.typhoons) {
        // 同じ台風名が既にある場合は、優先度の高いソースの情報を優先
        const key = t.name;
        if (!seen.has(key)) {
          seen.add(key);
          merged.push(t);
        }
      }
    }

    return merged;
  }

  private removeDuplicates(typhoons: Typhoon[]): Typhoon[] {
    // TODO: より賢い重複除去ロジック（位置・名前ベースなど）を後で実装
    const seen = new Set<string>();
    return typhoons.filter(t => {
      const key = t.name || t.id;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  /**
   * JTWCなどから来たデータをアプリ全体で使いやすい形に正規化
   */
  private normalizeTyphoon(t: Typhoon): Typhoon {
    let normalized = { ...t };

    // 生データからの保険（古いソース用）
    if (!normalized.windRadii && (normalized.rawSources as any)?.windRadii) {
      normalized.windRadii = (normalized.rawSources as any).windRadii;
    }

    // クライアント（iOS）が扱いやすい flat 形式も同時に付与
    normalized = toClientFriendly(normalized);

    return normalized;
  }

  /**
   * マージ後の台風リストを一括正規化
   */
  private normalizeAll(typhoons: Typhoon[]): Typhoon[] {
    return typhoons.map(t => this.normalizeTyphoon(t));
  }
}
