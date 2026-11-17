import {afterEach,it,expect,vi} from 'vitest';
import {transportApi} from '../services/transportApi.js';
import {member2Api} from '../services/member2Api.js';
afterEach(()=>vi.unstubAllGlobals());
it('reads existing authenticated metadata endpoints with credentials and no cached schedule',async()=>{
 const fetch=vi.fn(async()=>({ok:true,json:async()=>[]}));vi.stubGlobal('fetch',fetch);
 await transportApi.routes();await transportApi.pattern('12/34');
 expect(fetch).toHaveBeenNthCalledWith(1,'/api/student/transport/routes',{credentials:'include',cache:'no-store'});
 expect(fetch).toHaveBeenNthCalledWith(2,'/api/student/transport/patterns/12%2F34',{credentials:'include',cache:'no-store'});
});
it('loads all schedule pages with route, direction and date filters',async()=>{
 const fetch=vi.fn().mockResolvedValueOnce({ok:true,json:async()=>({items:[{id:'1'}],hasMore:true})}).mockResolvedValueOnce({ok:true,json:async()=>({items:[{id:'2'}],hasMore:false})});vi.stubGlobal('fetch',fetch);
 expect(await transportApi.schedules({variantId:'3',direction:'inbound',date:'2030-01-02'})).toEqual([{id:'1'},{id:'2'}]);
 const second=new URL(fetch.mock.calls[1][0],'http://localhost');expect(Object.fromEntries(second.searchParams)).toEqual({variantId:'3',direction:'inbound',date:'2030-01-02',page:'2',size:'100'});
});
it('surfaces authentication and metadata failures without pretending schedules are empty',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>({ok:false,status:401,json:async()=>({error:'unauthenticated'})})));await expect(transportApi.routes()).rejects.toThrow('session has expired');
 vi.stubGlobal('fetch',vi.fn(async()=>({ok:false,status:503,json:async()=>({error:'unavailable'})})));await expect(transportApi.routes()).rejects.toThrow('could not be loaded');
});
it('retains backend error codes and translates invalid stop selections for booking feedback',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>({ok:false,status:400,json:async()=>({error:'invalid_stop_selection'})})));
 await expect(member2Api.book({tripId:'schedule:1',pickupStopId:'bad'})).rejects.toMatchObject({code:'invalid_stop_selection',message:'Choose a valid pickup and destination for this trip.'});
});
