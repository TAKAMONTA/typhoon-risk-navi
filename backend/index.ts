import { Hono } from 'hono';
import { logger } from 'hono/logger';
import { cors } from 'hono/cors';

import { errorHandler } from './src/middleware/errorHandler';
import { riskService, locationService, typhoonAggregator } from './src/core/services';
import { toClientFriendly } from './src/services/typhoon/normalize';
import { config } from './src/config';

// Route groups
import locationsRouter from './src/routes/locations';
import typhoonsRouter from './src/routes/typhoons';
import riskRouter from './src/routes/risk';

const app = new Hono();

// --- Global middleware ---

// 本番は環境変数で許可オリジンを絞る。開発時は全許可。
const allowedOrigins =
  (process.env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

app.use(
  '*',
  cors({
    origin: (origin) => {
      if (!config.isProduction) return origin || '*';
      if (!origin) return '';
      return allowedOrigins.includes(origin) ? origin : '';
    },
    allowHeaders: ['Content-Type', 'x-device-id'],
    allowMethods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    maxAge: 600,
  }),
);

// 本番では HTTP リクエストログを抑制（個人情報やパスを過剰に晒さない）
if (!config.isProduction) {
  app.use('*', logger());
}

// device_id ヘッダ必須化（locations / risk / demo 系のみ）
function requireDeviceId(c: any, next: any) {
  const deviceId = c.req.header('x-device-id');
  if (!deviceId || deviceId.trim().length === 0) {
    return c.json(
      { success: false, error: { message: 'x-device-id header is required', code: 'MISSING_DEVICE_ID' } },
      400,
    );
  }
  return next();
}

app.use('/api/locations/*', requireDeviceId);
app.use('/api/locations', requireDeviceId);
app.use('/api/risk/*', requireDeviceId);
app.use('/api/risk', requireDeviceId);
app.use('/api/demo/*', requireDeviceId);

// Global error handler
app.onError(errorHandler);

// --- Routes ---
app.route('/api/locations', locationsRouter);
app.route('/api/typhoons', typhoonsRouter);
app.route('/api/risk', riskRouter);

// Health check（device_id 不要）
app.get('/health', (c) => c.json({ status: 'ok' }));

// --- Demo endpoints ---
//
// 設計方針:
// - GET /api/demo/state は副作用なし。読むだけ。
// - 保存場所の初期シードは POST /api/demo/seed で明示的に行う（冪等）。
//
// 旧バージョンは GET /api/demo/state 内で保存場所 0 件のとき勝手にデモ場所を作成していた。
// REST 的にも安全性的にも GET から書き込みを行うのは不適切なので分離。

app.get('/api/demo/state', async (c) => {
  const { DEMO_TYPHOON } = await import('./src/data/demo');
  const deviceId = c.req.header('x-device-id')!; // requireDeviceId で保証済み

  // 実データソースを優先的に試す
  let primaryTyphoon: any = DEMO_TYPHOON;
  try {
    const realResult = await typhoonAggregator.getActiveTyphoons({ mergeStrategy: 'best-available' });
    if (realResult.typhoons.length > 0) {
      primaryTyphoon = realResult.typhoons[0];
      if (!config.isProduction) {
        console.log('[demo/state] Using real data from:', realResult.primarySource || realResult.sourcesUsed.join(','));
      }
    }
  } catch {
    // 実データが取れなければデモ継続（静かにフォールバック）
  }

  const userLocations = await locationService.getUserLocations(deviceId);
  const risks = riskService.calculateRisksForLocations(userLocations, [primaryTyphoon]);

  // iOS が扱いやすいよう正規化
  let clientTyphoon: any = toClientFriendly(primaryTyphoon);
  if (clientTyphoon.windRadiiFlat) {
    clientTyphoon = {
      ...clientTyphoon,
      windRadii: clientTyphoon.windRadiiFlat,
      windRadiiQuadrant: clientTyphoon.windRadii,
      forecasts: (clientTyphoon.forecasts || []).map((f: any) => ({
        ...f,
        windRadii: f.windRadiiFlat || f.windRadii,
        windRadiiQuadrant: f.windRadii,
      })),
    };
  }

  return c.json({
    typhoon: clientTyphoon,
    risks,
    savedLocations: userLocations,
    lastUpdated: new Date().toISOString(),
  });
});

/**
 * 保存場所が 0 件のデバイスにデモ場所をシードする冪等エンドポイント。
 * 既に保存場所がある場合は何もしない（既存データを壊さない）。
 */
app.post('/api/demo/seed', async (c) => {
  const { DEMO_LOCATIONS } = await import('./src/data/demo');
  const deviceId = c.req.header('x-device-id')!;

  const existing = await locationService.getUserLocations(deviceId);
  if (existing.length > 0) {
    return c.json({
      success: true,
      data: { seeded: false, reason: 'device already has locations', existingCount: existing.length },
    });
  }

  for (const loc of DEMO_LOCATIONS) {
    await locationService.addLocation(deviceId, {
      name: loc.name,
      lat: loc.lat,
      lon: loc.lon,
      notificationLevel: loc.notificationLevel,
    });
  }

  const seeded = await locationService.getUserLocations(deviceId);
  return c.json({ success: true, data: { seeded: true, count: seeded.length } });
});

if (!config.isProduction) {
  console.log('🚀 沖縄台風ナビ Backend starting on port', config.port);
}

export default app;
