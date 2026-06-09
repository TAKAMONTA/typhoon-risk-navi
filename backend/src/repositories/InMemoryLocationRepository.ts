import type { SavedLocation } from '../../types/location';
import type { ILocationRepository } from './LocationRepository';

export class InMemoryLocationRepository implements ILocationRepository {
  private store = new Map<string, SavedLocation[]>();

  async findByDeviceId(deviceId: string): Promise<SavedLocation[]> {
    return this.store.get(deviceId) || [];
  }

  async findById(deviceId: string, id: string): Promise<SavedLocation | null> {
    const locations = this.store.get(deviceId) || [];
    return locations.find((loc) => loc.id === id) || null;
  }

  async create(deviceId: string, data: Omit<SavedLocation, 'id' | 'createdAt'>): Promise<SavedLocation> {
    const locations = this.store.get(deviceId) || [];
    
    const newLocation: SavedLocation = {
      ...data,
      id: crypto.randomUUID(),
      createdAt: new Date().toISOString(),
    };

    locations.push(newLocation);
    this.store.set(deviceId, locations);

    return newLocation;
  }

  async update(deviceId: string, id: string, data: Partial<Omit<SavedLocation, 'id' | 'createdAt'>>): Promise<SavedLocation | null> {
    const locations = this.store.get(deviceId) || [];
    const index = locations.findIndex((loc) => loc.id === id);

    if (index === -1) return null;

    const updated = { ...locations[index], ...data };
    locations[index] = updated;
    this.store.set(deviceId, locations);

    return updated;
  }

  async delete(deviceId: string, id: string): Promise<boolean> {
    const locations = this.store.get(deviceId) || [];
    const initialLength = locations.length;
    
    const filtered = locations.filter((loc) => loc.id !== id);
    this.store.set(deviceId, filtered);

    return filtered.length < initialLength;
  }
}