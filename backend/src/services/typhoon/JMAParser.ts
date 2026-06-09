import * as cheerio from 'cheerio';
import type { Typhoon, TyphoonPosition } from '../../types/typhoon';

/**
 * 気象庁（JMA）台風ページのパーサー
 * 
 * 注意:
 * - JMAのボサイポータルはJavaScript重めで、構造化データが少ない
 * - このパーサーはメイン一覧ページからの最低限の情報抽出を試みる
 * - 詳細な予報円・時系列データは個別台風ページが必要になることが多い
 */

export async function fetchAndParseJMA(): Promise<Typhoon[]> {
  try {
    const res = await fetch('https://www.jma.go.jp/bosai/typhoon/', {
      signal: AbortSignal.timeout(10000),
      headers: {
        'User-Agent': 'TyphoonRiskNavi/1.0 (educational/research use)',
      },
    });

    if (!res.ok) {
      console.warn(`[JMA] Failed to fetch page: ${res.status}`);
      return [];
    }

    const html = await res.text();
    return parseJMAMainPage(html);
  } catch (error) {
    console.error('[JMA] Fetch error:', error);
    return [];
  }
}

export function parseJMAMainPage(html: string): Typhoon[] {
  const $ = cheerio.load(html);
  const typhoons: Typhoon[] = [];

  // JMAのボサイ台風ページはJavaScriptで描画されることが多い。
  // 可能な限り構造化データを探す（__NEXT_DATA__ や window 初期データなど）

  // 1. Next.js / 現代的な埋め込みJSONを探す
  $('script#__NEXT_DATA__').each((_, el) => {
    try {
      const json = JSON.parse($(el).html() || '{}');
      // JMAのデータ構造は時々変わるが、typhoon関連のデータを探す
      const typhoonData = findTyphoonDataInObject(json);
      if (typhoonData.length > 0) {
        typhoonData.forEach((item: any) => {
          const t = parseJMATyphoonItem(item);
          if (t) typhoons.push(t);
        });
      }
    } catch {}
  });

  // 2. テキストベースのフォールバック（台風名 + 位置）
  // 注意: 位置が抽出できない場合は台風オブジェクト自体を返さない（リスク計算で嘘の位置を使わないため）
  $('body').find('*').each((_, el) => {
    const text = $(el).text().trim();
    const nameMatch = text.match(/台風第(\d+)号/);
    if (nameMatch) {
      const name = nameMatch[0];

      // 位置抽出
      const parentText = $(el).parent().text() + ' ' + text;
      const posMatch = parentText.match(/([\d.]+)[°度]?\s*([NS])?\s*,?\s*([\d.]+)[°度]?\s*([EW])?/i);

      let center: TyphoonPosition | undefined;
      if (posMatch) {
        const lat = parseFloat(posMatch[1]) * (posMatch[2]?.toUpperCase() === 'S' ? -1 : 1);
        const lon = parseFloat(posMatch[3]) * (posMatch[4]?.toUpperCase() === 'W' ? -1 : 1);
        // 西太平洋の妥当な範囲のみ採用（lat 0〜45N, lon 100〜180E）
        if (
          !isNaN(lat) && !isNaN(lon) &&
          lat > 0 && lat < 45 &&
          lon > 100 && lon < 180
        ) {
          center = { lat, lon };
        }
      }

      // 位置が確実に取れた場合のみ追加（プレースホルダ座標は使わない）
      if (!center) {
        console.warn(`[JMA] Skipping ${name} — could not extract reliable coordinates from page`);
        return;
      }

      const existing = typhoons.find(t => t.name === name);
      if (!existing) {
        typhoons.push({
          id: `JMA-${name.replace(/\s+/g, '')}`,
          name: name,
          nameJa: name,
          source: 'JMA',
          status: 'ACTIVE',
          currentCenter: center,
          forecasts: [],
          lastUpdated: new Date().toISOString(),
        });
      } else {
        existing.currentCenter = center;
      }
    }
  });

  // 重複除去 + 最低限のデータだけ残す
  const unique = typhoons.filter((t, index, self) =>
    index === self.findIndex((tt) => tt.name === t.name)
  );

  return unique;
}

// 再帰的にオブジェクト内から台風っぽいデータを探すヘルパー
function findTyphoonDataInObject(obj: any, depth = 0): any[] {
  if (depth > 6 || !obj || typeof obj !== 'object') return [];
  const results: any[] = [];

  if (Array.isArray(obj)) {
    obj.forEach(item => {
      if (item && (item.typhoon || item.name?.includes('台風') || item.id?.includes('typhoon'))) {
        results.push(item);
      } else {
        results.push(...findTyphoonDataInObject(item, depth + 1));
      }
    });
  } else {
    Object.keys(obj).forEach(key => {
      const val = obj[key];
      if (key.toLowerCase().includes('typhoon') && val) {
        if (Array.isArray(val)) results.push(...val);
        else results.push(val);
      } else if (typeof val === 'object') {
        results.push(...findTyphoonDataInObject(val, depth + 1));
      }
    });
  }

  return results;
}

function parseJMATyphoonItem(item: any): Typhoon | null {
  if (!item) return null;

  const name = item.name || item.typhoonName || item.title || '';
  if (!name.includes('台風')) return null;

  let center: TyphoonPosition | undefined;
  const lat = item.lat ?? item.latitude ?? item.center?.lat;
  const lon = item.lon ?? item.longitude ?? item.center?.lon;

  if (lat && lon) {
    center = { lat: Number(lat), lon: Number(lon) };
  }

  // 強度情報の抽出を試みる
  const maxWind = item.maxWind ?? item.wind ?? item.intensity?.maxWind;
  const pressure = item.pressure ?? item.centralPressure ?? item.intensity?.pressure;

  // 簡易的な風域抽出（テキストから「強風域」「暴風域」を探す）
  const windRadii = extractBasicWindRadiiFromText(item.text || item.description || '');

  // 位置が取れなかった台風はリスク計算で使い物にならないので捨てる
  if (!center) {
    return null;
  }

  return {
    id: `JMA-${name.replace(/\s+/g, '')}`,
    name: name,
    nameJa: name,
    source: 'JMA',
    status: 'ACTIVE',
    currentCenter: center,
    maxWindSpeed: maxWind ? Number(maxWind) : undefined,
    centralPressure: pressure ? Number(pressure) : undefined,
    windRadii: windRadii || undefined,
    forecasts: [],
    lastUpdated: new Date().toISOString(),
  };
}

// JMAのテキストから簡易的に強風域・暴風域を抽出する補助関数
function extractBasicWindRadiiFromText(text: string): any {
  if (!text) return undefined;

  const radii: any = {};

  // 「強風域 半径XXXkm」などのパターンを探す（日本語・英語混在対応）
  const strongWind = text.match(/(強風域|strong wind).*?(\d+)\s*(km|キロ)/i);
  const stormWind = text.match(/(暴風域|storm wind|violent wind).*?(\d+)\s*(km|キロ)/i);

  if (strongWind) {
    const km = parseInt(strongWind[2]);
    radii['034'] = { NE: km, SE: km, SW: km, NW: km }; // 簡易的に全象限同じ値
  }
  if (stormWind) {
    const km = parseInt(stormWind[2]);
    radii['050'] = { NE: km, SE: km, SW: km, NW: km };
  }

  return Object.keys(radii).length > 0 ? radii : undefined;
}
