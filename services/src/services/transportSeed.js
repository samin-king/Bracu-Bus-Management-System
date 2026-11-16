import { createHash } from 'node:crypto';
import { TRANSPORT_LOCK } from './transportValidation.js';
export async function seedTransport(pool, data) {
  const db = await pool.connect();
  try {
    await db.query('BEGIN');
    await db.query('SELECT pg_advisory_xact_lock($1)', [TRANSPORT_LOCK]);
    const existing = (await db.query('SELECT image_sha256 FROM transport_sources WHERE id=$1', [data.version])).rows[0];
    if (existing) {
      if (existing.image_sha256 !== data.sourceSha256) throw new Error('Source version/hash mismatch; use a new version, never overwrite admin changes.');
      await db.query('COMMIT'); return { imported: false, reason: 'already_imported' };
    }
    await db.query('INSERT INTO transport_sources(id,effective_from,image_sha256,extraction_complete,issues) VALUES($1,$2,$3,$4,$5)', [data.version,data.effectiveFrom,data.sourceSha256,data.importComplete,JSON.stringify(data.issues)]);
    async function stop(name) {
      const key = name === 'BRAC University (arrival time)' || name === 'BRAC University' ? 'bracu-campus' : createHash('sha256').update(name.toLowerCase().replace(/\s+/g,' ').trim()).digest('hex');
      return (await db.query('INSERT INTO transport_stops(source_key,name) VALUES($1,$2) ON CONFLICT(source_key) DO UPDATE SET source_key=EXCLUDED.source_key RETURNING id', [key, name === 'BRAC University (arrival time)' ? 'BRAC University' : name])).rows[0].id;
    }
    const variants = new Map();
    for (const variant of data.variants) {
      const route = (await db.query('INSERT INTO transport_routes(code,name) VALUES($1,$2) ON CONFLICT(code) DO UPDATE SET code=EXCLUDED.code RETURNING id',[variant.routeNumber,variant.name])).rows[0];
      const v = (await db.query('INSERT INTO transport_variants(route_id,code,name,source_id,verified) VALUES($1,$2,$3,$4,$5) RETURNING id',[route.id,variant.code,variant.name+(variant.variant ? `-${variant.variant}` : ''),data.version,variant.code !== '08'])).rows[0];
      const p = (await db.query("INSERT INTO transport_patterns(variant_id,direction,sequence_verified) VALUES($1,'inbound',TRUE) RETURNING id",[v.id])).rows[0];
      const associations=[];
      for (const [index,s] of variant.stops.entries()) {
        const stopId=await stop(s.name);
        const association=(await db.query('INSERT INTO transport_pattern_stops(pattern_id,stop_id,sequence,label,pickup_allowed,dropoff_allowed) VALUES($1,$2,$3,$4,$5,$6) RETURNING id',[p.id,stopId,index+1,s.name,!s.arrival,s.arrival])).rows[0];
        associations.push(association.id);
      }
      for (const column of ['first','second']) {
        if (!variant.stops[0][column]) continue;
        const schedule=(await db.query('INSERT INTO transport_schedules(source_key,source_id,pattern_id,label,period,departure_time,arrival_time,effective_from,verified) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id',[
          `${variant.code}-inbound-${column}`,data.version,p.id,column === 'first' ? '1st Trip' : '2nd Trip',column === 'first' ? 'morning_1' : 'morning_2',variant.stops[0][column],variant.stops.at(-1)[column],data.effectiveFrom,variant.code !== '08'
        ])).rows[0];
        for (const [index,s] of variant.stops.entries()) await db.query('INSERT INTO transport_stop_times(schedule_id,pattern_stop_id,pickup_time,arrival_time) VALUES($1,$2,$3,$4)',[schedule.id,associations[index],s.arrival ? null : s[column],s.arrival ? s[column] : null]);
      }
      const out=(await db.query("INSERT INTO transport_patterns(variant_id,direction,sequence_verified) VALUES($1,'outbound',FALSE) RETURNING id",[v.id])).rows[0];
      const campus=(await db.query('INSERT INTO transport_pattern_stops(pattern_id,stop_id,sequence,label,pickup_allowed,dropoff_allowed) VALUES($1,$2,1,$3,TRUE,FALSE) RETURNING id',[out.id,await stop('BRAC University'),'BRAC University'])).rows[0];
      variants.set(variant.code,{pattern:out.id,campus:campus.id});
    }
    for (const row of data.outbound) {
      const v=variants.get(row.variantCode);
      const schedule=(await db.query('INSERT INTO transport_schedules(source_key,source_id,pattern_id,label,period,departure_time,effective_from,verified) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id',[row.key,data.version,v.pattern,row.period,row.period,row.departureTime,data.effectiveFrom,row.verified && row.variantCode !== '08'])).rows[0];
      await db.query('INSERT INTO transport_stop_times(schedule_id,pattern_stop_id,pickup_time) VALUES($1,$2,$3)',[schedule.id,v.campus,row.departureTime]);
    }
    await db.query('COMMIT'); return { imported:true,complete:data.importComplete };
  } catch (error) { await db.query('ROLLBACK'); throw error; } finally { db.release(); }
}
