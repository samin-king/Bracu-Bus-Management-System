import catalog from '../data/transport-locations.json';
export const CAMPUS = catalog.campus;
export const normalizeLocation = value => String(value || '').normalize('NFKC').toLowerCase().replace(/[–—]/g,'-').replace(/[^\p{L}\p{N}]+/gu,' ').trim();
const byLabel = new Map(catalog.locations.flatMap(location => location.labels.map(label => [normalizeLocation(label),location])));
export function validCoordinates(latitude,longitude) {
  return typeof latitude === 'number' && Number.isFinite(latitude) && latitude >= -90 && latitude <= 90 && typeof longitude === 'number' && Number.isFinite(longitude) && longitude >= -180 && longitude <= 180;
}
export function distanceKm(from,to) {
  if (!from || !to || !validCoordinates(from.latitude,from.longitude) || !validCoordinates(to.latitude,to.longitude)) return null;
  const radians = degrees => degrees * Math.PI / 180;
  const a = Math.sin(radians(to.latitude-from.latitude)/2)**2 + Math.cos(radians(from.latitude))*Math.cos(radians(to.latitude))*Math.sin(radians(to.longitude-from.longitude)/2)**2;
  return 6371.0088 * 2 * Math.atan2(Math.sqrt(Math.min(1,a)),Math.sqrt(Math.max(0,1-a)));
}
export function resolveLocation(stop) {
  const label = stop.label || stop.name || '';
  if (normalizeLocation(label).startsWith('brac university')) return {...CAMPUS,label,accuracy:'campus'};
  if (validCoordinates(stop.latitude,stop.longitude)) return {latitude:stop.latitude,longitude:stop.longitude,label,accuracy:'admin',sourceUrl:stop.coordinate_reference || null};
  const location = byLabel.get(normalizeLocation(label));
  return location ? {...location,label} : null;
}
export function locateStop(stop) {
  const location = resolveLocation(stop);
  return {...stop,location,straightDistanceKm:distanceKm(CAMPUS,location)};
}
export function formatDistance(km) {
  if (km == null || !Number.isFinite(km) || km < 0) return 'Unavailable';
  return km < 1 ? `${Math.round(km*1000)} m` : `${km.toFixed(1)} km`;
}
