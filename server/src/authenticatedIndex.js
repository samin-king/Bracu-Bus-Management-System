import pg from 'pg';
import {loadAuthConfig} from '../../Bracu-Bus-Management-System/services/src/config/auth.js';
import {createAuthenticatedApp} from './authenticatedApp.js';

const config = loadAuthConfig({...process.env, FRONTEND_URL: process.env.AUTH_TRANSPORT_FRONTEND_URL || process.env.FRONTEND_URL});
const pool = new pg.Pool({connectionString: config.databaseUrl, connectionTimeoutMillis: 5000});
// Fail closed; no schema creation, seeding, or account grants during startup.
for (const table of ['users', 'auth_sessions', 'transport_account_roles', 'drivers']) {
  await pool.query(`SELECT 1 FROM ${table} LIMIT 1`);
}
const server = createAuthenticatedApp({config, pool}).listen(Number(process.env.AUTH_TRANSPORT_PORT || process.env.API_PORT || 3002), process.env.API_HOST || '127.0.0.1', () => console.log('Authenticated transport API listening'));
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close(async () => {await pool.end(); process.exit(0);}));
