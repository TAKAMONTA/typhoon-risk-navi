import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import { riskService, typhoonAggregator, locationService } from '../core/services';
import { success, fail } from '../lib/response';

const risk = new Hono();

const getDeviceId = (c: any) => c.req.header('x-device-id') || 'default-device';

// ============================================
// GET /api/risk
// メインエンドポイント：ユーザーの保存場所に対するリスクを返す
// ============================================
risk.get('/', async (c) => {
  const deviceId = getDeviceId(c);

  const typhoonResult = await typhoonAggregator.getActiveTyphoons();

  if (typhoonResult.typhoons.length === 0) {
    return success(c, {
      message: '現在進行中の台風がありません',
      risks: [],
    });
  }

  const savedLocations = await locationService.getUserLocations(deviceId);

  if (savedLocations.length === 0) {
    return success(c, {
      message: '保存された場所がありません',
      risks: [],
      typhoon: typhoonResult.typhoons[0] || null,
    });
  }

  const risks = riskService.calculateRisksForLocations(
    savedLocations,
    typhoonResult.typhoons
  );

  return success(c, {
    risks,
    basedOn: typhoonResult.sourcesUsed,
    typhoon: typhoonResult.typhoons[0] || null,
  });
});

// ============================================
// GET /api/risk/calculate
// 任意の座標に対するリスク計算（開発・テスト用）
// 例: /api/risk/calculate?lat=26.2&lon=127.7&name=沖縄本島
// ============================================
const calculateQuerySchema = z.object({
  lat: z.string().transform((v) => parseFloat(v)),
  lon: z.string().transform((v) => parseFloat(v)),
  name: z.string().optional().default('指定地点'),
});

risk.get('/calculate', zValidator('query', calculateQuerySchema), async (c) => {
  const { lat, lon, name } = c.req.valid('query');

  const typhoonResult = await typhoonAggregator.getActiveTyphoons();

  if (typhoonResult.typhoons.length === 0) {
    return success(c, {
      message: '現在進行中の台風がありません',
      risks: [],
    });
  }

  const risks = riskService.calculateRisksForLocations(
    [{ id: 'temp', name, lat, lon }],
    typhoonResult.typhoons
  );

  return success(c, {
    risks,
    basedOn: typhoonResult.sourcesUsed,
  });
});

export default risk;
