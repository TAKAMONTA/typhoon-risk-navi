import type { SavedLocation } from '../types/location';
import { locationRepository, type ILocationRepository } from '../repositories/LocationRepository';

export class LocationService {
  constructor(private repo: ILocationRepository = locationRepository) {}

  async getUserLocations(deviceId: string, limit?: number, offset?: number): Promise<SavedLocation[]> {
    // 将来的にリポジトリレベルでページネーションを実装する
    const all = await this.repo.findByDeviceId(deviceId);
    if (limit !== undefined && offset !== undefined) {
      return all.slice(offset, offset + limit);
    }
    return all;
  }

  async addLocation(
    deviceId: string,
    data: Omit<SavedLocation, 'id' | 'createdAt'>
  ): Promise<SavedLocation> {
    // Basic validation could go here or in the route
    return this.repo.create(deviceId, data);
  }

  async removeLocation(deviceId: string, locationId: string): Promise<boolean> {
    return this.repo.delete(deviceId, locationId);
  }

  async updateLocation(
    deviceId: string,
    locationId: string,
    updates: Partial<Omit<SavedLocation, 'id' | 'createdAt'>>
  ): Promise<SavedLocation | null> {
    return this.repo.update(deviceId, locationId, updates);
  }
}

export const locationService = new LocationService();
