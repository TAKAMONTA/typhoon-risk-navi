export interface SavedLocation {
  id: string;
  name: string;
  lat: number;
  lon: number;
  notificationLevel?: 'LOW' | 'MEDIUM' | 'HIGH' | 'SEVERE';
  createdAt: string;
}
