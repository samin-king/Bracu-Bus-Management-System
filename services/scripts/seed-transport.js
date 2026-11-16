import dotenv from 'dotenv';
import pg from 'pg';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { seedTransport } from '../src/services/transportSeed.js';
dotenv.config({path:fileURLToPath(new URL('../../.env',import.meta.url))});
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
const data=JSON.parse(await readFile(new URL('../../database/seeds/bracu-2026-10-03.json',import.meta.url),'utf8'));
const image=await readFile(new URL(`../../${data.sourceImage}`,import.meta.url));
if (createHash('sha256').update(image).digest('hex') !== data.sourceSha256) throw new Error('Source image hash mismatch');
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL});
try { console.log(await seedTransport(pool,data)); console.log('Unverified entries remain; no bus/driver assignments or trip activations were invented.'); }
finally { await pool.end(); }
