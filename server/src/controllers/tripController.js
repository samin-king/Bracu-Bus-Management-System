import { tripService } from '../services/tripService.js';
import { id,validate } from '../utils/validation.js';
export function tripController(db) {
 const service=tripService(db);
 return {
 list:async(req,res)=>res.json(await service.list()),
 get:async(req,res)=>res.json(await service.get(id(req.params.id))),
 create:async(req,res)=>{const data=await service.create(validate('trip',req.body));res.location('/api/trips/'+data.id).status(201).json(data);},
 update:async(req,res)=>res.json(await service.update(id(req.params.id),validate('trip',req.body)))
 };
}
