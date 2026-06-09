import type { Typhoon, TyphoonPosition, ForecastPoint } from '../../types/typhoon';

/**
 * JTWCのテキスト警告をパースするユーティリティ
 * 
 * JTWCの製品は伝統的に固定幅/特定フォーマットのテキストで提供される。
 * 代表的なセクション:
 *   - WTPN31 などのヘッダ
 *   - 現在位置・強度
 *   - 予報 (FORECASTS:)
 */

export function parseJTWCWarnings(rawText: string): Typhoon[] {
  const typhoons: Typhoon[] = [];

  // 複数の台風警告を分割（通常 "WTPN" や "SUBJ/TYPHOON" で区切られる）
  const warnings = rawText.split(/(?=WTPN\d{2})/g).filter(Boolean);

  for (const warning of warnings) {
    const typhoon = parseSingleJTWCWarning(warning.trim());
    if (typhoon) {
      typhoons.push(typhoon);
    }
  }

  return typhoons;
}

function parseSingleJTWCWarning(text: string): Typhoon | null {
  // 台風番号と名前を抽出（例: TYPHOON 06W (KONG-REY)）
  const nameMatch = text.match(/TYPHOON\s+(\d{2}W)\s*\(([^)]+)\)/i);
  if (!nameMatch) return null;

  const number = nameMatch[1];
  const name = nameMatch[2].trim();

  // 現在位置を抽出（複数の表記に対応）
  // 例1: LOCATED AT 30.1N 127.8E AT 300000Z
  // 例2: 300600Z --- NEAR 18.3N 129.6E
  let positionMatch = text.match(/LOCATED AT\s+([\d.]+)([NS])\s+([\d.]+)([EW])\s+AT\s+(\d{6})Z/i);
  
  if (!positionMatch) {
    // より柔軟なパターン（"NEAR" や "---" を使った新しい形式）
    positionMatch = text.match(/(?:\d{6}Z\s*---\s*)?NEAR\s+([\d.]+)([NS])\s+([\d.]+)([EW])/i);
  }
  
  if (!positionMatch) return null;

  const lat = parseFloat(positionMatch[1]) * (positionMatch[2] === 'S' ? -1 : 1);
  const lon = parseFloat(positionMatch[3]) * (positionMatch[4] === 'W' ? -1 : 1);

  // 強度情報
  const windMatch = text.match(/MAX SUSTAINED WINDS\s*-\s*(\d+)\s*KT/i);
  const gustMatch = text.match(/GUSTS\s+(\d+)\s*KT/i);
  const pressureMatch = text.match(/CENTRAL PRESSURE\s+(\d+)\s*MB/i);

  // 風速半径を抽出（リスク計算に非常に重要）
  let windRadii = parseWindRadii(text);

  // フォールバック：旧形式の "34 KT WINDS" 表記がパースできなかった場合の簡易対応
  if (Object.keys(windRadii).length === 0) {
    const fallback34 = text.match(/34\s*KT\s*WINDS\s*(\d+)\s*NM/i);
    const fallback50 = text.match(/50\s*KT\s*WINDS\s*(\d+)\s*NM/i);
    if (fallback34 || fallback50) {
      windRadii = {};
      if (fallback34) windRadii['034'] = { NE: parseInt(fallback34[1]), SE: parseInt(fallback34[1]), SW: parseInt(fallback34[1]), NW: parseInt(fallback34[1]) };
      if (fallback50) windRadii['050'] = { NE: parseInt(fallback50[1]), SE: parseInt(fallback50[1]), SW: parseInt(fallback50[1]), NW: parseInt(fallback50[1]) };
    }
  }

  // 移動情報
  const movementMatch = text.match(/MOVEMENT PAST SIX HOURS\s+(\d+)\s+DEGREES AT\s+([\d.]+)/i);

  // 予報セクションを抽出（風速半径付き）
  const forecasts = parseJTWCForecasts(text);

  const now = new Date().toISOString();

  const result: Typhoon = {
    id: `JTWC-${number}`,
    name: name,
    source: 'JTWC',
    status: 'ACTIVE',
    currentCenter: { lat, lon },
    maxWindSpeed: windMatch ? parseInt(windMatch[1]) * 0.51444 : undefined,
    centralPressure: pressureMatch ? parseInt(pressureMatch[1]) : undefined,
    direction: movementMatch ? parseInt(movementMatch[1]) : undefined,
    speed: movementMatch ? parseFloat(movementMatch[2]) * 1.852 : undefined,
    windRadii: Object.keys(windRadii).length > 0 ? windRadii : undefined,
    forecasts,
    lastUpdated: now,
    rawSources: {
      jtwc: text.substring(0, 800),
    },
  };

  return result;
}

function parseJTWCForecasts(text: string): ForecastPoint[] {
  const forecasts: ForecastPoint[] = [];

  // FORECASTS: 以降を対象にする
  const forecastSection = text.split(/FORECASTS?:/i)[1];
  if (!forecastSection) return forecasts;

  // より堅牢な正規表現で各予報ブロックを抽出
  // 例:
  // 6 HRS, VALID AT: 300600Z --- 31.0N 126.5E
  // MAX SUSTAINED WINDS - 085 KT
  // RADIUS OF 064 KT WINDS - 030 NM NORTHEAST QUADRANT
  const blockRegex = /(\d+)\s*HRS.*?VALID AT:\s*(\d{6})Z\s*---\s*([\d.]+)([NS])\s+([\d.]+)([EW])([\s\S]*?)(?=\d+\s*HRS|FORECAST|$)/gi;

  let match;
  while ((match = blockRegex.exec(forecastSection)) !== null) {
    const hours = parseInt(match[1]);
    const validTime = new Date(Date.now() + hours * 3600 * 1000).toISOString();

    const lat = parseFloat(match[3]) * (match[4] === 'S' ? -1 : 1);
    const lon = parseFloat(match[5]) * (match[6] === 'W' ? -1 : 1);

    const blockText = match[7] || '';

    // この予報ブロック内の風速半径を抽出
    const windRadii = parseWindRadii(blockText);

    // 予報最大風速も可能なら取る
    const fcstWindMatch = blockText.match(/MAX SUSTAINED WINDS\s*-\s*(\d+)\s*KT/i);

    forecasts.push({
      validTime,
      center: { lat, lon },
      windRadii: Object.keys(windRadii).length > 0 ? windRadii : undefined,
      maxWindSpeed: fcstWindMatch ? parseInt(fcstWindMatch[1]) * 0.51444 : undefined,
    });
  }

  return forecasts;
}

/**
 * 風速半径をパース（34kt, 50kt, 64kt）
 * 
 * 複数のJTWCテキスト形式に対応:
 * - 新形式: RADIUS OF 064 KT WINDS - 090 NM NORTHEAST QUADRANT
 * - 旧形式: 34 KT WINDS  120 NM NORTHEAST QUADRANT
 */
function parseWindRadii(text: string): Record<string, any> {
  const radii: Record<string, any> = {};

  // 新形式（2023〜現在主流）
  const newFormat = /RADIUS OF\s+(\d+)\s*KT WINDS\s*-\s*(\d+)\s*NM\s+(\w+)\s+QUADRANT/gi;
  let match;
  while ((match = newFormat.exec(text)) !== null) {
    const knots = match[1];
    const nm = parseInt(match[2]);
    const q = match[3].toUpperCase();
    const quadrant = q.startsWith('NO') ? 'NE' :
                     q.startsWith('SO') ? 'SE' :
                     q.startsWith('SW') ? 'SW' : 'NW';
    if (!radii[knots]) radii[knots] = {};
    radii[knots][quadrant] = nm;
  }

  // 旧形式（少し前のJTWC警告でよく見る）
  const oldFormat = /(\d+)\s*KT WINDS\s+(\d+)\s*NM\s+(\w+)\s+QUADRANT/gi;
  while ((match = oldFormat.exec(text)) !== null) {
    const knots = match[1];
    const nm = parseInt(match[2]);
    const q = match[3].toUpperCase();
    const quadrant = q.startsWith('NO') ? 'NE' :
                     q.startsWith('SO') ? 'SE' :
                     q.startsWith('SW') ? 'SW' : 'NW';
    if (!radii[knots]) radii[knots] = {};
    radii[knots][quadrant] = nm;
  }

  return radii;
}

