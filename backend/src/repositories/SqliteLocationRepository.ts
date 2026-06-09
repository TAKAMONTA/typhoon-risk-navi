import { Database } from 'bun:sqlite';
import type { SavedLocation } from '../../types/location';
import type { ILocationRepository } from './LocationRepository';

const DB_PATH = process.env.LOCATION_DB_PATH || './data/locations.db';

export class SqliteLocationRepository implements ILocationRepository {
  private db: Database;

  constructor() {
    // Ensure data directory exists
    const fs = require('fs');
    const path = require('path');
    const dir = path.dirname(DB_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    this.db = new Database(DB_PATH, { create: true });
    this.initSchema();
  }

  private initSchema() {
    this.db.run(`
      CREATE TABLE IF NOT EXISTS locations (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        notification_level TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
    `);

    // Helpful index for the common query pattern
    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_locations_device_id 
      ON locations(device_id);
    `);
  }

  async findByDeviceId(deviceId: string): Promise<SavedLocation[]> {
    const stmt = this.db.prepare(`
      SELECT id, name, lat, lon, notification_level as notificationLevel, created_at as createdAt
      FROM locations 
      WHERE device_id = ?
      ORDER BY created_at DESC
    `);

    const rows = stmt.all(deviceId) as any[];
    return rows.map(this.mapRowToLocation);
  }

  async findById(deviceId: string, id: string): Promise<SavedLocation | null> {
    const stmt = this.db.prepare(`
      SELECT id, name, lat, lon, notification_level as notificationLevel, created_at as createdAt
      FROM locations 
      WHERE device_id = ? AND id = ?
    `);

    const row = stmt.get(deviceId, id) as any;
    return row ? this.mapRowToLocation(row) : null;
  }

  async create(deviceId: string, data: Omit<SavedLocation, 'id' | 'createdAt'>): Promise<SavedLocation> {
    const id = crypto.randomUUID();
    const now = new Date().toISOString();

    const stmt = this.db.prepare(`
      INSERT INTO locations (id, device_id, name, lat, lon, notification_level, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      id,
      deviceId,
      data.name,
      data.lat,
      data.lon,
      data.notificationLevel ?? null,
      now
    );

    return {
      id,
      name: data.name,
      lat: data.lat,
      lon: data.lon,
      notificationLevel: data.notificationLevel,
      createdAt: now,
    };
  }

  async update(
    deviceId: string,
    id: string,
    data: Partial<Omit<SavedLocation, 'id' | 'createdAt'>>
  ): Promise<SavedLocation | null> {
    const fields: string[] = [];
    const values: any[] = [];

    if (data.name !== undefined) {
      fields.push('name = ?');
      values.push(data.name);
    }
    if (data.lat !== undefined) {
      fields.push('lat = ?');
      values.push(data.lat);
    }
    if (data.lon !== undefined) {
      fields.push('lon = ?');
      values.push(data.lon);
    }
    if (data.notificationLevel !== undefined) {
      fields.push('notification_level = ?');
      values.push(data.notificationLevel ?? null);
    }

    if (fields.length === 0) {
      return this.findById(deviceId, id);
    }

    values.push(deviceId, id);

    const stmt = this.db.prepare(`
      UPDATE locations 
      SET ${fields.join(', ')}
      WHERE device_id = ? AND id = ?
      RETURNING id, name, lat, lon, notification_level as notificationLevel, created_at as createdAt
    `);

    const row = stmt.get(...values) as any;
    return row ? this.mapRowToLocation(row) : null;
  }

  async delete(deviceId: string, id: string): Promise<boolean> {
    const stmt = this.db.prepare(`
      DELETE FROM locations 
      WHERE device_id = ? AND id = ?
    `);

    const result = stmt.run(deviceId, id);
    return result.changes > 0;
  }

  private mapRowToLocation(row: any): SavedLocation {
    return {
      id: row.id,
      name: row.name,
      lat: row.lat,
      lon: row.lon,
      notificationLevel: row.notificationLevel ?? undefined,
      createdAt: row.createdAt,
    };
  }

  // For testing / admin use
  close() {
    this.db.close();
  }
}

// 注意: アプリ全体で共有するシングルトンは `LocationRepository.ts` 側で生成される。
// このファイルではクラスのみ export し、二重に DB 接続が開かれないようにする。