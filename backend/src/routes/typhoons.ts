import { Hono } from 'hono';
import { typhoonAggregator } from '../core/services';
import { success } from '../lib/response';
import type { Typhoon } from '../types/typhoon';

const typhoons = new Hono();

// GET /api/typhoons/active
typhoons.get('/active', async (c) => {
  const result = await typhoonAggregator.getActiveTyphoons();

  // クライアントフレンドリーにするため、windRadii を flat 版に置き換えつつ、
  // 元の quadrant データは windRadiiQuadrant として残す（上級者/内部用）
  const clientFriendlyTyphoons = (result.typhoons || []).map((t: any) => {
    const hasQuadrant = t.windRadii && !t.windRadii.radius34kt && Object.keys(t.windRadii).some(k => ['034','050','064','34','50','64'].includes(k));

    if (hasQuadrant && t.windRadiiFlat) {
      return {
        ...t,
        windRadii: t.windRadiiFlat,           // デフォルトでクライアントが欲しい flat 形式
        windRadiiQuadrant: t.windRadii,       // 本物の quadrant データも残す
        forecasts: (t.forecasts || []).map((f: any) => ({
          ...f,
          windRadii: f.windRadiiFlat || f.windRadii,
          windRadiiQuadrant: f.windRadii,
        })),
      };
    }
    return t; // すでに flat やデータなしの場合はそのまま
  });

  return success(c, {
    ...result,
    typhoons: clientFriendlyTyphoons,
  });
});

// 開発者向けデバッグエンドポイント
// 本番（NODE_ENV=production）では無効化する。各ソースの生取得結果を晒す危険があるため
typhoons.get('/debug/sources', async (c) => {
  if (process.env.NODE_ENV === 'production') {
    return c.notFound();
  }
  const results = await typhoonAggregator.fetchAllSourcesDetailed();

  // windRadii の存在状況をデバッグしやすくまとめる
  const enriched = results.map(result => {
    const typhoonDebug = (result.typhoons || []).map((t: any) => {
      const currentRadii = t.windRadii;
      const currentBands = currentRadii ? Object.keys(currentRadii) : [];
      const hasCurrent = currentBands.length > 0;

      const forecastsWithRadii = (t.forecasts || []).filter((f: any) => f.windRadii && Object.keys(f.windRadii).length > 0).length;
      const totalForecasts = (t.forecasts || []).length;

      // サンプル値（最初の台風の現在値だけ見やすく）
      let sampleCurrentKm: Record<string, number> | undefined;
      if (currentRadii) {
        sampleCurrentKm = {};
        for (const band of ['034', '050', '064']) {
          const q = currentRadii[band] || currentRadii[band.replace(/^0/, '')];
          if (q) {
            const maxNm = Math.max(q.NE || 0, q.SE || 0, q.SW || 0, q.NW || 0);
            if (maxNm > 0) sampleCurrentKm[band] = Math.round(maxNm * 1.852);
          }
        }
      }

      return {
        id: t.id,
        name: t.name,
        hasCurrentWindRadii: hasCurrent,
        currentBands,
        forecastsWithWindRadii: forecastsWithRadii,
        totalForecasts,
        sampleCurrentRadiiKm: sampleCurrentKm || null,
      };
    });

    return {
      ...result,
      debug: {
        typhoonCount: result.typhoons?.length ?? 0,
        typhoons: typhoonDebug,
        anyWindRadii: typhoonDebug.some((d: any) => d.hasCurrentWindRadii || d.forecastsWithWindRadii > 0),
      },
    };
  });

  // 全体サマリーも付けてさらにデバッグしやすく
  const sourcesWithWindRadii = enriched.filter(r => r.debug?.anyWindRadii).map(r => r.source);
  const summary = {
    totalSources: enriched.length,
    sourcesWithWindRadii,
    hasAnyRealWindRadii: sourcesWithWindRadii.length > 0,
  };

  return success(c, { summary, sources: enriched });
});

export default typhoons;
