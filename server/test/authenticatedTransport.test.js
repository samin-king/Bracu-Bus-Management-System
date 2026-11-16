import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import session from 'express-session';
import connectPgSimple from 'connect-pg-simple';
import request from 'supertest';
import {migrate} from '../src/utils/database.js';
import {createAuthenticatedApp} from '../src/authenticatedApp.js';

test('real session middleware, isolated transport RBAC and driver transitions (OAuth provider test double)', async t => {
  const engine = new PGlite();
  await engine.waitReady;
  const db = {async query(sql, params) {
    const result = params ? await engine.query(sql, params) : (await engine.exec(sql)).at(-1);
    return {rows: result?.rows || [], rowCount: result?.rows?.length || 0};
  }};
  const config = {frontendUrl: 'http://127.0.0.1:8191', callbackUrl: 'http://127.0.0.1:3002/api/auth/google/callback',
    domain: 'g.bracu.ac.bd', secret: 'isolated-session-test-secret-at-least-32-characters', ttlMs: 3600000, secure: false, cookieName: 'bracu.sid'};
  let flow, subject = 'student-test', claimsOverride = {};
  const provider = {authorizationUrl(value) {flow = value; return 'https://accounts.google.com/test';},
    async verify() {return {sub: subject, email: `${subject.replaceAll('-', '.')}.account@g.bracu.ac.bd`, name: subject, email_verified: true, hd: config.domain, nonce: flow.nonce, ...claimsOverride};}};
  try {
    await db.query(await readFile(new URL('../../Bracu-Bus-Management-System/database/migrations/001_authentication.sql', import.meta.url), 'utf8'));
    await migrate(db);
    await db.query(await readFile(new URL('../integration/transport_account_roles.sql', import.meta.url), 'utf8'));
    const PgStore = connectPgSimple(session);
    const store = new PgStore({pool: db, tableName: 'auth_sessions', pruneSessionInterval: false});
    const app = createAuthenticatedApp({config, pool: db, provider, store});
    // Explicitly provision only isolated test accounts BEFORE authentication.
    for (const name of ['student-test','authority-test','driver-test']) {
      await db.query("INSERT INTO users(google_subject,name,email,role) VALUES($1,$2,$3,'student')",
        [name,name,`${name.replaceAll('-', '.')}.account@g.bracu.ac.bd`]);
    }
    const userId = async name => (await db.query('SELECT id FROM users WHERE google_subject=$1', [name])).rows[0].id;
    await db.query("INSERT INTO transport_account_roles(user_id,role) VALUES($1,'authority')", [await userId('authority-test')]);
    const login = async value => {
      subject = value;
      const agent = request.agent(app);
      await agent.get('/api/auth/google').expect(302);
      const response = await agent.get(`/api/auth/google/callback?state=${flow.state}&code=test-only`).expect(302);
      if (response.headers.location === config.frontendUrl + '/') {
        assert.ok(response.headers['set-cookie'].some(value => /HttpOnly/.test(value) && /SameSite=Lax/.test(value)));
      }
      return agent;
    };
    const student = await login('student-test');
    const authority = await login('authority-test');
    const write = (agent, method, path, body) => agent[method]('/api/' + path).set('Origin', config.frontendUrl).send(body);
    await t.test('anonymous requests and forged identity cannot access management', async () => {
      for (const path of ['buses','routes','trips','drivers','session']) await request(app).get('/api/'+path).set('x-driver-id','1').expect(401);
      assert.equal((await student.get('/api/session').expect(200)).body.role, 'student');
      for (const path of ['buses','routes','trips','drivers','drivers/me']) await student.get('/api/'+path).set('x-role','authority').expect(403);
      await write(student,'put','trips/1/driver',{driver_id:1}).expect(403);
    });
    const driver = (await write(authority,'post','drivers',{name:'Isolated Driver',license_number:'ISOLATED-DL'}).expect(201)).body;
    await db.query("INSERT INTO transport_account_roles(user_id,role,driver_id) VALUES($1,'driver',$2)", [await userId('driver-test'),driver.id]);
    const driverAgent = await login('driver-test');
    await t.test('existing authorized roles and session refresh preserve assigned accounts', async () => {
      for (const [agent, role] of [[student,'student'],[authority,'authority'],[driverAgent,'driver']]) {
        for (let refresh=0;refresh<2;refresh++) {
          const me = (await agent.get('/api/auth/me').expect(200)).body;
          assert.equal(me.role,role); assert.equal(me.google_subject,undefined);
        }
      }
      assert.equal((await db.query('SELECT count(*)::int AS count FROM users')).rows[0].count,3);
    });
    await t.test('unknown, unverified and mismatched accounts never register or gain sessions', async () => {
      const unknown = await login('unknown-test');
      await unknown.get('/api/auth/me').expect(401);
      claimsOverride = {email_verified:false};
      const unverified = await login('student-test');
      await unverified.get('/api/auth/me').expect(401);
      claimsOverride = {email:'other.person@g.bracu.ac.bd'};
      const mismatch = await login('student-test');
      await mismatch.get('/api/auth/me').expect(401);
      claimsOverride = {};
      assert.equal((await db.query('SELECT count(*)::int AS count FROM users')).rows[0].count,3);
      assert.equal((await authority.get('/api/auth/me').expect(200)).body.role,'authority');
    });
    const bus = (await write(authority,'post','buses',{bus_number:'ISOLATED-BUS',capacity:37}).expect(201)).body;
    const route = (await write(authority,'post','routes',{route_name:'Isolated route',origin:'A',destination:'B',stops:['A','B']}).expect(201)).body;
    const trip = (await write(authority,'post','trips',{bus_id:bus.id,route_id:route.id,travel_date:'2026-11-17',departure_time:'06:30',status:'SCHEDULED'}).expect(201)).body;
    await t.test('Authority modules list/detail/edit, origin protection and assignment', async () => {
      for (const [path,record] of [['buses',bus],['routes',route],['trips',trip],['drivers',driver]]) {
        await authority.get('/api/'+path).expect(200);
        await authority.get(`/api/${path}/${record.id}`).expect(200);
        await driverAgent.get('/api/'+path).expect(403);
      }
      await authority.post('/api/buses').set('Origin','https://untrusted.example').send({bus_number:'BAD',capacity:1}).expect(403);
      await write(authority,'put',`buses/${bus.id}`,{bus_number:'ISOLATED-BUS',capacity:28}).expect(200);
      await write(authority,'put',`routes/${route.id}`,{route_name:'Isolated route updated',origin:'A',destination:'B',stops:['A','B']}).expect(200);
      await write(authority,'put',`drivers/${driver.id}`,{name:'Isolated Driver updated',license_number:'ISOLATED-DL',status:'ACTIVE'}).expect(200);
      await write(authority,'put',`trips/${trip.id}`,{bus_id:bus.id,route_id:route.id,travel_date:'2026-11-17',departure_time:'06:30',status:'SCHEDULED'}).expect(200);
      await write(authority,'put',`trips/${trip.id}/driver`,{driver_id:driver.id}).expect(200);
      await write(authority,'put',`trips/${trip.id}/driver`,{driver_id:null}).expect(200);
      await write(authority,'put',`trips/${trip.id}/driver`,{driver_id:driver.id}).expect(200);
      await write(driverAgent,'put',`trips/${trip.id}/driver`,{driver_id:null}).expect(403);
      await authority.get('/api/drivers/me').expect(403);
    });
    await t.test('Driver identity comes from session mapping; actual trip Start/Stop and ownership', async () => {
      assert.equal((await driverAgent.get('/api/session').expect(200)).body.role,'driver');
      assert.equal((await driverAgent.get('/api/drivers/me').expect(200)).body.id,driver.id);
      assert.equal((await driverAgent.get('/api/drivers/me/trips').expect(200)).body.length,1);
      await driverAgent.get(`/api/drivers/${driver.id+1}/trips`).expect(403);
      await write(authority,'post',`trips/${trip.id}/start`,{}).expect(403);
      const started = (await write(driverAgent,'post',`trips/${trip.id}/start`,{}).expect(200)).body;
      assert.equal(started.status,'ACTIVE'); assert.ok(started.started_at);
      await write(driverAgent,'post',`trips/${trip.id}/start`,{}).expect(409);
      const stopped = (await write(driverAgent,'post',`trips/${trip.id}/stop`,{}).expect(200)).body;
      assert.equal(stopped.status,'COMPLETED'); assert.ok(stopped.completed_at);
      await write(driverAgent,'post',`trips/${trip.id}/stop`,{}).expect(409);
    });
    await t.test('role revocation and logout take effect on the backend', async () => {
      await db.query('DELETE FROM transport_account_roles WHERE user_id=$1',[await userId('authority-test')]);
      await authority.get('/api/buses').expect(403);
      await driverAgent.post('/api/auth/logout').set('Origin','https://untrusted.example').expect(403);
      await driverAgent.post('/api/auth/logout').set('Origin',config.frontendUrl).expect(204);
      await driverAgent.get('/api/session').expect(401);
      await write(driverAgent,'post',`trips/${trip.id}/start`,{}).expect(401);
    });
    await t.test('expired sessions and tampered cookies are rejected', async () => {
      await db.query("UPDATE auth_sessions SET sess=jsonb_set(sess::jsonb,'{authExpiresAt}','1'::jsonb)::json");
      await student.get('/api/session').expect(401);
      await request(app).get('/api/session').set('Cookie','bracu.sid=s:forged.invalid').expect(401);
    });
  } finally {await engine.close();}
});
