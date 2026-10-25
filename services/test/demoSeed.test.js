import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { seedDemo } from '../scripts/demoData.js';

const env = {
  DEMO_STUDENT_EMAIL: 'demo.student@g.bracu.ac.bd',
  DEMO_DRIVER_EMAIL: 'demo.driver@g.bracu.ac.bd',
  DEMO_AUTHORITY_EMAIL: 'demo.authority@g.bracu.ac.bd'
};
test('demo seed is repeatable, preserves profiles and refuses role escalation', async () => {
  const db = new PGlite();
  try {
    const root = new URL('../../database/migrations/', import.meta.url);
    for (const name of (await readdir(root)).filter(n => n.endsWith('.sql')).sort()) {
      await db.exec(await readFile(new URL(name, root), 'utf8'));
    }
    // PGlite has no cross-process locking; PostgreSQL exercises the real lock.
    const adapter = {query:(sql, values) => sql.includes('pg_advisory_xact_lock') ? Promise.resolve({rows:[]}) : db.query(sql, values)};
    await seedDemo(adapter, env);
    await db.query("UPDATE users SET gender='female',gender_verified=true WHERE role='student'");
    await seedDemo(adapter, env);
    for (const [table, count] of [['users',3],['drivers',1],['buses',2],['routes',1],['trips',48],['complaints',1],['feedback',1],['notifications',1],['auth_sessions',0],['email_login_tokens',0],['bookings',0]]) {
      assert.equal(Number((await db.query('SELECT count(*) AS count FROM '+table)).rows[0].count), count, table);
    }
    const profile = (await db.query("SELECT gender,gender_verified FROM users WHERE role='student'")).rows[0];
    assert.equal(profile.gender,'female');
    assert.equal(profile.gender_verified,true);
    assert.equal(Number((await db.query('SELECT count(*) AS count FROM trips WHERE driver_id IS NOT NULL')).rows[0].count),24);
    await assert.rejects(seedDemo(adapter, {...env,DEMO_STUDENT_EMAIL:env.DEMO_AUTHORITY_EMAIL,DEMO_AUTHORITY_EMAIL:env.DEMO_STUDENT_EMAIL}), /refusing to overwrite/);
    await assert.rejects(seedDemo(adapter, {...env,DEMO_DRIVER_EMAIL:env.DEMO_STUDENT_EMAIL}), /distinct inboxes/);
    await assert.rejects(seedDemo(adapter, {...env,DEMO_STUDENT_EMAIL:'invalid@example.com'}), /invalid_email/);
    assert.equal((await db.query("SELECT role FROM users WHERE email=$1",[env.DEMO_STUDENT_EMAIL])).rows[0].role,'student');
  } finally {await db.close();}
});
