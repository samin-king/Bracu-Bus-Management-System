import { Router } from 'express';
import { routeController } from '../controllers/routeController.js';
export function routeRoutes(db) {
 const router=Router(), c=routeController(db);
 const wrap=fn=>(req,res,next)=>Promise.resolve(fn(req,res,next)).catch(next);
 router.get('/',wrap(c.list));router.get('/:id',wrap(c.get));router.post('/',wrap(c.create));router.put('/:id',wrap(c.update));
 return router;
}
