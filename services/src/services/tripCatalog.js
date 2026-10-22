// Read-only boundary: replace this adapter with Member 3's existing repository
// when merged. No bus/route/trip schema or management endpoints are introduced.
export function createTripCatalog(trips = []) {
  const ids = new Set();
  for (const trip of trips) {
    if (!trip || typeof trip.id !== 'string' || !trip.id || ids.has(trip.id) ||
        typeof trip.bus !== 'string' || !trip.bus || typeof trip.route !== 'string' || !trip.route ||
        !['14:00', '17:00', '06:30', '08:30'].includes(trip.departureTime) ||
        !Number.isInteger(trip.capacity) || trip.capacity < 1 || trip.capacity > 200 ||
        !Number.isInteger(trip.standingCapacity ?? 0) || (trip.standingCapacity ?? 0) < 0 ||
        (trip.dates && (!Array.isArray(trip.dates) || trip.dates.some(d => !/^\d{4}-\d{2}-\d{2}$/.test(d))))) {
      throw new Error('Invalid Member 2 trip catalog');
    }
    ids.add(trip.id);
  }
  const catalog = structuredClone(trips);
  return { async list(date) { return structuredClone(catalog.filter(t => !t.dates || t.dates.includes(date))); } };
}
