/**
 * アプリ内部で統一して扱う台風データモデル
 * JMA / JTWC などの複数のソースをここに正規化する
 */

export interface TyphoonPosition {
  lat: number;
  lon: number;
}

export interface ForecastPoint {
  validTime: string;           // ISO string または 'YYYY-MM-DD HH:mm'
  center: TyphoonPosition;
  radius?: number;             // 予報円半径 (km)
  maxWindSpeed?: number;       // 予想最大風速 (m/s または knot)
  centralPressure?: number;    // 予想中心気圧 (hPa)

  // 風速半径（存在する場合）
  windRadii?: {
    [knots: string]: {
      NE?: number;
      SE?: number;
      SW?: number;
      NW?: number;
    };
  };

  windRadiiFlat?: {
    radius34kt?: number;
    radius50kt?: number;
    radius64kt?: number;
  };

  windRadiiQuadrant?: any;
}

export type TyphoonStatus = 
  | 'ACTIVE' 
  | 'WEAKENING' 
  | 'EXTRATROPICAL' 
  | 'DISSIPATED';

export interface Typhoon {
  id: string;                    // 例: "2024-06" や JTWCの番号
  name: string;                  // 台風名（国際名）
  nameJa?: string;               // 日本語名（気象庁）
  source: 'JMA' | 'JTWC' | 'COMBINED';
  status: TyphoonStatus;
  currentCenter: TyphoonPosition;
  maxWindSpeed?: number;
  centralPressure?: number;
  direction?: number;            // 進行方向 (度)
  speed?: number;                // 進行速度 (km/h または knot)

  // 現在位置の風速半径（JTWCなどから取得できた場合）
  // 内部では quadrant 形式を優先的に保持
  windRadii?: {
    [knots: string]: {
      NE?: number;
      SE?: number;
      SW?: number;
      NW?: number;
    };
  };

  // クライアント（iOSなど）向けに正規化した flat 形式（オプション）
  windRadiiFlat?: {
    radius34kt?: number;
    radius50kt?: number;
    radius64kt?: number;
  };

  // 元の quadrant データを明示的に残したい場合用（オプション）
  windRadiiQuadrant?: any;

  // 最新の予報情報（時系列）
  forecasts: ForecastPoint[];

  // メタ情報
  lastUpdated: string;           // ISO string
  rawSources?: {
    jma?: any;
    jtwc?: any;
  };
}
