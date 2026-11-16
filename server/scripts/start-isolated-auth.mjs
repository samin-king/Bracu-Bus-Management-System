import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import {existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {randomBytes} from 'node:crypto';
import {migrate} from '../src/utils/database.js';
import {createAuthenticatedApp} from '../src/authenticatedApp.js';
import {loadAuthConfig} from '../../Bracu-Bus-Management-System/services/src/config/auth.js';

const envPath = fileURLToPath(new URL('../../.env', import.meta.url));
if (existsSync(envPath)) process.loadEnvFile(envPath);
// Never connects to DATABASE_URL. All schema work is confined to this new DB.
const engine = new PGlite(fileURLToPath(new URL('../../.local/isolated-auth-transport-db', import.meta.url)));
await engine.waitReady;
const pool = {async query(sql, params) {
  const result = params ? await engine.query(sql, params) : (await engine.exec(sql)).at(-1);
  return {rows: result?.rows || [], rowCount: result?.rows?.length || 0};
}};
const config = loadAuthConfig({...process.env, NODE_ENV:'development', DATABASE_URL:'postgres://unused/isolated',
  FRONTEND_URL:process.env.AUTH_TRANSPORT_FRONTEND_URL || 'http://127.0.0.1:8191',
  GOOGLE_CALLBACK_URL:process.env.GOOGLE_CALLBACK_URL || 'http://127.0.0.1:3002/api/auth/google/callback',
  SESSION_SECRET:randomBytes(48).toString('base64url'), SESSION_COOKIE_SECURE:'false'});
const tables = await pool.query("SELECT tablename FROM pg_tables WHERE schemaname='public'");
if (tables.rows.length === 0) {
  await pool.query(await readFile(new URL('../../Bracu-Bus-Management-System/database/migrations/001_authentication.sql', import.meta.url),'utf8'));
  await migrate(pool);
  await pool.query(await readFile(new URL('../integration/transport_account_roles.sql', import.meta.url),'utf8'));
}
// Uses the real Google provider and PostgreSQL-backed sessions. No fake login.
const server = createAuthenticatedApp({config,pool}).listen(3002,'127.0.0.1',()=>console.log('Authenticated transport on 127.0.0.1:3002; isolated development database; OAuth credentials required'));
for (const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>server.close(async()=>{await engine.close();process.exit(0);}));
