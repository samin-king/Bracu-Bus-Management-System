import React, {useRef, useState} from 'react';
import {Link} from 'react-router-dom';
import {member2Api as api} from '../services/member2Api.js';
import {transportApi} from '../services/transportApi.js';
import {Badge, EmptyState, Loading, PageHeading, useResource} from './Ui.jsx';
import SeatMap, {seatLabel} from './SeatMap.jsx';
import {BookingSummary} from './BookingSummary.jsx';

const today = () => new Intl.DateTimeFormat('en-CA', {timeZone:'Asia/Dhaka',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const stamp = value => value ? new Date(value).toLocaleString('en-GB', {timeZone:'Asia/Dhaka'}) : 'Unavailable';
function ResourceState({state}) {
  return <>{state.loading && <Loading/>}{state.error && <><p role="alert" className="m2-error">{state.error}</p><button type="button" onClick={state.reload}>Retry</button></>}</>;
}
export default function ScheduledBooking({routes}) {
  const [date,setDate] = useState(today), [variant,setVariant] = useState(''), [direction,setDirection] = useState('inbound');
  const [scheduleId,setScheduleId] = useState(''), [pickupValue,setPickup] = useState(''), [dropValue,setDrop] = useState(''), [seat,setSeat] = useState(null);
  const [review,setReview] = useState(false), [busy,setBusy] = useState(false), [error,setError] = useState(''), [confirmation,setConfirmation] = useState(null), [uncertain,setUncertain] = useState(false);
  const submitting = useRef(false);
  const route = routes.find(r => r.variant_id === variant && r.direction === direction);
  const variants = [...new Map(routes.map(r => [r.variant_id,r])).values()];
  const schedules = useResource(() => route ? transportApi.schedules({variantId:variant,direction,date}) : [], [variant,direction,date,route?.pattern_id]);
  const pattern = useResource(() => route ? transportApi.pattern(route.pattern_id) : null, [route?.pattern_id]);
  const trips = useResource(() => api.trips(date), [date]);
  const schedule = schedules.data?.find(s => s.id === scheduleId);
  const trip = schedule && trips.data?.find(t => t.id === `schedule:${schedule.id}`);
  const availability = useResource(() => trip ? api.seats(trip.id,date) : null, [trip?.id,date]);
  const stops = (pattern.data?.stops || []).map(stop => {
    const time = stop.times.find(time => time.schedule_id === scheduleId);
    return {...stop,pickup_time:time?.pickup_time,arrival_time:time?.arrival_time};
  });
  const pickups = stops.filter(stop => stop.pickup_allowed && stop.pickup_time);
  const pickupId = pickupValue || (pickups.length === 1 ? pickups[0].id : '');
  const pickup = pickups.find(stop => stop.id === pickupId);
  const supportsDropoff = direction === 'inbound' && pattern.data?.sequence_verified;
  const dropoffs = supportsDropoff && pickup ? stops.filter(stop => stop.dropoff_allowed && stop.arrival_time && stop.sequence > pickup.sequence) : [];
  const dropId = dropValue || (dropoffs.length === 1 ? dropoffs[0].id : '');
  const dropoff = dropoffs.find(stop => stop.id === dropId);
  const validStops = Boolean(pickup && (!supportsDropoff || dropoff));
  const selectable = seat === 'standing' ? availability.data?.standingAvailable > 0 : availability.data?.seats.some(s => s.number === seat && s.selectable);
  function clearSelection() { setSeat(null);setPickup('');setDrop('');setReview(false);setConfirmation(null);setError(''); }
  function resetJourney() { setScheduleId('');clearSelection(); }
  function refresh() { schedules.reload();trips.reload();availability.reload(); }
  async function confirm() {
    if (submitting.current || uncertain || !review || !trip || !validStops || !selectable) return;
    submitting.current = true;setBusy(true);setError('');
    let posted = false;
    try {
      const latest = await api.seats(trip.id,date);
      if (!latest.bookingOpen) { const failure = new Error('Booking is closed for this trip.');failure.code='booking_window_closed';throw failure; }
      if (seat === 'standing' ? !(latest.standingAvailable > 0) : !latest.seats.some(s => s.number === seat && s.selectable)) {
        const failure = new Error('Your selection is no longer available. Choose again.');failure.code='booking_conflict';throw failure;
      }
      posted = true;
      const result = await api.book({tripId:trip.id,travelDate:date,standing:seat === 'standing',seatNumber:seat === 'standing' ? null : seat,pickupStopId:pickupId,...(dropoff ? {dropoffStopId:dropId} : {})});
      setConfirmation(result);setReview(false);setSeat(null);
    } catch (failure) {
      if (posted && !failure.code) {setUncertain(true);setError('The booking result could not be confirmed. Check Booking History before trying again.');}
      else setError(failure.message);
      setReview(false);setSeat(null);
    } finally {refresh();submitting.current=false;setBusy(false);}
  }
  return <><PageHeading title="Book a Seat" eyebrow="UNIVERSITY TRANSPORT SCHEDULE">Choose your route, pickup stoppage and trip. All times are in Asia/Dhaka.</PageHeading>
    {import.meta.env.VITE_LOCAL_SCHEDULE_PREVIEW === 'true' && <p className="info-note">Local preview: official route and stoppage times, with test bus/driver assignments and test capacity. No live reservation is created.</p>}
    <div className="schedule-filters">
      <label>Travel date<input aria-label="Travel date" type="date" min={today()} value={date} disabled={busy} onChange={e => {setDate(e.target.value);resetJourney();}}/></label>
      <label>Journey direction<select aria-label="Journey direction" value={direction} disabled={busy} onChange={e => {setDirection(e.target.value);resetJourney();}}><option value="inbound">To BRAC University</option><option value="outbound">From BRAC University</option></select></label>
      <label>Route<select aria-label="Route" value={variant} disabled={busy} onChange={e => {setVariant(e.target.value);resetJourney();}}><option value="">Choose a route</option>{variants.map(r => <option key={r.variant_id} value={r.variant_id}>{r.variant_code} · {r.variant_name}</option>)}</select></label>
    </div>
    {!variant && <section className="schedule-route-grid" aria-label="University routes">{variants.map(r => <button type="button" key={r.variant_id} onClick={() => {setVariant(r.variant_id);resetJourney();}}><span className="eyebrow">ROUTE {r.variant_code}</span><strong>{r.variant_name}</strong><span>View stoppages &amp; trips →</span></button>)}</section>}
    <ResourceState state={trips}/>
    {variant && <><div className="section-top"><h2>{route?.variant_name} · {direction === 'inbound' ? 'To campus' : 'From campus'}</h2><button type="button" disabled={busy} onClick={refresh}>Refresh availability</button></div>
      <ResourceState state={schedules}/><ResourceState state={pattern}/>
      {!schedules.loading && !schedules.error && !schedules.data?.length && <EmptyState title="No scheduled service for this date">Choose another date or journey direction. Missing trips are not available to book.</EmptyState>}
      <div className="schedule-trip-grid">{schedules.data?.map(s => {
        const available = trips.data?.find(t => t.id === `schedule:${s.id}`);
        return <button type="button" key={s.id} className="schedule-trip" aria-pressed={scheduleId === s.id} disabled={busy} onClick={() => {setScheduleId(s.id);clearSelection();}}>
          <span>{s.label}</span><strong>{s.departure_time} <span>→ {s.arrival_time || 'Arrival not published'}</span></strong><span>{s.variant_name}</span>
          <small>{available ? available.bus : 'Schedule preview · not open for booking'}</small><Badge status={available ? available.bookingOpen ? 'Booking open' : 'Booking closed' : !s.verified || !s.variant_verified ? 'Awaiting verification' : 'Awaiting assignment'}/>
        </button>;
      })}</div>
    </>}
    {schedule && pattern.data && <section className="schedule-stops" aria-label="Route stoppages"><div className="section-top"><h2>Choose your stoppage</h2><span>{schedule.label} · {schedule.departure_time}</span></div>
      {!trip && <p className="info-note">This schedule is available to preview. Booking requires a verified, active schedule with an assigned bus and driver on the selected service date.</p>}
      <div className="schedule-filters"><label>Pickup stoppage<select aria-label="Pickup stoppage" value={pickupId} disabled={busy} onChange={e => {setPickup(e.target.value);setDrop('');setSeat(null);setReview(false);setError('');setConfirmation(null);}}><option value="">Choose where to board</option>{pickups.map(stop => <option key={stop.id} value={stop.id}>{stop.label} · {stop.pickup_time}</option>)}</select></label>
        {supportsDropoff && <label>Destination<select aria-label="Destination" value={dropId} disabled={busy || !pickup} onChange={e => {setDrop(e.target.value);setReview(false);}}><option value="">Choose destination</option>{dropoffs.map(stop => <option key={stop.id} value={stop.id}>{stop.label} · {stop.arrival_time}</option>)}</select></label>}
      </div>
      {direction === 'outbound' && <p className="info-note">Board at BRAC University. Return-trip intermediate stoppages and arrival times were not published in the supplied schedule.</p>}
      <ol className="schedule-timeline">{stops.map(stop => <li key={stop.id} className={stop.id === pickupId ? 'selected-stop' : ''}><span>{stop.label}</span><strong>{stop.pickup_time || stop.arrival_time || 'Not published'}</strong><small>{stop.arrival_time ? 'Arrival' : 'Pickup'}</small></li>)}</ol>
    </section>}
    {trip && <><ResourceState state={availability}/>{availability.data && <>
      <h2>Select seat or standing</h2><p className="info-note">{availability.data.genderKnown ? `Your verified profile: ${availability.data.profileGender || 'known'}.` : <>Complete your <Link to="/profile">student profile</Link> for reserved-seat and standing eligibility.</>}</p>
      {!availability.data.bookingOpen && <p className="info-note">Booking is currently closed. You may select and review your journey; Confirm &amp; Book remains disabled. Window: {stamp(trip.opensAt)} – {stamp(trip.closesAt)}.</p>}
      <SeatMap data={availability.data} selected={seat} busy={busy} onSelect={choice => {setSeat(current => current === choice ? null : choice);setReview(false);setError('');}}/>
      <button type="button" className="primary-button" disabled={busy || uncertain || !validStops || !selectable} onClick={() => setReview(true)}>Confirm Booking</button>
      {!validStops && <p className="muted">Choose your pickup stoppage{supportsDropoff ? ' and destination' : ''} to continue.</p>}
    </>}</>}
    {review && trip && <section className="schedule-review" aria-label="Booking review"><h2>Review your booking</h2><dl><dt>Route</dt><dd>{trip.route}</dd><dt>Trip</dt><dd>{schedule.label} · {trip.departureTime}</dd><dt>Travel date</dt><dd>{date}</dd><dt>Pickup</dt><dd>{pickup.label} · {pickup.pickup_time}</dd>{dropoff && <><dt>Destination</dt><dd>{dropoff.label} · {dropoff.arrival_time}</dd></>}<dt>Bus</dt><dd>{trip.bus}</dd><dt>Seat / Standing</dt><dd>{seat === 'standing' ? 'Standing' : `Seat ${seatLabel(seat)} (${seat})`}</dd></dl>
      <button type="button" className="primary-button" disabled={busy || uncertain || !availability.data?.bookingOpen} onClick={confirm}>{busy ? 'Booking…' : 'Confirm & Book'}</button><button type="button" disabled={busy} onClick={() => setReview(false)}>Edit selection</button>
    </section>}
    {error && <p role="alert" className="m2-error">{error}</p>}{uncertain && <Link to="/bookings">Check Booking History</Link>}
    {confirmation && <section aria-label="Booking confirmation"><p role="status">Booking confirmed successfully.</p><BookingSummary booking={confirmation}/><Link to={`/bookings/${confirmation.id}`}>View booking</Link></section>}
  </>;
}
