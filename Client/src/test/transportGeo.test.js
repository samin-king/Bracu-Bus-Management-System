import source from '../../../database/seeds/bracu-2026-10-03.json';
import catalog from '../data/transport-locations.json';
import {it,expect} from 'vitest';
import {CAMPUS,distanceKm,formatDistance,locateStop,normalizeLocation,resolveLocation,validCoordinates} from '../utils/transportGeo.js';
it('uses the Merul Badda campus and calculates symmetric great-circle distances',()=>{
 expect(CAMPUS.latitude).toBeGreaterThan(23.77);expect(CAMPUS.latitude).toBeLessThan(23.78);expect(distanceKm(CAMPUS,CAMPUS)).toBe(0);
 const point={latitude:24.7733146,longitude:CAMPUS.longitude};expect(distanceKm(CAMPUS,point)).toBeCloseTo(111.195,2);expect(distanceKm(point,CAMPUS)).toBeCloseTo(111.195,2);
});
it('rejects absent, nonnumeric, infinite and out-of-range coordinates instead of mapping them to zero',()=>{
 for(const [lat,lon] of [[null,null],['23.8','90.4'],[Infinity,90],[91,90],[23,181]])expect(validCoordinates(lat,lon)).toBe(false);
 expect(distanceKm(CAMPUS,null)).toBeNull();expect(locateStop({label:'Unknown future stop'}).location).toBeNull();expect(locateStop({label:'Unknown future stop'}).straightDistanceKm).toBeNull();
});
it('uses authenticated admin coordinates and retains source references',()=>{
 const result=resolveLocation({label:'New official point',latitude:23.8,longitude:90.4,coordinate_reference:'survey'});expect(result.accuracy).toBe('admin');expect(result.sourceUrl).toBe('survey');expect(resolveLocation({label:'BRAC University (arrival time)'}).latitude).toBe(CAMPUS.latitude);
});
it('normalizes aliases, formats metres/kilometres and leaves missing distance unavailable',()=>{
 expect(normalizeLocation('  Mirpur–A (BUS STOP) ')).toBe('mirpur a bus stop');expect(formatDistance(0)).toBe('0 m');expect(formatDistance(.125)).toBe('125 m');expect(formatDistance(3.142)).toBe('3.1 km');expect(formatDistance(null)).toBe('Unavailable');expect(formatDistance(NaN)).toBe('Unavailable');
});

it('covers every published timetable association with a sourced landmark or explicitly approximate area reference',()=>{
 let count=0;
 for(const variant of source.variants)for(const stop of variant.stops){const point=locateStop({label:stop.name});expect(point.location,stop.name).not.toBeNull();expect(point.straightDistanceKm).toBeGreaterThanOrEqual(0);expect(point.straightDistanceKm).toBeLessThan(40);expect(point.location.sourceUrl).toMatch(/^https:\/\/www\.openstreetmap\.org\/(node|way|relation)\/\d+$/);count++;}
 expect(count).toBe(107);expect(catalog.locations.some(point=>point.accuracy==='area')).toBe(true);expect(catalog.locations.every(point=>['area','landmark'].includes(point.accuracy))).toBe(true);
});
