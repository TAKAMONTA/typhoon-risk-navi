import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import { locationService } from '../services/LocationService';
import { success, fail } from '../lib/response';

const locations = new Hono();

const getDeviceId = (c: any) => c.req.header('x-device-id') || 'default-device';

const locationSchema = z.object({
  name: z.string().min(1).max(100),
  lat: z.number().min(-90).max(90),
  lon: z.number().min(-180).max(180),
  notificationLevel: z.enum(['LOW', 'MEDIUM', 'HIGH', 'SEVERE']).optional(),
});

// GET /api/locations
// クエリパラメータ: ?limit=20&offset=0 （将来的にcursorベースも検討）
locations.get('/', async (c) => {
  const deviceId = getDeviceId(c);
  const limit = Math.min(parseInt(c.req.query('limit') || '50'), 100);
  const offset = parseInt(c.req.query('offset') || '0');

  const paginated = await locationService.getUserLocations(deviceId, limit, offset);
  const allLocations = await locationService.getUserLocations(deviceId); // total count用（改善の余地あり）

  return success(c, {
    locations: paginated,
    pagination: {
      total: allLocations.length,
      limit,
      offset,
      hasMore: offset + limit < allLocations.length,
    },
  });
});

// POST /api/locations
locations.post('/', zValidator('json', locationSchema), async (c) => {
  const deviceId = getDeviceId(c);
  const body = c.req.valid('json');
  
  const newLocation = await locationService.addLocation(deviceId, body);
  return success(c, newLocation, 201);
});

// DELETE /api/locations/:id
locations.delete('/:id', async (c) => {
  const deviceId = getDeviceId(c);
  const id = c.req.param('id');
  
  const deleted = await locationService.removeLocation(deviceId, id);
  
  if (!deleted) {
    return fail(c, 'Location not found', 404);
  }
  
  return success(c, { deleted: true });
});

// PATCH /api/locations/:id
locations.patch('/:id', zValidator('json', locationSchema.partial()), async (c) => {
  const deviceId = getDeviceId(c);
  const id = c.req.param('id');
  const updates = c.req.valid('json');
  
  const updated = await locationService.updateLocation(deviceId, id, updates);
  
  if (!updated) {
    return fail(c, 'Location not found', 404);
  }
  
  return success(c, updated);
});

export default locations;
