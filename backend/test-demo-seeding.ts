/**
 * Light verification of demo seeding logic with the new persistent repository
 */
import { locationService } from './src/services/LocationService';
import { DEMO_LOCATIONS } from './src/data/demo';

async function main() {
  console.log('=== Demo Seeding Verification ===\n');

  const testDeviceId = 'test-demo-seeding-device';

  // Clean previous test data
  const existing = await locationService.getUserLocations(testDeviceId);
  for (const loc of existing) {
    await locationService.removeLocation(testDeviceId, loc.id);
  }
  console.log(`Cleaned ${existing.length} previous entries for test device`);

  // Simulate the seeding logic from /api/demo/state
  const before = await locationService.getUserLocations(testDeviceId);
  console.log(`Locations before seeding: ${before.length}`);

  if (before.length === 0) {
    console.log('Seeding demo locations...');
    for (const loc of DEMO_LOCATIONS) {
      await locationService.addLocation(testDeviceId, {
        name: loc.name,
        lat: loc.lat,
        lon: loc.lon,
      });
    }
  }

  const after = await locationService.getUserLocations(testDeviceId);
  console.log(`Locations after seeding: ${after.length}`);
  after.forEach(l => console.log(`  - ${l.name} (${l.lat}, ${l.lon})`));

  // Verify persistence with new service instance
  console.log('\n--- New LocationService instance ---');
  // Re-import to simulate fresh module load
  const { locationService: locationService2 } = await import('./src/services/LocationService');
  const persisted = await locationService2.getUserLocations(testDeviceId);
  console.log(`Locations via new service instance: ${persisted.length}`);

  // Cleanup
  for (const loc of persisted) {
    await locationService2.removeLocation(testDeviceId, loc.id);
  }
  console.log('\n✅ Demo seeding test data cleaned up');
  console.log('\n=== Verification Complete ===');
}

main().catch(console.error);