// 架空だが現実味のある台風データ（沖縄接近を想定したデモ用）
// 沖縄台風ナビ向け。風速半径は JTWC 形式に近い flat 値（km）。
// iOS 側と risk 計算で使用。初回起動時に沖縄の主要地点が自動登録されます。
export const DEMO_TYPHOON = {
  id: "2026-06W",
  name: "JANGMI",
  nameJa: "台風6号",
  source: "COMBINED",
  status: "ACTIVE",
  currentCenter: { lat: 22.5, lon: 126.5 },   // さらに南から北上する想定
  maxWindSpeed: 43.7, // m/s ≈ 85kt
  centralPressure: 950,
  direction: 340,
  speed: 20, // km/h
  windRadii: {
    radius34kt: 290,
    radius50kt: 115,
    radius64kt: 60,
  },
  forecasts: [
    {
      validTime: "2026-05-31T18:00:00Z",
      center: { lat: 24.2, lon: 126.8 },
      radius: 165,
      windRadii: { radius34kt: 270, radius50kt: 100, radius64kt: 50 },
    },
    {
      validTime: "2026-06-01T06:00:00Z",
      center: { lat: 25.4, lon: 127.0 },   // 沖縄本島にかなり近づく
      radius: 175,
      windRadii: { radius34kt: 230, radius50kt: 80, radius64kt: 35 },
    },
    {
      validTime: "2026-06-01T18:00:00Z",
      center: { lat: 26.3, lon: 127.5 },   // 沖縄本島通過・接近
      radius: 180,
      windRadii: { radius34kt: 190, radius50kt: 55, radius64kt: 20 },
    },
    {
      validTime: "2026-06-02T06:00:00Z",
      center: { lat: 27.8, lon: 128.8 },
      radius: 185,
      windRadii: { radius34kt: 130, radius50kt: 35, radius64kt: 0 },
    },
  ],
  lastUpdated: new Date().toISOString(),
};

export const DEMO_LOCATIONS = [
  { id: "loc1", name: "那覇市", lat: 26.21, lon: 127.68, notificationLevel: "SEVERE" as const },
  { id: "loc2", name: "宜野湾市", lat: 26.28, lon: 127.72, notificationLevel: "HIGH" as const },
  { id: "loc3", name: "宮古島", lat: 24.81, lon: 125.28, notificationLevel: "HIGH" as const },
  { id: "loc4", name: "石垣島", lat: 24.34, lon: 124.16, notificationLevel: "MEDIUM" as const },
  { id: "loc5", name: "恩納村", lat: 26.50, lon: 127.83, notificationLevel: "LOW" as const },
];
