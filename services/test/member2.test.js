import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import request from 'supertest';
import session from 'express-session';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/app.js';
import { createTripCatalog } from '../src/services/tripCatalog.js';
import { windowOpen } from '../src/services/bookingRules.js';
const config = { frontendUrl: 'http://localhost:5173', callbackUrl: 'http://localhost:3000/api/auth/google/callback', domain: 'g.bracu.ac.bd', secret: 'member2-test-session-secret-over-32-characters', cookieName: 'sid', ttlMs: 3600000, secure: false };
const date = '2030-01-02';
const trips = Array.from({ length: 6 }, (_, i) => ({ id: `trip-${i}`, bus: `Bus ${i}`, route: 'Campus → City', departureTime: '14:00', capacity: i === 5 ? 28 : 37, standingCapacity: 2 }));
const migration = async (db, name) => {
  const sql = await readFile(new URL(`../../database/migrations/${name}`, import.meta.url), 'utf8');
  if (db.exec) await db.exec(sql); else await db.query(sql);
};
async function setup(t, real = false) {
  let db, pool;
  if (real) {
    const schema = `m2_${randomUUID().replaceAll('-', '')}`;
    const admin = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL });
    await admin.query(`CREATE SCHEMA ${schema}`);
    pool = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL, options: `-c search_path=${schema}` });
    db = pool;
    t.after(async () => { await pool.end(); await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  } else {
    db = new PGlite();
    // PGlite has one connection. Serialize each complete transaction, never
    // interleave BEGIN/COMMIT. This does not simulate PostgreSQL MVCC races.
    let tail = Promise.resolve();
    const acquire = async () => {
      let release; const previous = tail; tail = new Promise(resolve => { release = resolve; });
      await previous; return release;
    };
    pool = {
      async query(...args) { const release = await acquire(); try { return await db.query(...args); } finally { release(); } },
      async connect() { const release = await acquire(); return { query: (...args) => db.query(...args), release }; }
    };
    t.after(() => db.close());
  }
  await migration(db, '001_authentication.sql'); await migration(db, '002_member2.sql');
  const users = (await db.query(`INSERT INTO users(google_subject,name,email,gender) VALUES
    ('one','Student One','student.one@g.bracu.ac.bd','female'),
    ('two','Student Two','student.two@g.bracu.ac.bd','male'),
    ('three','Student Three','student.three@g.bracu.ac.bd',NULL) RETURNING id`)).rows;
  const store = new session.MemoryStore();
  let now = new Date('2030-01-02T11:00:00+06:00');
  let flow;
  const provider = {
    authorizationUrl(value) { flow = value; return 'https://accounts.google.com'; },
    async verify() { return { sub: 'one', name: 'Student One', email: 'student.one@g.bracu.ac.bd', email_verified: true, hd: config.domain, nonce: flow.nonce }; }
  };
  const app = createApp({ config, pool, store, provider, tripCatalog: createTripCatalog(trips), clock: () => now });
  async function student(index) {
    // Test-only signed session fixture; no bypass route exists in the application.
    const { sign } = await import('cookie-signature');
    const sid = randomUUID();
    await new Promise((resolve, reject) => store.set(sid, { cookie: { maxAge: 3600000 }, userId: users[index].id, authExpiresAt: Date.now() + 3600000 }, error => error ? reject(error) : resolve()));
    return `sid=${encodeURIComponent(`s:${sign(sid, config.secret)}`)}`;
  }
  const cookies = await Promise.all([student(0), student(1), student(2)]);
  const get = (path, who = 0) => request(app).get(`/api/student${path}`).set('Cookie', cookies[who]);
  const post = (path, body = {}, who = 0) => request(app).post(`/api/student${path}`).set('Cookie', cookies[who]).set('Origin', config.frontendUrl).send(body);
  const book = (overrides = {}, who = 0) => post('/bookings', { tripId: 'trip-0', travelDate: date, seatNumber: 19, ...overrides }, who);
  return { db, app, cookies, get, post, book, users, get flow() { return flow; }, setNow: value => { now = new Date(value); } };
}
test('booking APIs: authentication, trusted identity, invalid input and seat protection', async t => {
  const s = await setup(t);
  await request(s.app).post('/api/student/bookings').send({}).expect(401);
  await s.book({ tripId: 'missing' }).expect(404);
  for (const seatNumber of [0, -1, 38, '19', null, 1.2]) await s.book({ seatNumber }).expect(400);
  await s.book({ travelDate: '2030-02-30' }).expect(400);
  const booking = (await s.book({ student_id: s.users[1].id }).expect(201)).body;
  assert.equal(String(booking.student_id), String(s.users[0].id));
  await s.book({}, 1).expect(409);
  await s.get(`/bookings/${booking.id}`).expect(200);
  await s.get(`/bookings/${booking.id}`, 1).expect(403);
  assert.equal((await s.get('/bookings', 1)).body.length, 0);
  const seats = (await s.get(`/trips/trip-0/seats?date=${date}`, 1)).body;
  assert.equal(seats.seats.length, 37);
  assert.equal(seats.seats[18].state, 'Booked');
  assert.equal(seats.seats[0].selectable, false);
  assert.equal((await s.get(`/trips/trip-5/seats?date=${date}`)).body.seats.length, 28);
  await request(s.app).post('/api/student/bookings').set('Cookie', s.cookies[0]).set('Origin', 'https://evil.example').send({}).expect(403);
});
test('booking window enforced on server; closed trips remain visible', async t => {
  const s = await setup(t); s.setNow('2030-01-02T11:15:00+06:00');
  await s.book().expect(409);
  assert.equal((await s.get(`/trips?date=${date}`)).body[0].bookingOpen, false);
});
test('Dhaka window boundaries and previous-day morning openings', () => {
  for (const [departureTime, open, close] of [['14:00', '2030-01-02T10:50', '2030-01-02T11:15'], ['17:00', '2030-01-02T15:20', '2030-01-02T15:40'], ['06:30', '2030-01-01T20:00', '2030-01-02T06:30'], ['08:30', '2030-01-01T21:00', '2030-01-02T08:30']]) {
    const trip = { departureTime }, start = new Date(`${open}:00+06:00`), end = new Date(`${close}:00+06:00`);
    assert.equal(windowOpen(trip, date, new Date(start.getTime() - 1)), false);
    assert.equal(windowOpen(trip, date, start), true);
    assert.equal(windowOpen(trip, date, new Date(end.getTime() - 1)), true);
    assert.equal(windowOpen(trip, date, end), false);
  }
});
test('four-trip limit, ownership, cancellation and released seat', async t => {
  const s = await setup(t);
  const bookings = [];
  for (let i = 0; i < 4; i++) bookings.push((await s.book({ tripId: `trip-${i}` }).expect(201)).body);
  await s.book({ tripId: 'trip-4' }).expect(409);
  await s.post(`/bookings/${bookings[0].id}/cancel`, {}, 1).expect(403);
  await s.post(`/bookings/${bookings[0].id}/cancel`).expect(200);
  await s.post(`/bookings/${bookings[0].id}/cancel`).expect(409);
  await s.book({}, 1).expect(201);
  await s.book({ tripId: 'trip-4' }).expect(201);
  assert.equal((await s.get('/bookings')).body.filter(b => b.section === 'Cancelled').length, 1);
  s.setNow('2030-01-02T14:00:00+06:00');
  await s.post(`/bookings/${bookings[1].id}/cancel`).expect(409);
  assert.equal((await s.get('/bookings')).body.filter(b => b.section === 'Past').length, 4);
});
test('gender restrictions and standing capacity are enforced using stored profile', async t => {
  const s = await setup(t);
  await s.book({ seatNumber: 1, gender: 'female' }, 1).expect(403);
  await s.book({ seatNumber: 1 }, 2).expect(403);
  await s.book({ seatNumber: 1 }).expect(201);
  await s.book({ standing: true, seatNumber: null }).expect(403);
  await s.book({ standing: true, seatNumber: null }, 1).expect(201);
  await s.book({ standing: true, seatNumber: 19, tripId: 'trip-1' }, 1).expect(400);
});
test('complaints: validation, ownership, own list and immutable status', async t => {
  const s = await setup(t);
  const input = { category: 'Late bus', subject: 'Delayed departure', description: 'Bus left late.' };
  await request(s.app).post('/api/student/complaints').send(input).expect(401);
  for (const value of [{}, { ...input, category: 'bad' }, { ...input, subject: ' ' }, { ...input, description: 'x'.repeat(5001) }]) await s.post('/complaints', value).expect(400);
  const booking = (await s.book().expect(201)).body;
  await s.post('/complaints', { ...input, bookingId: booking.id }, 1).expect(403);
  await s.post('/complaints', { ...input, tripId: 'missing' }).expect(400);
  const complaint = (await s.post('/complaints', { ...input, bookingId: booking.id, status: 'Resolved', student_id: s.users[1].id }).expect(201)).body;
  assert.equal(complaint.status, 'Pending');
  await s.get(`/complaints/${complaint.id}`).expect(200);
  await s.get(`/complaints/${complaint.id}`, 1).expect(403);
  assert.equal((await s.get('/complaints')).body.length, 1);
  assert.equal((await s.get('/complaints', 1)).body.length, 0);
  await request(s.app).patch(`/api/student/complaints/${complaint.id}`).set('Cookie', s.cookies[0]).set('Origin', config.frontendUrl).send({ status: 'Resolved' }).expect(404);
});
test('simultaneous booking requests yield one success and one conflict (embedded PostgreSQL)', async t => {
  const s = await setup(t);
  const results = await Promise.all([s.book(), s.book({}, 1)]);
  assert.deepEqual(results.map(r => r.status).sort(), [201, 409]);
  assert.equal(Number((await s.db.query("SELECT count(*) FROM bookings WHERE status='confirmed'")).rows[0].count), 1);
});
test('database trigger rejects a fifth confirmed trip outside the API', async t => {
  const s = await setup(t);
  for (let i = 0; i < 4; i++) await s.book({ tripId: `trip-${i}` }).expect(201);
  await assert.rejects(s.db.query(`INSERT INTO bookings(student_id,trip_id,travel_date,departure_at,trip_snapshot,capacity,seat_number)
    VALUES($1,'external-trip',$2,'2030-01-02T08:00:00Z','{}',37,19)`, [s.users[0].id, date]), error => error.code === 'P0001');
});
test('standing capacity cannot be exceeded by simultaneous male requests', async t => {
  const s = await setup(t);
  await s.db.query("UPDATE users SET gender='male'");
  const results = await Promise.all([0, 1, 2].map(who => s.book({ standing: true, seatNumber: null }, who)));
  assert.deepEqual(results.map(r => r.status).sort(), [201, 201, 409]);
});
test('real PostgreSQL independent-connection seat race and daily-limit race', { skip: !process.env.TEST_DATABASE_URL }, async t => {
  const s = await setup(t, true);
  const results = await Promise.all([s.book(), s.book({}, 1)]);
  assert.deepEqual(results.map(r => r.status).sort(), [201, 409]);
  // Clear only this test's isolated schema records, then race five trips.
  await s.db.query('DELETE FROM bookings');
  const many = await Promise.all(Array.from({ length: 5 }, (_, i) => s.book({ tripId: `trip-${i}` })));
  assert.equal(many.filter(r => r.status === 201).length, 4);
  assert.equal(many.filter(r => r.status === 409).length, 1);
});
test('Member 1 OAuth callback session can immediately use Member 2', async t => {
  const s = await setup(t), agent = request.agent(s.app);
  await agent.get('/api/auth/google').expect(302);
  await agent.get(`/api/auth/google/callback?code=test&state=${s.flow.state}`).expect(302);
  await agent.get('/api/student/bookings').expect(200);
  await agent.post('/api/student/bookings').set('Origin', config.frontendUrl).send({ tripId: 'trip-0', travelDate: date, seatNumber: 1 }).expect(201);
});
