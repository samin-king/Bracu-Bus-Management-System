import { driverRoutes } from './routes/driverRoutes.js';
import { developmentIdentity,developmentManagement } from './middleware/driverIdentity.js';
import express from 'express';
import { busRoutes } from './routes/busRoutes.js';
import { routeRoutes } from './routes/routeRoutes.js';
import { tripRoutes } from './routes/tripRoutes.js';
import { errorHandler } from './middleware/errors.js';
export function createApp(db,{authenticateDriver=developmentIdentity,authorizeManagement=developmentManagement}={}) {
 const app=express();
 app.disable('x-powered-by');
 app.use(express.json({limit:'64kb'}));
 app.use(authenticateDriver);
 app.use('/api/drivers',driverRoutes(db,authorizeManagement));
 app.use('/api/buses',busRoutes(db));
 app.use('/api/routes',routeRoutes(db));
 app.use('/api/trips',tripRoutes(db,authorizeManagement));
 app.use((req,res)=>res.status(404).json({error:'API endpoint not found'}));
 app.use(errorHandler);
 return app;
}
