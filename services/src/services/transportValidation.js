import { Member2Error, validDate } from './bookingRules.js';
export const TRANSPORT_LOCK = 67290326;
export const periods = ['morning_1', 'morning_2', 'afternoon', 'evening'];
export const id = value => {
  if (!((typeof value === 'string') || Number.isSafeInteger(value)) || !/^[1-9]\d{0,18}$/.test(String(value)) || BigInt(value) > 9223372036854775807n) throw new Member2Error('invalid_id');
  return String(value);
};
export function text(value, max = 500) { if (typeof value !== 'string' || !value.trim() || value.trim().length > max) throw new Member2Error('invalid_transport_input'); return value.trim(); }
export function time(value) { if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) throw new Member2Error('invalid_time'); return value; }
export function integer(value, min, max) { if (!Number.isInteger(value) || value < min || value > max) throw new Member2Error('invalid_transport_input'); return value; }
export function boolean(value) { if (typeof value !== 'boolean') throw new Member2Error('invalid_transport_input'); return value; }
export function scheduleInput(input) {
  const value = { patternId: id(input.patternId), label: text(input.label, 150), period: input.period,
    departureTime: time(input.departureTime), arrivalTime: input.arrivalTime ? time(input.arrivalTime) : null,
    effectiveFrom: validDate(input.effectiveFrom), effectiveTo: input.effectiveTo ? validDate(input.effectiveTo) : null,
    serviceDays: input.serviceDays, busId: input.busId ? id(input.busId) : null, driverId: input.driverId ? id(input.driverId) : null,
    active: boolean(input.active), verified: boolean(input.verified), stopTimes: input.stopTimes };
  if (!periods.includes(value.period) || (value.arrivalTime && value.arrivalTime <= value.departureTime) ||
      (value.effectiveTo && value.effectiveTo < value.effectiveFrom) || !Array.isArray(value.serviceDays) || !value.serviceDays.length ||
      value.serviceDays.some(day => !Number.isInteger(day) || day < 0 || day > 6) || new Set(value.serviceDays).size !== value.serviceDays.length ||
      !Array.isArray(value.stopTimes)) throw new Member2Error('invalid_schedule');
  return value;
}
export function validateStopTimes(stops, entries, departure, arrival, direction) {
  if (stops.length !== entries.length || !stops.length) throw new Member2Error('invalid_stop_times');
  if (entries.some(e => !e || typeof e !== 'object' || Array.isArray(e))) throw new Member2Error('invalid_stop_times');
  const byId = new Map(entries.map(e => [id(e.patternStopId), e]));
  if (byId.size !== stops.length) throw new Member2Error('invalid_stop_times');
  let previous = null;
  return stops.map((stop, index) => {
    const entry = byId.get(String(stop.id));
    if (!entry || Boolean(entry.pickupTime) === Boolean(entry.arrivalTime)) throw new Member2Error('invalid_stop_times');
    const stamp = time(entry.pickupTime || entry.arrivalTime);
    if ((previous && stamp < previous) || (index === 0 && stamp !== departure) ||
        (entry.pickupTime && !stop.pickup_allowed) || (entry.arrivalTime && !stop.dropoff_allowed) ||
        (direction === 'inbound' && index === stops.length - 1 && (entry.arrivalTime !== arrival))) throw new Member2Error('invalid_stop_times');
    previous = stamp;
    return { patternStopId: String(stop.id), pickupTime: entry.pickupTime || null, arrivalTime: entry.arrivalTime || null };
  });
}
