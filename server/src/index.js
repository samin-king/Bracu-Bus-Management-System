import { createApp } from './app.js';
import { pool } from './config/db.js';
if(!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
await pool.query('SELECT 1');
const server=createApp(pool).listen(Number(process.env.API_PORT)||3000,()=>console.log('Transport API listening'));
for(const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>server.close(async()=>{await pool.end();process.exit(0);}));
