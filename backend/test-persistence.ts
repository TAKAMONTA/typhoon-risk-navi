/**
 * Simple persistence verification script for SqliteLocationRepository
 * Run with: bun run test-persistence.ts
 */
import { SqliteLocationRepository } from './src/repositories/SqliteLocationRepository';

async function main() {
  console.log('=== Persistence Verification ===\n');

  // Use a test-specific DB to avoid polluting real data
  process.env.LOCATION_DB_PATH = './data/test-locations.db';

  const repo = new SqliteLocationRepository();
  const testDeviceId = 'test-device-verification';

  // Clean up previous test data
  const existing = await repo.findByDeviceId(testDeviceId);
  for (const loc of existing) {
    await repo.delete(testDeviceId, loc.id);
  }
  console.log(`Cleaned up ${existing.length} previous test locations`);

  // 1. Create locations
  console.log('\n--- Creating locations ---');
  const loc1 = await repo.create(testDeviceId, {
    name: 'テスト場所1',
    lat: 35.6812,
    lon: 139.7671,
    notificationLevel: 'MEDIUM',
  });
  console.log('Created:', loc1);

  const loc2 = await repo.create(testDeviceId, {
    name: 'テスト場所2',
    lat: 34.6937,
    lon: 135.5023,
  });
  console.log('Created:', loc2);

  // 2. Find by device
  console.log('\n--- findByDeviceId ---');
  const all = await repo.findByDeviceId(testDeviceId);
  console.log(`Found ${all.length} locations for device:`);
  all.forEach(l => console.log(`  - ${l.name} (${l.lat}, ${l.lon}) [${l.notificationLevel || 'none'}]`));

  // 3. Find by id
  console.log('\n--- findById ---');
  const found = await repo.findById(testDeviceId, loc1.id);
  console.log('Found by ID:', found ? found.name : 'null');

  // 4. Update
  console.log('\n--- Update ---');
  const updated = await repo.update(testDeviceId, loc1.id, {
    name: 'テスト場所1 (更新済み)',
    notificationLevel: 'HIGH',
  });
  console.log('Updated:', updated);

  // 5. Verify update
  const afterUpdate = await repo.findByDeviceId(testDeviceId);
  console.log('\nAfter update:');
  afterUpdate.forEach(l => console.log(`  - ${l.name} [${l.notificationLevel || 'none'}]`));

  // 6. Delete
  console.log('\n--- Delete ---');
  const deleted = await repo.delete(testDeviceId, loc2.id);
  console.log(`Delete result: ${deleted}`);

  const remaining = await repo.findByDeviceId(testDeviceId);
  console.log(`Remaining locations: ${remaining.length}`);

  // 7. Persistence test: Create new instance and check data
  console.log('\n--- Persistence Test (new repository instance) ---');
  const repo2 = new SqliteLocationRepository();
  const persisted = await repo2.findByDeviceId(testDeviceId);
  console.log(`Found ${persisted.length} locations with new repo instance:`);
  persisted.forEach(l => console.log(`  - ${l.name} (createdAt: ${l.createdAt})`));

  // Cleanup
  for (const loc of persisted) {
    await repo2.delete(testDeviceId, loc.id);
  }
  console.log('\n✅ Test data cleaned up');

  repo.close();
  repo2.close();

  console.log('\n=== Verification Complete ===');
}

main().catch(console.error);