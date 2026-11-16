import express from 'express';
import rateLimit from 'express-rate-limit';
import { requireAuth, requireSameOrigin } from '../middleware/authMiddleware.js';
import { AuthError } from '../services/authService.js';
const run = fn => async (req,res,next) => {try {res.json(await fn(req));}catch(error){next(error);}};
export function transportRoutes(service,authService,config,{admin=false}={}) {
  const router=express.Router();
  router.use((req,res,next)=>{res.set('Cache-Control','no-store');next();});
  router.use(requireAuth(authService));
  router.use((req,res,next)=>['GET','HEAD'].includes(req.method)?next():requireSameOrigin(config)(req,res,next));
  router.use(express.json({limit:'64kb'}));
  if(admin) {
    router.use(async(req,res,next)=>{try {if(!(await service.access(req.user.id)).transportAdmin) throw new AuthError('forbidden',403);next();}catch(e){next(e);}});
    router.use(rateLimit({windowMs:60000,limit:240,standardHeaders:'draft-7',legacyHeaders:false}));
  }
  router.get('/routes',run(()=>service.routes()));
  router.get('/patterns/:id',run(r=>service.pattern(r.params.id)));
  router.get('/schedules',run(r=>service.schedules(r.query)));
  router.get('/sources',run(()=>service.sources()));
  if(!admin) router.get('/access',run(r=>service.access(r.user.id)));
  else {
    router.get('/resources/:kind',run(r=>service.resources(r.params.kind,r.query)));
    router.post('/resources/:kind',run(r=>service.resource(r.user.id,r.params.kind,r.body||{})));
    router.put('/resources/:kind/:id',run(r=>service.resource(r.user.id,r.params.kind,r.body||{},r.params.id)));
    router.delete('/exceptions/:date',run(r=>service.removeException(r.user.id,r.params.date)));
    router.put('/stops/:id',run(r=>service.saveStop(r.user.id,r.params.id,r.body||{})));
    router.put('/patterns/:id/order',run(r=>service.reorder(r.user.id,r.params.id,r.body||{})));
    router.post('/schedules',run(r=>service.saveSchedule(r.user.id,null,r.body||{})));
    router.put('/schedules/:id',run(r=>service.saveSchedule(r.user.id,r.params.id,r.body||{})));
    router.put('/variants/:id/verification',run(r=>service.verifyVariant(r.user.id,r.params.id,r.body||{})));
  }
  return router;
}
