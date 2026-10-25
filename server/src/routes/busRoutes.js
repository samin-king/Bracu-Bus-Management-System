import { Router } from 'express';
import { busController } from '../controllers/busController.js';
export function busRoutes(db) {
 const router=Router(), c=busController(db);
 const wrap=fn=>(req,res,next)=>Promise.resolve(fn(req,res,next)).catch(next);
 router.get('/',wrap(c.list));router.get('/:id',wrap(c.get));router.post('/',wrap(c.create));router.put('/:id',wrap(c.update));
 return router;
}
