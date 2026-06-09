/**
 * JTWCパーサーの簡易テスト用
 * 
 * 実行例:
 *   bun run src/services/typhoon/JTWCParser.test.ts
 */

import { parseJTWCWarnings } from './JTWCParser';

// 実際のJTWC警告に近いサンプルテキスト（新旧両方の風速半径表記を混ぜてテスト）
const sampleWarning = `
WTPN31 PGTW 300300
SUBJ/TYPHOON 06W (KONG-REY) WARNING NR 012//
1. TYPHOON 06W (KONG-REY) LOCATED AT 30.1N 127.8E AT 300000Z
   MOVEMENT PAST SIX HOURS  315 DEGREES AT 12 KTS
   MAX SUSTAINED WINDS - 065 KT, GUSTS 080 KT
   CENTRAL PRESSURE 965 MB
   RADIUS OF 034 KT WINDS - 120 NM NORTHEAST QUADRANT
   RADIUS OF 050 KT WINDS -  60 NM NORTHEAST QUADRANT
   RADIUS OF 064 KT WINDS -  25 NM NORTHEAST QUADRANT
2. FORECASTS:
   6 HRS, VALID AT:
   300600Z --- 31.0N 126.5E
   MAX SUSTAINED WINDS - 060 KT, GUSTS 075 KT
   RADIUS OF 034 KT WINDS - 090 NM NORTHEAST QUADRANT
   RADIUS OF 050 KT WINDS -  40 NM NORTHEAST QUADRANT
   12 HRS, VALID AT:
   301200Z --- 32.2N 125.0E
   MAX SUSTAINED WINDS - 055 KT, GUSTS 070 KT
`;

const typhoons = parseJTWCWarnings(sampleWarning);

console.log('Parsed typhoons:', JSON.stringify(typhoons, null, 2));

if (typhoons.length > 0) {
  console.log('\n✅ Parser test passed. Found', typhoons.length, 'typhoon(s).');
} else {
  console.log('\n❌ Parser test failed. No typhoons parsed.');
}
