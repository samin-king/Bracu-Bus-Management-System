import { randomUUID } from 'node:crypto';
import { Member2Error, validDate } from './bookingRules.js';
import { id, text, integer, boolean, scheduleInput, validateStopTimes, TRANSPORT_LOCK } from './transportValidation.js';
const hhmm = value => value == null ? null : String(value).slice(0,5);
export function createTransportService({pool}) {
  const page = query => ({page:integer(Number(query.page || 1),1,100000),size:integer(Number(query.size || 25),1,100)});
  async function ensureUnused(db, ids) {
    if ((await db.query("SELECT 1 FROM bookings WHERE schedule_id=ANY($1::bigint[]) AND status='confirmed' AND departure_at>NOW() LIMIT 1",[ids])).rows.length) throw new Member2Error('schedule_in_use',409);
  }
  async function mutate(actor,action,entity,work) {
    const db=await pool.connect();
    try {
      await db.query('BEGIN'); await db.query('SELECT pg_advisory_xact_lock($1)',[TRANSPORT_LOCK]);
      const result=await work(db);
      await db.query('INSERT INTO transport_audit(actor_id,action,entity_id,details) VALUES($1,$2,$3,$4)',[actor,action,entity == null ? null : String(entity),JSON.stringify(result)]);
      await db.query('COMMIT'); return result;
    } catch(error) {await db.query('ROLLBACK'); if(error.code==='23505') throw new Member2Error('transport_conflict',409); throw error;}
    finally {db.release();}
  }
  async function schedules(query={}) {
    const p=page(query); const values=[];const filters=[];
    if(query.variantId) {values.push(id(query.variantId));filters.push(`p.variant_id=$${values.length}`);}
    if(query.date) {validDate(query.date);values.push(query.date);const n=values.length; filters.push(`$${n}::date>=s.effective_from AND (s.effective_to IS NULL OR $${n}::date<=s.effective_to) AND EXTRACT(DOW FROM $${n}::date)::integer=ANY(s.service_days)`);}
    if(query.direction) {if(!['inbound','outbound'].includes(query.direction)) throw new Member2Error('invalid_direction');values.push(query.direction);filters.push(`p.direction=$${values.length}`);}
    values.push(p.size+1,(p.page-1)*p.size);
    const rows=(await pool.query(`SELECT s.*,s.effective_from::text effective_from,s.effective_to::text effective_to,p.direction,p.sequence_verified,p.variant_id,v.name variant_name,v.code variant_code,v.verified variant_verified,b.name bus_name,d.name driver_name,
      NOT EXISTS(SELECT 1 FROM transport_service_exceptions e WHERE e.travel_date=${query.date ? `$${query.variantId ? 2 : 1}::date` : 'CURRENT_DATE'}) service_available
      FROM transport_schedules s JOIN transport_patterns p ON p.id=s.pattern_id JOIN transport_variants v ON v.id=p.variant_id
      LEFT JOIN transport_buses b ON b.id=s.bus_id LEFT JOIN transport_drivers d ON d.id=s.driver_id
      ${filters.length ? 'WHERE '+filters.join(' AND ') : ''} ORDER BY v.code,s.departure_time,s.id LIMIT $${values.length-1} OFFSET $${values.length}`,values)).rows;
    return {items:rows.slice(0,p.size).map(s=>({...s,id:String(s.id),pattern_id:String(s.pattern_id),variant_id:String(s.variant_id),departure_time:hhmm(s.departure_time),arrival_time:hhmm(s.arrival_time)})),page:p.page,hasMore:rows.length>p.size};
  }
  async function pattern(patternId) {
    const item=(await pool.query('SELECT p.*,v.name variant_name,v.code variant_code FROM transport_patterns p JOIN transport_variants v ON v.id=p.variant_id WHERE p.id=$1',[id(patternId)])).rows[0];
    if(!item) throw new Member2Error('not_found',404);
    const stops=(await pool.query('SELECT ps.*,s.latitude,s.longitude,s.coordinate_reference FROM transport_pattern_stops ps JOIN transport_stops s ON s.id=ps.stop_id WHERE ps.pattern_id=$1 ORDER BY ps.sequence',[patternId])).rows;
    const times=(await pool.query('SELECT st.*,s.label,s.period FROM transport_stop_times st JOIN transport_schedules s ON s.id=st.schedule_id WHERE s.pattern_id=$1 ORDER BY s.id',[patternId])).rows;
    return {...item,id:String(item.id),stops:stops.map(s=>({...s,id:String(s.id),stop_id:String(s.stop_id),times:times.filter(t=>String(t.pattern_stop_id)===String(s.id)).map(t=>({...t,schedule_id:String(t.schedule_id),pickup_time:hhmm(t.pickup_time),arrival_time:hhmm(t.arrival_time)}))}))};
  }
  return {
    schedules,pattern,
    async routes() { return (await pool.query(`SELECT r.id route_id,r.code route_code,r.name route_name,v.id variant_id,v.code variant_code,v.name variant_name,v.verified,
      p.id pattern_id,p.direction,p.sequence_verified FROM transport_routes r JOIN transport_variants v ON v.route_id=r.id
      JOIN transport_patterns p ON p.variant_id=v.id ORDER BY r.code,v.code,p.direction`)).rows.map(r=>({...r,route_id:String(r.route_id),variant_id:String(r.variant_id),pattern_id:String(r.pattern_id)})); },
    async sources() {return (await pool.query('SELECT * FROM transport_sources ORDER BY effective_from DESC')).rows;},
    async access(userId) {return {transportAdmin:(await pool.query('SELECT 1 FROM transport_admins WHERE user_id=$1',[userId])).rows.length>0};},
    async resources(kind,query={}) {
      const tables={buses:'transport_buses',drivers:'transport_drivers',devices:'transport_gps_devices',exceptions:'transport_service_exceptions'};
      const table=Object.hasOwn(tables,kind) ? tables[kind] : null;if(!table) throw new Member2Error('not_found',404);
      const p=page(query); const rows=(await pool.query(`SELECT * FROM ${table} ORDER BY ${kind==='exceptions' ? 'travel_date' : 'id'} LIMIT $1 OFFSET $2`,[p.size+1,(p.page-1)*p.size])).rows;
      return {items:rows.slice(0,p.size),page:p.page,hasMore:rows.length>p.size};
    },
    async resource(actor,kind,input,resourceId=null) {
      return mutate(actor,`save_${kind}`,resourceId,async db=>{
        if(kind==='exceptions') {
          const date=validDate(input.travelDate); const reason=text(input.reason);
          return (await db.query('INSERT INTO transport_service_exceptions(travel_date,reason) VALUES($1,$2) ON CONFLICT(travel_date) DO UPDATE SET reason=EXCLUDED.reason RETURNING *',[date,reason])).rows[0];
        }
        const resource=resourceId ? id(resourceId) : null;
        if(resource && kind==='buses') await ensureUnused(db,(await db.query('SELECT id FROM transport_schedules WHERE bus_id=$1',[resource])).rows.map(s=>s.id));
        if(resource && kind==='drivers') await ensureUnused(db,(await db.query('SELECT id FROM transport_schedules WHERE driver_id=$1',[resource])).rows.map(s=>s.id));
        let table,columns,values;
        if(kind==='buses') {table='transport_buses';columns=['registration','name','capacity','standing_capacity','gps_device_id','active'];values=[text(input.registration,100),text(input.name,150),integer(input.capacity,1,200),integer(input.standingCapacity??0,0,200),input.gpsDeviceId ? id(input.gpsDeviceId) : null,boolean(input.active)];}
        else if(kind==='drivers') {table='transport_drivers';columns=['name','staff_reference','active'];values=[text(input.name,150),text(input.staffReference,150),boolean(input.active)];}
        else if(kind==='devices') {table='transport_gps_devices';columns=['external_id','provider','active'];values=[text(input.externalId,150),'traccar',boolean(input.active)];}
        else throw new Member2Error('not_found',404);
        const sql=resource ? `UPDATE ${table} SET ${columns.map((c,i)=>`${c}=$${i+1}`).join(',')} WHERE id=$${values.length+1} RETURNING *` : `INSERT INTO ${table}(${columns.join(',')}) VALUES(${values.map((_,i)=>`$${i+1}`).join(',')}) RETURNING *`;
        const row=(await db.query(sql,resource ? [...values,resource] : values)).rows[0]; if(!row) throw new Member2Error('not_found',404);return row;
      });
    },
    async removeException(actor,date) {return mutate(actor,'remove_exception',date,async db=>{validDate(date);await db.query('DELETE FROM transport_service_exceptions WHERE travel_date=$1',[date]);return {removed:date};});},
    async saveStop(actor,associationId,input) {
      return mutate(actor,'update_stop',associationId,async db=>{
        const association=(await db.query('SELECT * FROM transport_pattern_stops WHERE id=$1',[id(associationId)])).rows[0];if(!association) throw new Member2Error('not_found',404);
        await ensureUnused(db,(await db.query('SELECT id FROM transport_schedules WHERE pattern_id=$1',[association.pattern_id])).rows.map(s=>s.id));
        const label=text(input.label); const latitude=input.latitude??null, longitude=input.longitude??null;
        if((latitude===null)!==(longitude===null) || (latitude!==null && (typeof latitude!=='number' || !Number.isFinite(latitude) || latitude< -90 || latitude>90 || typeof longitude!=='number' || !Number.isFinite(longitude) || longitude< -180 || longitude>180))) throw new Member2Error('invalid_coordinates');
        const reference=latitude===null ? null : text(input.coordinateReference);
        await db.query('UPDATE transport_stops SET latitude=$1,longitude=$2,coordinate_reference=$3 WHERE id=$4',[latitude,longitude,reference,association.stop_id]);
        return (await db.query('UPDATE transport_pattern_stops SET label=$1 WHERE id=$2 RETURNING *',[label,associationId])).rows[0];
      });
    },
    async reorder(actor,patternId,input) {
      return mutate(actor,'reorder_stops',patternId,async db=>{
        const rows=(await db.query('SELECT id FROM transport_pattern_stops WHERE pattern_id=$1 ORDER BY sequence',[id(patternId)])).rows;
        if(!rows.length) throw new Member2Error('not_found',404);
        const ordered=Array.isArray(input.stopIds) ? input.stopIds.map(id) : [];
        if(ordered.length!==rows.length || new Set(ordered).size!==rows.length || rows.some(r=>!ordered.includes(String(r.id)))) throw new Member2Error('invalid_stop_order');
        await ensureUnused(db,(await db.query('SELECT id FROM transport_schedules WHERE pattern_id=$1',[patternId])).rows.map(s=>s.id));
        for(const [index,stop] of ordered.entries()) await db.query('UPDATE transport_pattern_stops SET sequence=$1 WHERE id=$2',[index+1,stop]);
        await db.query('UPDATE transport_schedules SET active=FALSE,admin_modified=TRUE WHERE pattern_id=$1',[patternId]);
        return {patternId:String(patternId),stopIds:ordered,requiresScheduleReview:true};
      });
    },
    async saveSchedule(actor,scheduleId,input) {
      const value=scheduleInput(input);
      return mutate(actor,'save_schedule',scheduleId,async db=>{
        if(scheduleId) {
          await ensureUnused(db,[id(scheduleId)]);
          const existing = (await db.query('SELECT verified FROM transport_schedules WHERE id=$1',[scheduleId])).rows[0];
          if (!existing) throw new Member2Error('not_found',404);
          if (!existing.verified && value.verified) text(input.verificationReference,1000);
        }
        const patternRow=(await db.query('SELECT p.*,v.verified variant_verified FROM transport_patterns p JOIN transport_variants v ON v.id=p.variant_id WHERE p.id=$1',[value.patternId])).rows[0];
        if(!patternRow) throw new Member2Error('not_found',404);
        const stops=(await db.query('SELECT * FROM transport_pattern_stops WHERE pattern_id=$1 ORDER BY sequence',[value.patternId])).rows;
        const times=validateStopTimes(stops,value.stopTimes,value.departureTime,value.arrivalTime,patternRow.direction);
        if(value.active && (!value.verified || !patternRow.variant_verified || !value.busId || !value.driverId)) throw new Member2Error('trip_not_ready');
        if(value.busId && !(await db.query('SELECT 1 FROM transport_buses WHERE id=$1 AND active',[value.busId])).rows.length) throw new Member2Error('invalid_assignment');
        if(value.driverId && !(await db.query('SELECT 1 FROM transport_drivers WHERE id=$1 AND active',[value.driverId])).rows.length) throw new Member2Error('invalid_assignment');
        // Unknown outbound arrival prevents safe reuse of the same assignment on overlapping services.
        if(value.active) {
          const conflicts=(await db.query(`SELECT service_days FROM transport_schedules WHERE active AND id<>$1 AND (bus_id=$2 OR driver_id=$3)
            AND effective_from<=COALESCE($5::date,'9999-12-31'::date) AND (effective_to IS NULL OR effective_to >=$4::date)
            AND departure_time < COALESCE($7::time,'23:59:59'::time) AND COALESCE(arrival_time,'23:59:59'::time)>$6::time`,[scheduleId || 0,value.busId,value.driverId,value.effectiveFrom,value.effectiveTo,value.departureTime,value.arrivalTime])).rows;
          if(conflicts.some(c=>c.service_days.some(d=>value.serviceDays.includes(d)))) throw new Member2Error('assignment_conflict',409);
        }
        const params=[value.patternId,value.label,value.period,value.departureTime,value.arrivalTime,value.effectiveFrom,value.effectiveTo,value.serviceDays,value.busId,value.driverId,value.verified,value.active];
        let row;
        if(scheduleId) row=(await db.query('UPDATE transport_schedules SET pattern_id=$1,label=$2,period=$3,departure_time=$4,arrival_time=$5,effective_from=$6,effective_to=$7,service_days=$8,bus_id=$9,driver_id=$10,verified=$11,active=$12,admin_modified=TRUE WHERE id=$13 RETURNING *',[...params,id(scheduleId)])).rows[0];
        else row=(await db.query('INSERT INTO transport_schedules(pattern_id,label,period,departure_time,arrival_time,effective_from,effective_to,service_days,bus_id,driver_id,verified,active,source_key,admin_modified) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,TRUE) RETURNING *',[...params,`admin:${randomUUID()}`])).rows[0];
        if(!row) throw new Member2Error('not_found',404);
        await db.query('DELETE FROM transport_stop_times WHERE schedule_id=$1',[row.id]);
        for(const entry of times) await db.query('INSERT INTO transport_stop_times(schedule_id,pattern_stop_id,pickup_time,arrival_time) VALUES($1,$2,$3,$4)',[row.id,entry.patternStopId,entry.pickupTime,entry.arrivalTime]);
        return { ...row, verificationReference: input.verificationReference || null };
      });
    },
    async verifyVariant(actor,variantId,input) {return mutate(actor,'verify_variant',variantId,async db=>{
      text(input.reference,1000);
      const row=(await db.query('UPDATE transport_variants SET verified=TRUE WHERE id=$1 RETURNING *',[id(variantId)])).rows[0];if(!row) throw new Member2Error('not_found',404);
      return {...row,verificationReference:input.reference};
    });}
  };
}
