import React from 'react';
import {beforeEach,it,expect,vi} from 'vitest';
import {act,fireEvent,render,screen,waitFor,within} from '@testing-library/react';
import {MemoryRouter} from 'react-router-dom';
import {BookBus,BookingSummary} from '../pages/Member2.jsx';
import {member2Api as api} from '../services/member2Api.js';
import {transportApi} from '../services/transportApi.js';
vi.mock('../services/member2Api.js',()=>({member2Api:{trips:vi.fn(),seats:vi.fn(),book:vi.fn()}}));
vi.mock('../services/transportApi.js',()=>({transportApi:{routes:vi.fn(),pattern:vi.fn(),schedules:vi.fn()}}));
const routes=[{variant_id:'1',variant_code:'01-A',variant_name:'Mirpur-A',pattern_id:'10',direction:'inbound',sequence_verified:true},{variant_id:'1',variant_code:'01-A',variant_name:'Mirpur-A',pattern_id:'11',direction:'outbound',sequence_verified:false},{variant_id:'2',variant_code:'02',variant_name:'Uttara',pattern_id:'12',direction:'inbound',sequence_verified:true}];
const schedule={id:'100',variant_id:'1',variant_name:'Mirpur-A',pattern_id:'10',label:'1st Trip',departure_time:'06:20',arrival_time:'07:50',verified:true,variant_verified:true,active:true};
const trip={id:'schedule:100',scheduleId:'100',bus:'BRACU-01',route:'Mirpur-A',label:'1st Trip',departureTime:'06:20',capacity:37,requiresStops:true,bookingOpen:true,opensAt:'2030-01-01T14:00:00Z',closesAt:'2030-01-02T00:20:00Z'};
const stops=[{id:'31',label:'Mirpur 12',sequence:1,pickup_allowed:true,dropoff_allowed:false,times:[{schedule_id:'100',label:'1st Trip',pickup_time:'06:20',arrival_time:null}]},{id:'32',label:'Farmgate',sequence:2,pickup_allowed:true,dropoff_allowed:false,times:[{schedule_id:'100',label:'1st Trip',pickup_time:'06:55',arrival_time:null}]},{id:'33',label:'BRAC University',sequence:3,pickup_allowed:false,dropoff_allowed:true,times:[{schedule_id:'100',label:'1st Trip',pickup_time:null,arrival_time:'07:50'}]}];
const availability={trip,bookingOpen:true,profileGender:'male',genderKnown:true,standingEligible:true,standingCapacity:2,standingAvailable:2,seats:[{number:1,state:'Reserved',selectable:false},{number:19,state:'Available',selectable:true}]};
const booking={id:'501',trip_id:trip.id,travel_date:'2030-01-02',status:'confirmed',section:'Upcoming',seat_number:19,trip_snapshot:{...trip,pickup:{name:'Farmgate',pickupTime:'06:55'},dropoff:{name:'BRAC University',arrivalTime:'07:50'}}};
beforeEach(()=>{
 vi.resetAllMocks();transportApi.routes.mockResolvedValue(routes);transportApi.schedules.mockResolvedValue([schedule]);transportApi.pattern.mockResolvedValue({id:'10',sequence_verified:true,stops});
 api.trips.mockResolvedValue([trip,{id:'legacy',bus:'DEV-BOOKING-01',route:'Development booking route'}]);api.seats.mockResolvedValue(availability);api.book.mockResolvedValue(booking);
});
const view=()=>render(<MemoryRouter><BookBus/></MemoryRouter>);
async function choose({seat=true}={}){
 view();fireEvent.change(await screen.findByLabelText('Route'),{target:{value:'1'}});
 fireEvent.click(await screen.findByRole('button',{name:/1st Trip/}));
 fireEvent.change(await screen.findByLabelText('Pickup stoppage'),{target:{value:'32'}});
 if(seat)fireEvent.click(await screen.findByRole('button',{name:'Seat 19 Available'}));
}
it('uses official routes and exact pickup times, hides legacy development trips and reviews before posting',async()=>{
 await choose();expect(screen.queryByText(/DEV-BOOKING/)).not.toBeInTheDocument();expect(screen.getByLabelText('Destination')).toHaveValue('33');
 expect(screen.getByRole('option',{name:'Farmgate · 06:55'})).toBeInTheDocument();
 fireEvent.click(screen.getByRole('button',{name:'Confirm Booking'}));expect(api.book).not.toHaveBeenCalled();
 const review=screen.getByRole('region',{name:'Booking review'});expect(review).toHaveTextContent('Farmgate · 06:55');expect(review).toHaveTextContent('E3');
 fireEvent.click(within(review).getByRole('button',{name:'Confirm & Book'}));
 await screen.findByText('Booking confirmed successfully.');
 expect(api.book).toHaveBeenCalledExactlyOnceWith({tripId:'schedule:100',travelDate:expect.any(String),seatNumber:19,standing:false,pickupStopId:'32',dropoffStopId:'33'});
 expect(screen.getByRole('region',{name:'Booking confirmation'})).toHaveTextContent('Farmgate · 06:55');
 expect(api.trips.mock.calls.length).toBeGreaterThan(1);expect(api.seats.mock.calls.length).toBeGreaterThan(1);
});
it('requires a pickup before review and preserves the server closed-window rule',async()=>{
 api.seats.mockResolvedValue({...availability,bookingOpen:false});api.trips.mockResolvedValue([{...trip,bookingOpen:false}]);
 await choose({seat:false});fireEvent.change(screen.getByLabelText('Pickup stoppage'),{target:{value:''}});fireEvent.click(await screen.findByRole('button',{name:'Seat 19 Available'}));
 expect(screen.getByRole('button',{name:'Confirm Booking'})).toBeDisabled();fireEvent.change(screen.getByLabelText('Pickup stoppage'),{target:{value:'32'}});fireEvent.click(screen.getByRole('button',{name:'Seat 19 Available'}));
 fireEvent.click(screen.getByRole('button',{name:'Confirm Booking'}));expect(screen.getByRole('button',{name:'Confirm & Book'})).toBeDisabled();expect(api.book).not.toHaveBeenCalled();
});
it('rechecks the server window before posting',async()=>{
 await choose();api.seats.mockResolvedValue({...availability,bookingOpen:false});fireEvent.click(screen.getByRole('button',{name:'Confirm Booking'}));fireEvent.click(screen.getByRole('button',{name:'Confirm & Book'}));
 expect(await screen.findByRole('alert')).toHaveTextContent('Booking is closed');expect(api.book).not.toHaveBeenCalled();
});
it('submits standing with actual stop IDs and suppresses double submission',async()=>{
 await choose({seat:false});fireEvent.click(await screen.findByRole('button',{name:'Select Standing'}));fireEvent.click(screen.getByRole('button',{name:'Confirm Booking'}));
 let finish;api.book.mockImplementation(()=>new Promise(resolve=>{finish=resolve;}));const submit=screen.getByRole('button',{name:'Confirm & Book'});fireEvent.click(submit);fireEvent.click(submit);
 await waitFor(()=>expect(finish).toBeTypeOf('function'));expect(api.book).toHaveBeenCalledTimes(1);expect(api.book).toHaveBeenCalledWith(expect.objectContaining({standing:true,seatNumber:null,pickupStopId:'32',dropoffStopId:'33'}));
 await act(async()=>finish({...booking,standing:true,seat_number:null}));await screen.findByText('Booking confirmed successfully.');
});
it('shows backend booking errors and refreshes availability without inventing success',async()=>{
 const error=new Error('This seat or trip is already booked.');error.code='booking_conflict';api.book.mockRejectedValue(error);
 await choose();fireEvent.click(screen.getByRole('button',{name:'Confirm Booking'}));fireEvent.click(screen.getByRole('button',{name:'Confirm & Book'}));
 expect(await screen.findByRole('alert')).toHaveTextContent('already booked');expect(screen.queryByText('Booking confirmed successfully.')).not.toBeInTheDocument();
 await waitFor(()=>expect(api.trips.mock.calls.length).toBeGreaterThan(1));
});
it('blocks repeating an uncertain write and directs the student to server booking history',async()=>{
 api.book.mockRejectedValue(new TypeError('Network lost'));await choose();fireEvent.click(screen.getByRole('button',{name:'Confirm Booking'}));fireEvent.click(screen.getByRole('button',{name:'Confirm & Book'}));
 await screen.findByRole('link',{name:'Check Booking History'});expect(screen.getByRole('button',{name:'Confirm Booking'})).toBeDisabled();expect(api.book).toHaveBeenCalledTimes(1);
});
it('clears pickup, seat and review when switching route or date',async()=>{
 await choose();fireEvent.click(screen.getByRole('button',{name:'Confirm Booking'}));fireEvent.change(screen.getByLabelText('Route'),{target:{value:'2'}});
 expect(screen.queryByRole('region',{name:'Booking review'})).not.toBeInTheDocument();expect(screen.queryByLabelText('Pickup stoppage')).not.toBeInTheDocument();
 fireEvent.change(screen.getByLabelText('Travel date'),{target:{value:'2030-01-02'}});await waitFor(()=>expect(api.trips).toHaveBeenLastCalledWith('2030-01-02'));
});
it('shows inactive and unverified schedule stops as preview, never as bookable inventory',async()=>{
 api.trips.mockResolvedValue([]);transportApi.schedules.mockResolvedValue([{...schedule,active:false,verified:false}]);await choose({seat:false});
 expect(screen.getByText('Awaiting verification')).toBeInTheDocument();expect(screen.getByLabelText('Pickup stoppage')).toBeInTheDocument();expect(screen.queryByLabelText('Seat map')).not.toBeInTheDocument();expect(screen.queryByRole('button',{name:'Confirm Booking'})).not.toBeInTheDocument();
});
it('does not invent outbound intermediate stops or a missing return trip',async()=>{
 view();fireEvent.change(await screen.findByLabelText('Journey direction'),{target:{value:'outbound'}});fireEvent.change(screen.getByLabelText('Route'),{target:{value:'1'}});
 transportApi.pattern.mockResolvedValue({id:'11',sequence_verified:false,stops:[{id:'34',label:'BRAC University',sequence:1,pickup_allowed:true,times:[{schedule_id:'100',label:'1st Trip',pickup_time:'14:05'}]}]});
 await waitFor(()=>expect(transportApi.schedules).toHaveBeenCalledWith(expect.objectContaining({direction:'outbound'})));fireEvent.click(await screen.findByRole('button',{name:/1st Trip/}));
 expect(await screen.findByText(/Return-trip intermediate stoppages/)).toBeInTheDocument();expect(screen.queryByLabelText('Destination')).not.toBeInTheDocument();
});
it('retries schedule errors and displays dates with no service',async()=>{
 transportApi.schedules.mockRejectedValueOnce(new Error('Schedule unavailable'));view();fireEvent.change(await screen.findByLabelText('Route'),{target:{value:'1'}});await screen.findByText('Schedule unavailable');
 transportApi.schedules.mockResolvedValue([]);fireEvent.click(screen.getByRole('button',{name:'Retry'}));expect(await screen.findByRole('heading',{name:'No scheduled service for this date'})).toBeInTheDocument();
});
it('history/details render stored pickup and destination after refresh or cancellation',()=>{
 render(<BookingSummary booking={{...booking,status:'cancelled'}}/>);expect(screen.getByText('Farmgate · 06:55')).toBeInTheDocument();expect(screen.getByText('BRAC University · 07:50')).toBeInTheDocument();expect(screen.getByText('cancelled')).toBeInTheDocument();
});
