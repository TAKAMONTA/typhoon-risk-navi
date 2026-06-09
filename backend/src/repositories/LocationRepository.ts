import type { SavedLocation } from '../../types/location';
import { SqliteLocationRepository } from './SqliteLocationRepository';

export interface ILocationRepository {
  findByDeviceId(deviceId: string): Promise<SavedLocation[]>;
  findById(deviceId: string, id: string): Promise<SavedLocation | null>;
  create(deviceId: string, data: Omit<SavedLocation, 'id' | 'createdAt'>): Promise<SavedLocation>;
  update(deviceId: string, id: string, data: Partial<Omit<SavedLocation, 'id' | 'createdAt'>>): Promise<SavedLocation | null>;
  delete(deviceId: string, id: string): Promise<boolean>;
}

// Re-export the SQLite implementation as the default
export { SqliteLocationRepository } from './SqliteLocationRepository';

// For testing / easy rollback
export { InMemoryLocationRepository } from './InMemoryLocationRepository';

/**
 * Default repository implementation.
 * 
 * Uses SQLite for persistence (recommended for development & production).
 * 
 * To temporarily switch back to in-memory (useful for tests or quick experiments):
 *   import { InMemoryLocationRepository } from './InMemoryLocationRepository';
 *   export const locationRepository = new InMemoryLocationRepository();
 */
export const locationRepository = new SqliteLocationRepository();
