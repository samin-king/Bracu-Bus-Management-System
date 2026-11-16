import test from 'node:test';
import { migrate } from '../../server/src/utils/database.js';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import session from 'express-session';
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { createApp } from '../src/app.js';
import { seedTransport } from '../src/services/transportSeed.js';
import { createBookingTripCatalog } from '../src/services/bookingTripCatalog.js';
import { createTransportCatalog } from '../src/services/transportCatalog.js';
import { createTransportService } from '../src/services/transportService.js';
import { bookingWindow } from '../src/services/bookingRules.js';
const require=createRequire(import.meta.url);const {sign}=require('cookie-signature');
const data=JSON.parse(await readFile(new URL('../../database/seeds/bracu-2026-10-03.json',import.meta.url),'utf8'));
async function setup(t) {
  const db=new PGlite();let tail=Promise.resolve();
  const acquire=async()=>{let release;const previous=tail;tail=new Promise(r=>{release=r;});await previous;return release;};
  const pool={async query(...args){const release=await acquire();try{return await db.query(...args);}finally{release();}},async connect(){const release=await acquire();return {query:(...args)=>db.query(...args),release};}};
  t.after(()=>db.close());
  await migrate({query: (sql, params) => params ? db.query(sql, params) : db.exec(sql)});
  await seedTransport(pool,data);
  const users=(await pool.query("INSERT INTO users(google_subject,name,email,gender,gender_verified) VALUES('admin','Admin','audit.admin@g.bracu.ac.bd','female',true),('student','Student','audit.student@g.bracu.ac.bd','male',true) RETURNING id")).rows;
  await pool.query('INSERT INTO transport_admins(user_id) VALUES($1)',[users[0].id]);
  const config={frontendUrl:'http://test.local',callbackUrl:'http://test.local/api/auth/google/callback',domain:'g.bracu.ac.bd',secret:'transport-test-secret-more-than-32-characters',cookieName:'sid',ttlMs:3600000,secure:false};
  const store=new session.MemoryStore();const cookies=[];
  for(const u of users){const sid=randomUUID();await new Promise(r=>store.set(sid,{cookie:{maxAge:3600000},userId:u.id,authExpiresAt:Date.now()+3600000},r));cookies.push('sid='+encodeURIComponent('s:'+sign(sid,config.secret)));}
  const app=createApp({config,pool,store,tripCatalog:createBookingTripCatalog(pool, {}),clock:()=>new Date('2030-01-02T05:00:00+06:00')});
  const service=createTransportService({pool});
  const get=(path,who=1)=>request(app).get(path).set('Cookie',cookies[who]);
  const write=(method,path,body,who=0)=>request(app)[method](path).set('Cookie',cookies[who]).set('Origin',config.frontendUrl).send(body);
  const schedules=(await service.schedules({size:100})).items;
  async function ready(key='01-A-inbound-first', overrides={}) {
    const s=schedules.find(s=>s.source_key===key);const p=await service.pattern(s.pattern_id);
    const bus=await service.resource(users[0].id,'buses',{registration:randomUUID(),name:'Real fixture bus',capacity:37,standingCapacity:2,active:true});
    const driver=await service.resource(users[0].id,'drivers',{name:'Fixture driver',staffReference:randomUUID(),active:true});
    const input={patternId:s.pattern_id,label:s.label,period:s.period,departureTime:s.departure_time,arrivalTime:s.arrival_time,effectiveFrom:'2026-10-03',effectiveTo:null,serviceDays:[0,1,2,3,4,6],busId:String(bus.id),driverId:String(driver.id),verified:true,active:true,
      stopTimes:p.stops.map(stop=>{const time=stop.times.find(time=>time.schedule_id===s.id);return {patternStopId:stop.id,pickupTime:time.pickup_time,arrivalTime:time.arrival_time};}),...overrides};
    await service.saveSchedule(users[0].id,s.id,input);return {schedule:s,pattern:p,input};
  }
  return {db,pool,app,get,write,service,users,ready,schedules,cookies,config};
}
test('source extraction preserves 12 variants, exact ordered stop/times and missing trips; idempotent seed',async t=>{
  const s=await setup(t);assert.equal((await s.service.routes()).length,24);assert.equal(s.schedules.length,42);
  for(const variant of data.variants) {
    const route=(await s.service.routes()).find(r=>r.variant_code===variant.code&&r.direction==='inbound');const p=await s.service.pattern(route.pattern_id);
    assert.deepEqual(p.stops.map(stop=>stop.label),variant.stops.map(stop=>stop.name));
    assert.deepEqual(p.stops.map(stop=>stop.sequence),variant.stops.map((_,i)=>i+1));
    for(const [column,label] of [['first','1st Trip'],['second','2nd Trip']]) {
      const schedules=s.schedules.filter(item=>item.variant_code===variant.code&&item.direction==='inbound'&&item.label===label);
      assert.equal(schedules.length,variant.stops[0][column]?1:0);
      if(!schedules.length) continue;
      for(const [index,stop] of p.stops.entries()) {
        const entry=stop.times.find(time=>time.schedule_id===schedules[0].id);
        assert.equal(entry.pickup_time||entry.arrival_time,variant.stops[index][column]);
        assert.equal(Boolean(entry.arrival_time),variant.stops[index].arrival);
      }
    }
  }
  for(const row of data.outbound) assert.equal(s.schedules.find(s=>s.source_key===row.key).departure_time,row.departureTime);
  assert.equal(s.schedules.find(s=>s.source_key==='03-A-outbound-evening-2').verified,false);
  assert.equal(s.schedules.filter(s=>s.active).length,0);
  assert.equal((await seedTransport(s.pool,data)).imported,false);
  assert.equal((await s.service.schedules({size:100})).items.length,42);
  assert.equal(Number((await s.pool.query('SELECT COUNT(*) FROM transport_stops WHERE latitude IS NOT NULL')).rows[0].count),0);
});
test('student routes/searchable pattern metadata and admin authorization, origin and pagination',async t=>{
  const s=await setup(t);
  await request(s.app).get('/api/student/transport/routes').expect(401);
  const routes=(await s.get('/api/student/transport/routes').expect(200)).body;assert.equal(routes.length,24);
  await s.get('/api/transport-admin/routes').expect(403);
  await s.get('/api/transport-admin/routes',0).expect(200);
  const result=(await s.get('/api/transport-admin/schedules?size=2',0).expect(200)).body;assert.equal(result.items.length,2);assert.equal(result.hasMore,true);
  await s.get('/api/student/transport/schedules?size=101').expect(400);
  await s.get('/api/transport-admin/resources/constructor',0).expect(404);
  await s.get('/api/student/transport/patterns/9999999999999999999').expect(400);
  await request(s.app).put('/api/transport-admin/variants/1/verification').set('Cookie',s.cookies[0]).set('Origin','http://evil.test').send({reference:'x'}).expect(403);
});
test('official pickup/departure separated from arrival; original policy periods retained',()=>{
  const morning=bookingWindow({departureTime:'06:20',bookingPeriod:'morning_1'},'2030-01-02');
  assert.equal(morning.opensAt.toISOString(),'2030-01-01T14:00:00.000Z');assert.equal(morning.closesAt.toISOString(),'2030-01-02T00:20:00.000Z');
  assert.equal(bookingWindow({departureTime:'14:05',bookingPeriod:'afternoon'},'2030-01-02').closesAt.toISOString(),'2030-01-02T05:15:00.000Z');
});
test('assigned trip booking validates association, sequence and snapshot; rejects tampering; cancellation retains selection',async t=>{
  const s=await setup(t);const {pattern}=await s.ready();
  const trips=(await s.get('/api/student/trips?date=2030-01-02').expect(200)).body;assert.equal(trips.length,1);const trip=trips[0];
  assert.equal(trip.departureTime,'06:40');assert.equal(trip.arrivalTime,'07:30');
  const input={tripId:trip.id,travelDate:'2030-01-02',seatNumber:19,standing:false,pickupStopId:pattern.stops[0].id,dropoffStopId:pattern.stops.at(-1).id};
  await s.write('post','/api/student/bookings',{...input,pickupStopId:pattern.stops.at(-1).id},1).expect(400);
  const other=s.schedules.find(x=>x.source_key==='02-A-inbound-first');const otherPattern=await s.service.pattern(other.pattern_id);
  await s.write('post','/api/student/bookings',{...input,pickupStopId:otherPattern.stops[0].id},1).expect(400);
  await s.write('post','/api/student/bookings',{...input,dropoffStopId:null},1).expect(400);
  const booking=(await s.write('post','/api/student/bookings',input,1).expect(201)).body;
  assert.equal(booking.trip_snapshot.pickup.name,pattern.stops[0].label);assert.equal(booking.trip_snapshot.pickup.pickupTime,'06:40');assert.equal(booking.trip_snapshot.dropoff.name,'BRAC University (arrival time)');
  await s.write('post','/api/student/bookings',input,1).expect(409);
  const cancel=(await s.write('post',`/api/student/bookings/${booking.id}/cancel`,{},1).expect(200)).body;assert.equal(cancel.status,'cancelled');assert.equal(cancel.pickup_stop_id,booking.pickup_stop_id);
});
test('missing trips, Friday, effective dates and calendar closure exclude booking candidates',async t=>{
  const s=await setup(t);assert.deepEqual((await s.get('/api/student/trips?date=2030-01-02')).body,[]);
  await s.ready();assert.equal((await s.get('/api/student/trips?date=2030-01-04')).body.length,0);
  assert.equal((await s.get('/api/student/trips?date=2026-10-01')).body.length,0);
  await s.service.resource(s.users[0].id,'exceptions',{travelDate:'2030-01-02',reason:'University closure'});
  assert.equal((await s.get('/api/student/trips?date=2030-01-02')).body.length,0);
});
test('admin edits are reflected, reorder is transactional, duplicate reimport preserves edits, active schedules validate times',async t=>{
  const s=await setup(t);const row=s.schedules.find(x=>x.source_key==='02-A-inbound-first');const p=await s.service.pattern(row.pattern_id);
  await s.service.saveStop(s.users[0].id,p.stops[0].id,{label:'Verified renamed stop'});
  await seedTransport(s.pool,data);assert.equal((await s.service.pattern(p.id)).stops[0].label,'Verified renamed stop');
  await assert.rejects(s.service.reorder(s.users[0].id,p.id,{stopIds:[p.stops[0].id]}),/invalid_stop_order/);
  assert.equal((await s.service.pattern(p.id)).stops[0].label,'Verified renamed stop');
  await s.service.reorder(s.users[0].id,p.id,{stopIds:p.stops.map(x=>x.id).reverse()});
  assert.equal((await s.service.pattern(p.id)).stops[0].id,p.stops.at(-1).id);
  const ready=await s.ready('01-A-inbound-first');
  await assert.rejects(s.service.saveSchedule(s.users[0].id,ready.schedule.id,{...ready.input,stopTimes:ready.input.stopTimes.slice(1)}),/invalid_stop_times/);
  assert.equal((await s.pool.query('SELECT COUNT(*) FROM transport_audit')).rows[0].count>0,true);
});
test('additive migration preserves legacy bookings and snapshots',async t=>{
  const db=new PGlite();t.after(()=>db.close());
  for(const file of ['001_authentication.sql','002_member2.sql']) await db.exec(await readFile(new URL('../../database/migrations/'+file,import.meta.url),'utf8'));
  const user=(await db.query("INSERT INTO users(google_subject,name,email) VALUES('legacy','Legacy','legacy.student@g.bracu.ac.bd') RETURNING id")).rows[0];
  await db.query("INSERT INTO bookings(student_id,trip_id,travel_date,departure_at,trip_snapshot,capacity,seat_number) VALUES($1,'legacy','2030-01-02','2030-01-02T08:00:00Z','{\"route\":\"Legacy route\"}',37,19)",[user.id]);
  await db.exec(await readFile(new URL('../../database/migrations/003_transport_schedule.sql',import.meta.url),'utf8'));
  const row=(await db.query('SELECT * FROM bookings')).rows[0];assert.equal(row.trip_snapshot.route,'Legacy route');assert.equal(row.schedule_id,null);assert.equal(row.seat_number,19);
});
test('unverified entries stay unavailable, and verification needs a reference',async t=>{
  const s=await setup(t);
  await assert.rejects(s.ready('08-inbound-first',{verificationReference:'Official header confirmation'}),/trip_not_ready/);
  await assert.rejects(s.ready('03-A-outbound-evening-2'),/invalid_transport_input/);
  assert.equal((await s.get('/api/student/trips?date=2030-01-02')).body.length,0);
});
test('outbound does not invent drop-offs; admin updates cannot mutate future confirmed bookings',async t=>{
  const s=await setup(t);const ready=await s.ready();
  const trip=(await s.get('/api/student/trips?date=2030-01-02')).body[0];
  await s.write('post','/api/student/bookings',{tripId:trip.id,travelDate:'2030-01-02',seatNumber:19,pickupStopId:ready.pattern.stops[0].id,dropoffStopId:ready.pattern.stops.at(-1).id},1).expect(201);
  await assert.rejects(s.service.saveSchedule(s.users[0].id,ready.schedule.id,{...ready.input,active:false}),/schedule_in_use/);
  await assert.rejects(s.service.reorder(s.users[0].id,ready.pattern.id,{stopIds:ready.pattern.stops.map(x=>x.id).reverse()}),/schedule_in_use/);
  const outbound=s.schedules.find(s=>s.source_key==='01-A-outbound-evening-1');
  const p=await s.service.pattern(outbound.pattern_id);assert.equal(p.sequence_verified,false);assert.equal(p.stops.length,1);assert.equal(p.stops[0].dropoff_allowed,false);
});
test('assignment overlaps and malformed stop-time elements are rejected without partial changes',async t=>{
  const s=await setup(t);const first=await s.ready();const other=s.schedules.find(x=>x.source_key==='02-A-inbound-first');const p=await s.service.pattern(other.pattern_id);
  const input={...first.input,patternId:p.id,departureTime:other.departure_time,arrivalTime:other.arrival_time,stopTimes:p.stops.map(stop=>{const t=stop.times.find(t=>t.schedule_id===other.id);return {patternStopId:stop.id,pickupTime:t.pickup_time,arrivalTime:t.arrival_time};})};
  await assert.rejects(s.service.saveSchedule(s.users[0].id,other.id,input),/assignment_conflict/);
  await assert.rejects(s.service.saveSchedule(s.users[0].id,other.id,{...input,stopTimes:input.stopTimes.map(()=>null)}),/invalid_stop_times/);
  assert.equal((await s.pool.query('SELECT active FROM transport_schedules WHERE id=$1',[other.id])).rows[0].active,false);
});

test('merged catalog keeps Member 3 trips and official schedules bookable through the same API', async t => {
  const s = await setup(t);
  await s.ready();
  const bus = (await s.pool.query("INSERT INTO buses(bus_number,capacity) VALUES('MERGE-01',37) RETURNING id")).rows[0];
  const route = (await s.pool.query("INSERT INTO routes(route_name,origin,destination) VALUES('Existing Member 3 route','City','Campus') RETURNING id")).rows[0];
  const trip = (await s.pool.query("INSERT INTO trips(bus_id,route_id,travel_date,departure_time) VALUES($1,$2,'2030-01-02','06:30') RETURNING id", [bus.id, route.id])).rows[0];
  const trips = (await s.get('/api/student/trips?date=2030-01-02').expect(200)).body;
  assert.ok(trips.some(item => item.id === String(trip.id)));
  assert.ok(trips.some(item => item.id.startsWith('schedule:')));
  const booking = (await s.write('post', '/api/student/bookings', {tripId:String(trip.id),travelDate:'2030-01-02',seatNumber:19}, 1).expect(201)).body;
  assert.equal(booking.trip_id, String(trip.id));
  assert.equal(booking.status, 'confirmed');
});
