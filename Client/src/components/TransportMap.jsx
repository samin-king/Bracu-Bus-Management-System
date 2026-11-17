import React,{useEffect,useRef,useState} from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import {CAMPUS,formatDistance} from '../utils/transportGeo.js';
const tileUrl = import.meta.env.VITE_MAP_TILE_URL || 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
function text(value) {const node=document.createElement('span');node.textContent=value;return node;}
export default function TransportMap({stops,selected,onSelect,road,fitKey}) {
  const container=useRef(null),map=useRef(null),layers=useRef(null),callback=useRef(onSelect),[tileError,setTileError]=useState(false);
  callback.current=onSelect;
  useEffect(()=>{
    const instance=L.map(container.current,{scrollWheelZoom:false}).setView([CAMPUS.latitude,CAMPUS.longitude],12);
    map.current=instance;
    const tiles=L.tileLayer(tileUrl,{maxZoom:19,attribution:'&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">OpenStreetMap contributors</a>'}).addTo(instance);
    tiles.on('tileerror',()=>setTileError(true));
    L.control.scale({imperial:false}).addTo(instance);
    layers.current=L.layerGroup().addTo(instance);
    const observer=typeof ResizeObserver==='undefined'?null:new ResizeObserver(()=>instance.invalidateSize());observer?.observe(container.current);
    return()=>{observer?.disconnect();instance.remove();map.current=null;};
  },[]);
  useEffect(()=>{
    if(!map.current)return;
    const group=layers.current;group.clearLayers();
    L.marker([CAMPUS.latitude,CAMPUS.longitude],{icon:L.divIcon({className:'campus-map-pin',html:'<span>BRACU</span>',iconSize:[64,38],iconAnchor:[32,38]}),title:CAMPUS.name,zIndexOffset:1000}).addTo(group).bindTooltip(text(CAMPUS.name),{direction:'top'});
    const positions=new Map();
    for(const stop of stops.filter(s=>s.location && s.location.accuracy!=='campus')) {
      const point=stop.location,key=`${point.latitude},${point.longitude}`;
      const current=positions.get(key);
      if(!current || stop.key===selected)positions.set(key,stop);
    }
    for(const stop of positions.values()) {
      const active=stop.key===selected;
      L.circleMarker([stop.location.latitude,stop.location.longitude],{radius:active?10:6,color:active?'#412445':'#852641',weight:active?4:2,fillColor:active?'#f3cb66':'#fff',fillOpacity:1}).addTo(group)
        .bindTooltip(text(`${stop.label} · ${stop.location.accuracy==='area'?'Approx. ':''}${formatDistance(stop.straightDistanceKm)} straight-line from BRACU${stop.location.accuracy==='area'?' (area reference)':''}`),{direction:'top'})
        .on('click',()=>callback.current(stop.key));
    }
    if(road?.coordinates?.length)L.polyline(road.coordinates,{color:'#852641',weight:5,opacity:.9}).addTo(group);
  },[stops,selected,road]);
  useEffect(()=>{
    if(!map.current)return;
    const coords=stops.filter(s=>s.location).map(s=>[s.location.latitude,s.location.longitude]);
    if(coords.length)map.current.fitBounds(L.latLngBounds([[CAMPUS.latitude,CAMPUS.longitude],...coords]),{padding:[35,35],maxZoom:14,animate:false});
  },[fitKey,stops]);
  useEffect(()=>{
    const stop=stops.find(s=>s.key===selected);
    if(stop?.location&&map.current)map.current.fitBounds(L.latLngBounds(road?.coordinates?.length ? road.coordinates : [[CAMPUS.latitude,CAMPUS.longitude],[stop.location.latitude,stop.location.longitude]]),{padding:[35,35],maxZoom:15,animate:false});
  },[selected,stops,road]);
  return <div className="real-map-wrapper"><div ref={container} className="real-transport-map" role="region" aria-label="BRAC University and transport stoppages on OpenStreetMap"/>{tileError&&<p className="map-tile-error" role="status">Some map tiles could not load. Stoppage coordinates and distances remain available. <button type="button" onClick={()=>{setTileError(false);map.current?.eachLayer(layer=>{if(layer instanceof L.TileLayer)layer.redraw();});}}>Reload map tiles</button></p>}</div>;
}
