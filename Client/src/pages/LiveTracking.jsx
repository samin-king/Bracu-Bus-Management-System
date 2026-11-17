import React,{useEffect,useMemo,useRef,useState} from 'react';
import {transportApi} from '../services/transportApi.js';
import {roadRoute} from '../services/mapRouting.js';
import {CAMPUS,formatDistance,locateStop,normalizeLocation} from '../utils/transportGeo.js';
import TransportMap from '../components/TransportMap.jsx';
import {EmptyState,Icon,Loading,PageHeading,useResource} from '../components/Ui.jsx';
export default function LiveTracking(){
  const routes=useResource(transportApi.routes);
  const inbound=(routes.data||[]).filter(route=>route.direction==='inbound');
  const routeKey=inbound.map(route=>route.pattern_id).join(',');
  const patterns=useResource(async()=>{
    const results=await Promise.allSettled(inbound.map(async route=>({route,pattern:await transportApi.pattern(route.pattern_id)})));
    return {items:results.filter(result=>result.status==='fulfilled').map(result=>result.value),failed:results.filter(result=>result.status==='rejected').length};
  },[routeKey]);
  const [routeId,setRouteId]=useState('all'),[query,setQuery]=useState(''),[selected,setSelected]=useState(''),[road,setRoad]=useState(null),[roadError,setRoadError]=useState(''),[routing,setRouting]=useState(false);
  const requestVersion=useRef(0);
  useEffect(()=>()=>{requestVersion.current++;},[]);
  const stops=useMemo(()=>{
    const merged=new Map();
    for(const {route,pattern} of patterns.data?.items||[]){
      if(routeId!=='all'&&route.variant_id!==routeId)continue;
      for(const stop of pattern.stops){
        const campus=normalizeLocation(stop.label).startsWith('brac university');
        const key=campus?'campus':String(stop.stop_id||normalizeLocation(stop.label));
        if(!merged.has(key))merged.set(key,{...locateStop(stop),key,routeNames:[],routeCodes:[],verified:route.verified});
        const item=merged.get(key);if(!item.routeCodes.includes(route.variant_code)){item.routeCodes.push(route.variant_code);item.routeNames.push(route.variant_name);}
      }
    }
    return [...merged.values()];
  },[patterns.data,routeId]);
  const visible=stops.filter(stop=>normalizeLocation([stop.label,...stop.routeNames].join(' ')).includes(normalizeLocation(query)));
  const chosen=stops.find(stop=>stop.key===selected);
  const mapped=stops.filter(stop=>stop.location).length;
  function select(key){requestVersion.current++;setSelected(key);setRoad(null);setRoadError('');setRouting(false);}
  function changeRoute(value){setRouteId(value);setQuery('');select('');}
  async function directions(){
    if(!chosen?.location||routing)return;
    const version=++requestVersion.current;setRouting(true);setRoadError('');
    try{const result=await roadRoute(CAMPUS,chosen.location);if(version===requestVersion.current)setRoad(result);}
    catch(error){if(version===requestVersion.current){setRoad(null);setRoadError(error.message||'Road directions are unavailable.');}}
    finally{if(version===requestVersion.current)setRouting(false);}
  }
  const route=inbound.find(item=>item.variant_id===routeId);
  return <><PageHeading title="Live Bus Tracking" eyebrow="CAMPUS & TRANSPORT MAP" action={<button type="button" onClick={()=>{routes.reload();patterns.reload();select('');}}><Icon name="history" size={17}/>Refresh locations</button>}>Explore BRAC University and every published route stoppage on a real map.</PageHeading>
    <div className="geographic-status"><span className="geo-status-dot"/><div><strong>Real map · GPS not connected</strong><p>Stoppage locations and campus distances are available. Real-time bus locations require a GPS service.</p></div></div>
    <div className="geo-controls"><label>Route<select aria-label="Map route" value={routeId} onChange={e=>changeRoute(e.target.value)}><option value="all">All university routes</option>{inbound.map(item=><option key={item.variant_id} value={item.variant_id}>{item.variant_code} · {item.variant_name}</option>)}</select></label><label>Find a stoppage<input type="search" value={query} placeholder="Search place or route" onChange={e=>setQuery(e.target.value)}/></label></div>
    {(routes.loading||patterns.loading)&&<Loading>Loading university locations...</Loading>}
    {routes.error&&<p role="alert" className="m2-error">{routes.error} <button type="button" onClick={routes.reload}>Retry routes</button></p>}
    {patterns.error&&<p role="alert" className="m2-error">{patterns.error} <button type="button" onClick={patterns.reload}>Retry locations</button></p>}
    {patterns.data?.failed>0&&<p role="alert" className="m2-error">Some route locations could not be loaded. Loaded routes remain available. <button type="button" onClick={patterns.reload}>Retry locations</button></p>}
    <div className="geo-layout"><section className="tracking-map-card"><div className="map-toolbar"><div><span className="eyebrow">GEOGRAPHIC ROUTE MAP</span><h2>{route?.variant_name||'BRAC University transport network'}</h2></div><span className="geo-count">{mapped} / {stops.length} locations mapped</span></div>
      <TransportMap stops={stops} selected={selected} onSelect={select} road={road} fitKey={routeId}/>
      <div className="geo-map-legend"><span><i className="campus-key"/>BRAC University</span><span><i className="stop-key"/>Stoppage reference</span><span>No simulated bus movement</span></div>
      <div className="geo-campus"><strong>{CAMPUS.name}</strong><span>{CAMPUS.address}</span><a href={CAMPUS.sourceUrl} target="_blank" rel="noreferrer">View campus on OpenStreetMap ↗</a></div>
    </section>
    <aside className="geo-details"><section className="geo-distance-card" aria-label="Distance from BRAC University"><span className="eyebrow">DISTANCE FROM CAMPUS</span><h2>{chosen?.label||'Choose a stoppage'}</h2>{chosen?<>
      <div className="geo-distance-value">{formatDistance(chosen.straightDistanceKm)}</div><p>{chosen.location?.accuracy==='area'?'Approximate straight-line distance to mapped area reference':'Straight-line distance from BRAC University'}</p>
      {!chosen.location?<p className="info-note">This location has no verified coordinate yet. Its pin and distance are unavailable.</p>:<>
        <p className="geo-pin-note">{chosen.location.accuracy==='campus'?'Campus location':chosen.location.accuracy==='admin'?'Administrator-supplied coordinate':chosen.location.accuracy==='area'?'Area reference · exact boarding point needs confirmation':'Mapped landmark · boarding side needs confirmation'}</p>
        {chosen.key!=='campus'&&<button type="button" className="primary-button" disabled={routing} onClick={directions}>{routing?'Finding road route…':'Show road distance & directions'}</button>}
        {road&&<div className="geo-road-result"><strong>{formatDistance(road.distanceKm)}</strong><span>Estimated driving distance from BRAC University</span><small>Suggested road route; it may differ from the university bus route. No live traffic or arrival prediction.</small></div>}
        {chosen.location.mappedName && <p className="geo-pin-note">Mapped reference: {chosen.location.mappedName}</p>}
        {chosen.location.sourceUrl&&<a href={chosen.location.sourceUrl} target="_blank" rel="noreferrer">Location source ↗</a>}
      </>}
      {roadError&&<p role="alert" className="m2-error">{roadError} Straight-line distance is still shown.</p>}
    </>:<p>Select a pin on the map or a stoppage below to see its distance and road directions.</p>}</section>
    <section className="geo-stop-panel"><div className="section-top"><h2>Stoppages</h2><span>{visible.length} places</span></div><p className="muted">Distances below are straight-line estimates from the Merul Badda campus.</p><ul className="geo-stop-list">{visible.map(stop=><li key={stop.key}><button type="button" aria-pressed={selected===stop.key} onClick={()=>select(stop.key)}><span><strong>{stop.label}</strong><small>{stop.routeCodes.join(' · ')}</small><small>{!stop.location?'Coordinate pending':stop.location.accuracy==='area'?'Area reference · approximate distance':stop.location.accuracy==='campus'?'Merul Badda campus':'Mapped location'}</small></span><b>{formatDistance(stop.straightDistanceKm)}</b></button></li>)}</ul>{!routes.loading&&!patterns.loading&&!visible.length&&<EmptyState icon="map" title={query?'No matching stoppages':'No published route locations'}>{query?'Try another place or route name.':'Route stops will appear when the university schedule is published.'}</EmptyState>}</section></aside></div>
  </>;
}
