import pg from 'pg';
import { seedDemo } from './demoData.js';

// Do not read local .env: this command uses only explicitly supplied host settings.
if (process.env.NODE_ENV !== 'production') throw new Error('Demo provisioning requires NODE_ENV=production');
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
const pool = new pg.Pool({connectionString: process.env.DATABASE_URL});
let client;
try {
  client = await pool.connect();
  await seedDemo(client, process.env);
  console.log('Demo accounts, fleet, trips and sample messages provisioned; email verification remains required.');
} catch (error) {
  console.error('Demo provisioning failed', {type:error.constructor.name, code:error.code});
  process.exitCode = 1;
} finally {
  client?.release();
  await pool.end();
}
