import {afterEach,it,expect,vi} from 'vitest';
afterEach(()=>{vi.unstubAllGlobals();vi.resetModules();});
const from={latitude:23.7733146,longitude:90.424371},to={latitude:23.8787009,longitude:90.4017549};
it('requests actual driving geometry with longitude/latitude order and caches repeated destinations',async()=>{
 const fetch=vi.fn(async()=>({ok:true,json:async()=>({code:'Ok',routes:[{distance:15927,geometry:{type:'LineString',coordinates:[[90.424371,23.7733146],[90.4017549,23.8787009]]}}]})}));vi.stubGlobal('fetch',fetch);const {roadRoute}=await import('../services/mapRouting.js');
 const result=await roadRoute(from,to);expect(result.distanceKm).toBe(15.927);expect(result.coordinates[0]).toEqual([23.7733146,90.424371]);expect(fetch.mock.calls[0][0]).toContain('90.424371,23.7733146;90.4017549,23.8787009');expect(await roadRoute(from,to)).toEqual(result);expect(fetch).toHaveBeenCalledTimes(1);
});
it('rejects missing coordinates before making a routing request',async()=>{
 const fetch=vi.fn();vi.stubGlobal('fetch',fetch);const {roadRoute}=await import('../services/mapRouting.js');await expect(roadRoute(from,{latitude:null,longitude:null})).rejects.toThrow('not available');expect(fetch).not.toHaveBeenCalled();
});
it('rejects a no-route response instead of inventing a road distance',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>({ok:true,json:async()=>({code:'NoRoute',routes:[]})})));const {roadRoute}=await import('../services/mapRouting.js');await expect(roadRoute(from,to)).rejects.toThrow('No road route');
});
it('rejects malformed geometry and upstream HTTP failures',async()=>{
 const fetch=vi.fn(async()=>({ok:true,json:async()=>({code:'Ok',routes:[{distance:42,geometry:{type:'LineString',coordinates:[[900,500]]}}]})}));vi.stubGlobal('fetch',fetch);const {roadRoute}=await import('../services/mapRouting.js');await expect(roadRoute(from,to)).rejects.toThrow('No road route');
 vi.resetModules();fetch.mockResolvedValue({ok:false});const {roadRoute:retry}=await import('../services/mapRouting.js');await expect(retry(from,to)).rejects.toThrow('temporarily unavailable');
});
