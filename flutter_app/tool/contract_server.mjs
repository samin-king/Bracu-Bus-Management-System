// Test-only fixture: the actual Express app and SQL migrations, with ephemeral
// PostgreSQL, captured mail and memory sessions. Never loads .env or uses Neon.
import {PGlite} from '@electric-sql/pglite';
import session from 'express-session';
import {createApp} from '../../services/src/app.js';
import {migrate} from '../../server/src/utils/database.js';
if(process.env.BRACU_BACKEND_CONTRACT!=='1')throw new Error('Explicit test opt-in required');
const engine=new PGlite();
const client={async query(sql,params){
  const r=params?await engine.query(sql,params):(await engine.exec(sql)).at(-1);
  return {rows:r?.rows||[],rowCount:r?.rows?.length||r?.affectedRows||0};
},release(){}};
const pool={query:client.query,connect:async()=>client};
await migrate(client);
await pool.query("INSERT INTO drivers(name,license_number,status) VALUES('Fixture Driver','FIXTURE-001','ACTIVE')");
for(const role of ['student','driver','authority','admin']){
  await pool.query('INSERT INTO users(google_subject,name,email,role,driver_id) VALUES($1,$2,$3,$4,$5)',
    ['fixture:'+role,'Fixture '+role,role+'.fixture@g.bracu.ac.bd',role,role==='driver'?1:null]);
}
await pool.query("INSERT INTO buses(bus_number,capacity) VALUES('FIXTURE-BUS',37)");
await pool.query("INSERT INTO routes(route_name,origin,destination) VALUES('Fixture Route','City','Campus')");
await pool.query("INSERT INTO trips(bus_id,route_id,driver_id,travel_date,departure_time) VALUES(1,1,1,'2030-01-02','14:00')");
const config={frontendUrl:'http://localhost:5173',domain:'g.bracu.ac.bd',
  secret:'ephemeral-contract-test-secret-at-least-32',cookieName:'bracu.sid',ttlMs:3600000,secure:false};
const app=createApp({config,pool,store:new session.MemoryStore(),sendEmail:async m=>{
  const token=new URLSearchParams(new URL(m.url).hash.slice(1)).get('email_token');
  process.stdout.write(JSON.stringify({type:'email',email:m.email,token})+'\n');
}});
const server=app.listen(0,'127.0.0.1',()=>process.stdout.write(
  JSON.stringify({type:'ready',origin:'http://127.0.0.1:'+server.address().port})+'\n'));
let closing=false;
function close(){if(closing)return;closing=true;server.close(async()=>{await engine.close();process.exit(0);});}
process.stdin.setEncoding('utf8');
process.stdin.on('data',chunk=>{if(chunk.includes('stop'))close();});
process.stdin.on('end',close);
process.on('SIGTERM',close);
