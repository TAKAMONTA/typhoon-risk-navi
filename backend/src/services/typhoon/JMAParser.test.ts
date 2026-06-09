/**
 * JMAパーサーの簡易テスト
 * 
 * 実行例:
 *   bun run src/services/typhoon/JMAParser.test.ts
 */

import { fetchAndParseJMA } from './JMAParser';

console.log('Fetching and parsing JMA typhoon data...');

const typhoons = await fetchAndParseJMA();

console.log('Parsed typhoons from JMA:', JSON.stringify(typhoons, null, 2));

if (typhoons.length > 0) {
  console.log(`\n✅ JMA parser returned ${typhoons.length} typhoon(s).`);
} else {
  console.log('\n⚠️ No typhoons parsed from JMA (this is common when no active typhoons, or page structure changed).');
}
