/**
 * TyphoonDataAggregator の最小実行テスト
 *
 * 実行方法:
 *   bun run src/services/typhoon/TyphoonDataAggregator.test.ts
 *
 * このテストでは現在実装されている JTWCSource と JMASource を実際に登録して動かします。
 * （現在はデータがほとんど取れない可能性が高いので、動作確認・ログ出力が主目的です）
 */

import { TyphoonDataAggregator } from './TyphoonDataAggregator';
import { JTWCSource } from './JTWCSource';
import { JMASource } from './JMASource';

async function main() {
  console.log('=== TyphoonDataAggregator 動作テスト開始 ===\n');

  const aggregator = new TyphoonDataAggregator();

  // ソース登録
  console.log('ソースを登録中...');
  aggregator.registerSource(new JTWCSource());
  aggregator.registerSource(new JMASource());

  const registered = aggregator.getRegisteredSources();
  console.log(`登録済みソース数: ${registered.length}`);
  registered.forEach(source => {
    console.log(`  - ${source.metadata.name} (priority: ${source.metadata.priority})`);
  });
  console.log('');

  // 統合取得テスト
  console.log('getActiveTyphoons() を実行中...');
  const result = await aggregator.getActiveTyphoons();

  console.log('\n=== 統合結果 ===');
  console.log(`取得台風数: ${result.typhoons.length}`);
  console.log(`使用されたソース: ${result.sourcesUsed.join(', ') || 'なし'}`);
  console.log(`プライマリソース: ${result.primarySource || 'なし'}`);
  console.log(`マージ戦略: ${result.mergeStrategy}`);
  console.log(`取得時刻: ${result.fetchedAt}`);

  if (result.typhoons.length > 0) {
    console.log('\n取得できた台風:');
    result.typhoons.forEach((t, i) => {
      console.log(`  [${i + 1}] ${t.name} (${t.source}) - 位置: ${t.currentCenter.lat.toFixed(2)}, ${t.currentCenter.lon.toFixed(2)}`);
    });
  } else {
    console.log('\n現在進行中の台風は取得できませんでした（ソースが未実装 or 現在台風なし）');
  }

  // 詳細取得テスト（各ソースの生結果）
  console.log('\n=== 各ソースの詳細取得結果 ===');
  const detailed = await aggregator.fetchAllSourcesDetailed();
  detailed.forEach(res => {
    console.log(`\n[${res.source}]`);
    console.log(`  取得件数: ${res.typhoons.length}`);
    console.log(`  取得時刻: ${res.fetchedAt}`);
    console.log(`  所要時間: ${res.durationMs ?? 'N/A'}ms`);
    if (res.error) {
      console.log(`  エラー: ${res.error}`);
    }
  });

  console.log('\n=== テスト終了 ===');
}

main().catch(err => {
  console.error('テスト実行中にエラーが発生しました:', err);
  process.exit(1);
});
