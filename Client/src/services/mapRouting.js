import {validCoordinates} from '../utils/transportGeo.js';
const base = (import.meta.env.VITE_MAP_ROUTER_URL || 'https://router.project-osrm.org').replace(/\/$/,'');
const cache = new Map();
let queue = Promise.resolve(), lastRequest = 0;
export function roadRoute(from,to) {
  if (!validCoordinates(from?.latitude,from?.longitude) || !validCoordinates(to?.latitude,to?.longitude)) return Promise.reject(new Error('Location coordinates are not available.'));
  const coordinates = `${from.longitude},${from.latitude};${to.longitude},${to.latitude}`;
  if (cache.has(coordinates)) return cache.get(coordinates);
  const request = queue.catch(()=>{}).then(async()=>{
    const pause = 1100 - (Date.now()-lastRequest);
    if (pause > 0) await new Promise(resolve=>setTimeout(resolve,pause));
    lastRequest = Date.now();
    const response = await fetch(`${base}/route/v1/driving/${coordinates}?overview=full&geometries=geojson&steps=false`,{signal:AbortSignal.timeout(15000)});
    if (!response.ok) throw new Error('Road directions are temporarily unavailable.');
    const data = await response.json(), route = data.routes?.[0];
    if (data.code !== 'Ok' || !route || !Number.isFinite(route.distance) || route.distance < 0 || route.geometry?.type !== 'LineString' || !route.geometry.coordinates?.length || route.geometry.coordinates.some(p => !Array.isArray(p) || !validCoordinates(p[1],p[0]))) throw new Error('No road route was found for this location.');
    return {distanceKm:route.distance/1000,coordinates:route.geometry.coordinates.map(([lon,lat])=>[lat,lon])};
  });
  queue = request;
  cache.set(coordinates,request);
  request.catch(()=>cache.delete(coordinates));
  return request;
}
