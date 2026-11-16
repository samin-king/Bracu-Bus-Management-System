import { createDatabaseTripCatalog, createTripCatalog } from './tripCatalog.js';
import { createTransportCatalog } from './transportCatalog.js';

// Both existing trip sources keep their original IDs and booking validation.
export function createBookingTripCatalog(pool, env = process.env) {
  const mode = env.TRANSPORT_CATALOG || 'combined';
  if (mode === 'legacy-json') return createTripCatalog(JSON.parse(env.MEMBER2_TRIPS_JSON || '[]'));
  const member3 = createDatabaseTripCatalog(pool);
  const official = createTransportCatalog(pool);
  if (mode === 'member3') return member3;
  if (mode === 'postgres') return official;
  if (mode !== 'combined') throw new Error('Invalid TRANSPORT_CATALOG');
  return {
    async list(date, options) {
      const trips = await member3.list(date, options);
      return [...trips, ...await official.list(date, options)];
    },
    lockForBooking: official.lockForBooking,
    bookingSelection: official.bookingSelection,
  };
}
