export const config = {
  port: Number(process.env.PORT) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
  logLevel: process.env.LOG_LEVEL || 'info',

  // 商用ソース（任意）
  xweatherApiKey: process.env.XWEATHER_API_KEY,
  xweatherClientId: process.env.XWEATHER_CLIENT_ID,

  // 永続化
  database: {
    type: 'sqlite' as const, // 'sqlite' | 'postgres'（将来）
    sqlitePath: process.env.LOCATION_DB_PATH || './data/locations.db',
  },
};

export type Config = typeof config;
