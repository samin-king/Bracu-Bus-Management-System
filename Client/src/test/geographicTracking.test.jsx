import React from 'react';
import {beforeEach,it,expect,vi} from 'vitest';
import {act,fireEvent,render,screen,waitFor,within} from '@testing-library/react';
import LiveTracking from '../pages/LiveTracking.jsx';
import {transportApi} from '../services/transportApi.js';
import {roadRoute} from '../services/mapRouting.js';
vi.mock('../services/transportApi.js',()=>({transportApi:{routes:vi.fn(),pattern:vi.fn()}}));
vi.mock('../services/mapRouting.js',()=>({roadRoute:vi.fn()}));
vi.mock('../components/TransportMap.jsx',()=>({default:({stops,onSelect})=><div role="region" aria-label="Interactive geographic map">{stops.filter(s=>s.location).map(s=><button key={s.key} onClick={()=>onSelect(s.key)}>{'Map pin '+s.label}</button>)}</div>}));
const routes=[{variant_id:'1',variant_code:'01-A',variant_name:'Abdullahpur-A',pattern_id:'10',direction:'inbound',verified:true},{variant_id:'2',variant_code:'02-A',variant_name:'Mirpur-A',pattern_id:'20',direction:'inbound',verified:true}];
const campus={id:'3',stop_id:'3',label:'BRAC University (arrival time)',latitude:null,longitude:null};
const stop={id:'1',stop_id:'1',label:'Test landmark',latitude:23.80,longitude:90.40,coordinate_reference:'https://www.openstreetmap.org/node/1'};
beforeEach(()=>{vi.resetAllMocks();transportApi.routes.mockResolvedValue(routes);transportApi.pattern.mockImplementation(async id=>({stops:id==='10'?[stop,campus]:[{...stop,id:'4',stop_id:'4',label:'Second landmark',latitude:23.81},campus]}));roadRoute.mockResolvedValue({distanceKm:7.2,coordinates:[[23.77,90.42],[23.8,90.4]]});});
it('maps official stops and campus, deduplicates shared campus, and does not simulate a bus',async()=>{
 render(<LiveTracking/>);await screen.findByRole('button',{name:/^Test landmark/});expect(screen.getByText('Real map · GPS not connected')).toBeInTheDocument();expect(screen.getByText('3 / 3 locations mapped')).toBeInTheDocument();expect(screen.getAllByRole('button',{name:/^BRAC University \(arrival time\)/})).toHaveLength(1);expect(roadRoute).not.toHaveBeenCalled();expect(screen.queryByText(/Demo route view/)).not.toBeInTheDocument();
});
it('selects a location on the map and gets actual road directions only on request',async()=>{
 render(<LiveTracking/>);fireEvent.click(await screen.findByRole('button',{name:'Map pin Test landmark'}));const detail=screen.getByRole('region',{name:'Distance from BRAC University'});expect(within(detail).getByText('Straight-line distance from BRAC University')).toBeInTheDocument();expect(roadRoute).not.toHaveBeenCalled();fireEvent.click(within(detail).getByRole('button',{name:'Show road distance & directions'}));await within(detail).findByText('7.2 km');expect(roadRoute).toHaveBeenCalledTimes(1);expect(within(detail).getByText(/Suggested road route/)).toBeInTheDocument();
});
it('filters published routes and searches stoppage names without geocoding requests',async()=>{
 render(<LiveTracking/>);await screen.findByRole('button',{name:/^Second landmark/});fireEvent.change(screen.getByLabelText('Map route'),{target:{value:'1'}});expect(screen.queryByRole('button',{name:/^Second landmark/})).not.toBeInTheDocument();fireEvent.change(screen.getByLabelText('Find a stoppage'),{target:{value:'no matching place'}});expect(screen.getByRole('heading',{name:'No matching stoppages'})).toBeInTheDocument();
});
it('does not invent coordinates or distances for a new unlocated stop',async()=>{
 transportApi.pattern.mockResolvedValue({stops:[{id:'9',stop_id:'9',label:'New unlocated stop'}]});render(<LiveTracking/>);fireEvent.click(await screen.findByRole('button',{name:/^New unlocated stop/}));const detail=screen.getByRole('region',{name:'Distance from BRAC University'});expect(within(detail).getByText('Unavailable')).toBeInTheDocument();expect(within(detail).queryByRole('button',{name:'Show road distance & directions'})).not.toBeInTheDocument();expect(screen.getByText('0 / 1 locations mapped')).toBeInTheDocument();
});
it('keeps straight-line distance when routing fails and allows retry',async()=>{
 roadRoute.mockRejectedValueOnce(new Error('Road routing is offline'));render(<LiveTracking/>);fireEvent.click(await screen.findByRole('button',{name:/^Test landmark/}));fireEvent.click(screen.getByRole('button',{name:'Show road distance & directions'}));expect(await screen.findByRole('alert')).toHaveTextContent('Road routing is offline');expect(screen.getByText('Straight-line distance from BRAC University')).toBeInTheDocument();fireEvent.click(screen.getByRole('button',{name:'Show road distance & directions'}));await screen.findByText('7.2 km');
});
it('discards a late road response when the selected stop changes',async()=>{
 let finish;roadRoute.mockImplementation(()=>new Promise(resolve=>{finish=resolve;}));render(<LiveTracking/>);fireEvent.click(await screen.findByRole('button',{name:/^Test landmark/}));fireEvent.click(screen.getByRole('button',{name:'Show road distance & directions'}));fireEvent.click(screen.getByRole('button',{name:/^Second landmark/}));await act(async()=>finish({distanceKm:99,coordinates:[]}));expect(screen.queryByText('99.0 km')).not.toBeInTheDocument();expect(screen.getByRole('region',{name:'Distance from BRAC University'})).toHaveTextContent('Second landmark');
});
it('retains loaded routes when another pattern fails and retries missing data',async()=>{
 transportApi.pattern.mockImplementation(async id=>{if(id==='20')throw new Error('offline');return {stops:[stop,campus]};});render(<LiveTracking/>);expect(await screen.findByRole('alert')).toHaveTextContent('Some route locations');expect(screen.getByRole('button',{name:/^Test landmark/})).toBeInTheDocument();transportApi.pattern.mockResolvedValue({stops:[stop,campus]});fireEvent.click(screen.getByRole('button',{name:'Retry locations'}));await waitFor(()=>expect(screen.queryByRole('alert')).not.toBeInTheDocument());
});
it('retries a failed routes request and handles an empty catalog',async()=>{
 transportApi.routes.mockRejectedValueOnce(new Error('Routes offline'));render(<LiveTracking/>);await screen.findByText('Routes offline');transportApi.routes.mockResolvedValue([]);fireEvent.click(screen.getByRole('button',{name:'Retry routes'}));await screen.findByRole('heading',{name:'No published route locations'});expect(screen.getByText(/Merul Badda, Dhaka/)).toBeInTheDocument();
});
