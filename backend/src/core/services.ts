import { TyphoonDataAggregator } from '../services/typhoon/TyphoonDataAggregator';
import { JTWCSource } from '../services/typhoon/JTWCSource';
import { JMASource } from '../services/typhoon/JMASource';
import { XweatherSource } from '../services/typhoon/XweatherSource';
import { RiskCalculationService } from '../services/risk/RiskCalculationService';
import { LocationService } from '../services/LocationService';

// アプリケーション全体で共有するサービスインスタンス
// 本番ではDIコンテナ（例: tsyringe など）に置き換えることを推奨

export const typhoonAggregator = new TyphoonDataAggregator();

// === データソース登録（優先度順） ===
// 1. 信頼できる商用ソース（最優先）
const xweather = new XweatherSource();
if (process.env.XWEATHER_API_KEY || process.env.XWEATHER_CLIENT_ID) {
  typhoonAggregator.registerSource(xweather);
  console.log('[Data] Xweather source registered (high priority)');
}

// 2. 公式ソース（フォールバック）
typhoonAggregator.registerSource(new JTWCSource());
typhoonAggregator.registerSource(new JMASource());

console.log('[Data] Registered sources:', 
  typhoonAggregator.getRegisteredSources().map(s => s.metadata.name).join(', ')
);

export const riskService = new RiskCalculationService();

export const locationService = new LocationService();
