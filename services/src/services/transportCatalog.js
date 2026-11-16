import { validDate, Member2Error } from './bookingRules.js';
import { TRANSPORT_LOCK, id } from './transportValidation.js';
const hhmm = value => value == null ? null : String(value).slice(0,5);
export function createTransportCatalog(pool) {
  async function list(date, { db = pool } = {}) {
    validDate(date);
    const rows=(await db.query(`SELECT s.*, p.direction, p.sequence_verified, v.id variant_id, v.code variant_code, v.name variant_name,
      r.id route_id,r.code route_code,r.name route_name,b.name bus_name,b.capacity,b.standing_capacity,b.gps_device_id,d.name driver_name
      FROM transport_schedules s JOIN transport_patterns p ON p.id=s.pattern_id
      JOIN transport_variants v ON v.id=p.variant_id JOIN transport_routes r ON r.id=v.route_id
      JOIN transport_buses b ON b.id=s.bus_id AND b.active JOIN transport_drivers d ON d.id=s.driver_id AND d.active
      WHERE s.active AND s.verified AND v.verified AND $1::date>=s.effective_from AND (s.effective_to IS NULL OR $1::date<=s.effective_to)
      AND EXTRACT(DOW FROM $1::date)::integer=ANY(s.service_days)
      AND NOT EXISTS(SELECT 1 FROM transport_service_exceptions e WHERE e.travel_date=$1::date)
      ORDER BY r.code,v.code,s.departure_time,s.id`,[date])).rows;
    if (!rows.length) return [];
    const stops=(await db.query(`SELECT ps.*,st.pickup_time,st.arrival_time,st.schedule_id FROM transport_stop_times st
      JOIN transport_pattern_stops ps ON ps.id=st.pattern_stop_id WHERE st.schedule_id=ANY($1::bigint[]) ORDER BY ps.sequence`,[rows.map(r=>r.id)])).rows;
    return rows.map(row=>({id:`schedule:${row.id}`,scheduleId:String(row.id),patternId:String(row.pattern_id),routeId:String(row.route_id),variantId:String(row.variant_id),variantCode:row.variant_code,
      label:row.label,route:row.variant_name,bus:row.bus_name,busId:String(row.bus_id),driver:row.driver_name,direction:row.direction,
      departureTime:hhmm(row.departure_time),arrivalTime:hhmm(row.arrival_time),bookingPeriod:row.period,
      capacity:row.capacity,standingCapacity:row.standing_capacity,requiresStops:true,dropoffSupported:row.direction==='inbound' && row.sequence_verified,
      sourceId:row.source_id,sourceVerified:row.verified,stopSequenceVerified:row.sequence_verified,
      stops:stops.filter(s=>String(s.schedule_id)===String(row.id)).map(s=>({id:String(s.id),stopId:String(s.stop_id),name:s.label,sequence:s.sequence,pickupAllowed:s.pickup_allowed,dropoffAllowed:s.dropoff_allowed,pickupTime:hhmm(s.pickup_time),arrivalTime:hhmm(s.arrival_time)}))}));
  }
  return {
    list,
    async lockForBooking(db) { await db.query('SELECT pg_advisory_xact_lock_shared($1)',[TRANSPORT_LOCK]); },
    async bookingSelection(trip,input) {
      if (!trip.requiresStops) return {};
      const pickup=trip.stops.find(s=>s.id===id(input.pickupStopId));
      const drop=input.dropoffStopId == null ? null : trip.stops.find(s=>s.id===id(input.dropoffStopId));
      if (!pickup?.pickupAllowed || !pickup.pickupTime || (input.dropoffStopId != null && !drop) ||
        (trip.dropoffSupported && !drop) || (drop && (!trip.dropoffSupported || !drop.dropoffAllowed || drop.sequence<=pickup.sequence))) throw new Member2Error('invalid_stop_selection');
      return {pickup,dropoff:drop};
    }
  };
}
