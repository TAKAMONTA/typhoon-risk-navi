export interface SavedLocation {
  id: string;
  name: string;
  lat: number;
  lon: number;
  createdAt: string;
}

// Simple in-memory store (MVP)
// In production this would be replaced with a real database per user/device
const locationsStore: Map<string, SavedLocation[]> = new Map();

export function getLocations(deviceId: string): SavedLocation[] {
  return locationsStore.get(deviceId) || [];
}

export function addLocation(deviceId: string, location: Omit<SavedLocation, 'id' | 'createdAt'>): SavedLocation {
  const locations = getLocations(deviceId);
  
  const newLocation: SavedLocation = {
    ...location,
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
  };
  
  locations.push(newLocation);
  locationsStore.set(deviceId, locations);
  
  return newLocation;
}

export function deleteLocation(deviceId: string, locationId: string): boolean {
  const locations = getLocations(deviceId);
  const index = locations.findIndex(loc => loc.id === locationId);
  
  if (index === -1) return false;
  
  locations.splice(index, 1);
  locationsStore.set(deviceId, locations);
  return true;
}

export function updateLocation(deviceId: string, locationId: string, updates: Partial<Omit<SavedLocation, 'id' | 'createdAt'>>): SavedLocation | null {
  const locations = getLocations(deviceId);
  const location = locations.find(loc => loc.id === locationId);
  
  if (!location) return null;
  
  Object.assign(location, updates);
  return location;
}
