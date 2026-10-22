import React, { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useParams } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth.js';
import { member2Api as api } from '../services/member2Api.js';
import './member2.css';
const categories = ['Driver behaviour', 'Bus condition', 'Route problem', 'Overcrowding', 'Late bus', 'Seat/booking issue', 'Other'];
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
const stamp = value => new Date(value).toLocaleString('en-GB', { timeZone: 'Asia/Dhaka' });
function ErrorMessage({ error }) { return error && <p role="alert" className="m2-error">{error}</p>; }
function useLoad(load, dependencies = []) {
  const [state, set] = useState({ loading: true, data: null, error: '' });
  const [version, update] = useState(0);
  useEffect(() => {
    let active = true;
    set({ loading: true, data: null, error: '' });
    Promise.resolve().then(load).then(data => { if (active) set({ loading: false, data, error: '' }); }, error => { if (active) set({ loading: false, data: null, error: error.message }); });
    return () => { active = false; };
  }, [...dependencies, version]);
  return { ...state, reload: () => update(v => v + 1) };
}
function LoadState({ state }) {
  return <>{state.loading && <p role="status">Loading…</p>}<ErrorMessage error={state.error} />{state.error && <button type="button" onClick={state.reload}>Retry</button>}</>;
}
export function StudentLayout() {
  const { user, logout } = useAuth();
  const [error, setError] = useState(''), [busy, setBusy] = useState(false);
  async function signOut() { setBusy(true); try { await logout(); } catch { setError('Sign out failed. Please try again.'); } finally { setBusy(false); } }
  return <div className="member2"><header><Link to="/">BRACU SMART TRANSPORT</Link><span>{user.name}</span></header>
    <nav aria-label="Student navigation"><NavLink to="/" end>Dashboard</NavLink><NavLink to="/book">Book Bus</NavLink><NavLink to="/bookings">My Bookings</NavLink><NavLink to="/complaints">Complaints</NavLink><button disabled={busy} onClick={signOut}>{busy ? 'Signing out…' : 'Logout'}</button></nav>
    <main><ErrorMessage error={error} /><Outlet /></main></div>;
}
export function StudentDashboard() {
  return <><h1>Student Dashboard</h1><p>Plan your journey with BRACU transport.</p><div className="m2-cards"><Link to="/book">Book Bus</Link><Link to="/bookings">My Bookings</Link><Link to="/complaints">Complaints</Link></div><p>All booking times use Asia/Dhaka. You may confirm up to four trips per travel date.</p></>;
}
export function BookingSummary({ booking }) {
  const trip = booking.trip_snapshot;
  return <dl><dt>Booking ID</dt><dd>{booking.id}</dd><dt>Trip</dt><dd>{booking.trip_id}</dd><dt>Bus</dt><dd>{trip.bus}</dd><dt>Route</dt><dd>{trip.route}</dd><dt>Travel date</dt><dd>{booking.travel_date}</dd><dt>Trip time</dt><dd>{trip.departureTime} (Asia/Dhaka)</dd><dt>Seat</dt><dd>{booking.standing ? 'Standing' : booking.seat_number}</dd><dt>Status</dt><dd>{booking.status}</dd>{booking.created_at && <><dt>Created time</dt><dd>{stamp(booking.created_at)}</dd></>}</dl>;
}
export function BookBus() {
  const [date, setDate] = useState(today), [tripId, setTripId] = useState(''), [seat, setSeat] = useState(null);
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [confirmation, setConfirmation] = useState(null);
  const trips = useLoad(() => api.trips(date), [date]);
  const seats = useLoad(() => tripId ? api.seats(tripId, date) : null, [tripId, date]);
  async function book() {
    setBusy(true); setError('');
    try {
      const result = await api.book({ tripId, travelDate: date, standing: seat === 'standing', seatNumber: seat === 'standing' ? null : seat });
      setConfirmation(result); setSeat(null); seats.reload();
    } catch (failure) { setError(failure.message); setSeat(null); seats.reload(); }
    finally { setBusy(false); }
  }
  return <><h1>Book Bus</h1><p>Choose a travel date, trip and seat. Seats 1–18 are reserved for women.</p>
    <label>Travel date<input type="date" value={date} min={today()} disabled={busy} onChange={e => { setDate(e.target.value); setTripId(''); setSeat(null); setConfirmation(null); setError(''); }} /></label>
    <LoadState state={trips} />
    {trips.data && <><h2>Available trips</h2>{!trips.data.length && <p>No trips are available for this date.</p>}<div className="m2-cards">{trips.data.map(t => <button key={t.id} disabled={busy} aria-pressed={tripId === t.id} onClick={() => { setTripId(t.id); setSeat(null); setConfirmation(null); setError(''); }}>{t.bus} · {t.route} · {t.departureTime}<small>{t.bookingOpen ? 'Booking open' : 'Booking closed'}</small><small>Window: {stamp(t.opensAt)} – {stamp(t.closesAt)}</small></button>)}</div></>}
    {tripId && <><LoadState state={seats} />{seats.data && <><h2>Select seat</h2><p>Available · Selected · Booked · Reserved</p>{!seats.data.genderKnown && <p>Your student profile gender is unverified. Reserved seats and standing cannot be booked.</p>}
      {!seats.data.bookingOpen && <p>Booking is currently closed for this trip.</p>}
      <div className="m2-seats" aria-label="Seat map">{seats.data.seats.map(s => <button key={s.number} className={`m2-seat ${seat === s.number ? 'selected' : s.state.toLowerCase()}`} disabled={busy || !s.selectable || !seats.data.bookingOpen} aria-pressed={seat === s.number} aria-label={`Seat ${s.number} ${seat === s.number ? 'Selected' : s.state}`} onClick={() => setSeat(s.number)}>{s.number}<small>{seat === s.number ? 'Selected' : s.state}</small></button>)}</div>
      {seats.data.standingAvailable > 0 && <button disabled={busy || !seats.data.bookingOpen} aria-pressed={seat === 'standing'} onClick={() => setSeat('standing')}>Standing ({seats.data.standingAvailable} available, male students only)</button>}
      <button disabled={busy || seat === null || !seats.data.bookingOpen} onClick={book}>{busy ? 'Booking…' : 'Confirm booking'}</button></>}</>}
    <ErrorMessage error={error} />{confirmation && <section aria-label="Booking confirmation"><p role="status">Booking confirmed successfully.</p><BookingSummary booking={confirmation} /><Link to={`/bookings/${confirmation.id}`}>View booking</Link></section>}</>;
}
export function MyBookings() {
  const state = useLoad(api.bookings);
  return <><h1>My Bookings</h1><LoadState state={state} />{state.data && ['Upcoming', 'Past', 'Cancelled'].map(section => <section key={section}><h2>{section}</h2>{!state.data.some(b => b.section === section) && <p>No {section.toLowerCase()} bookings.</p>}{state.data.filter(b => b.section === section).map(b => <article key={b.id}><BookingSummary booking={b} /><Link to={`/bookings/${b.id}`}>Booking details #{b.id}</Link></article>)}</section>)}</>;
}
export function BookingDetails() {
  const { id } = useParams(), state = useLoad(() => api.booking(id), [id]);
  const [ask, setAsk] = useState(false), [busy, setBusy] = useState(false), [error, setError] = useState(''), [success, setSuccess] = useState('');
  async function cancel() {
    setBusy(true); setError('');
    try { await api.cancel(id); setAsk(false); setSuccess('Booking cancelled. The seat is available again.'); state.reload(); }
    catch (failure) { setError(failure.message); } finally { setBusy(false); }
  }
  return <><h1>Booking Details</h1><LoadState state={state} /><ErrorMessage error={error} />{success && <p role="status">{success}</p>}{state.data && <><BookingSummary booking={state.data} />{state.data.section === 'Upcoming' && <button onClick={() => setAsk(true)}>Cancel booking</button>}
    {ask && <section role="dialog" aria-modal="true" aria-labelledby="cancel-title"><h2 id="cancel-title">Cancel this booking?</h2><p>Your seat will be released.</p><button disabled={busy} onClick={cancel}>{busy ? 'Cancelling…' : 'Yes, cancel booking'}</button><button disabled={busy} onClick={() => setAsk(false)}>Keep booking</button></section>}</>}<Link to="/bookings">Back to My Bookings</Link></>;
}
export function Complaints() {
  const state = useLoad(api.complaints), bookings = useLoad(api.bookings);
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [success, setSuccess] = useState('');
  async function submit(e) {
    e.preventDefault(); const form = e.currentTarget, input = Object.fromEntries(new FormData(form));
    setBusy(true); setError(''); setSuccess('');
    try { await api.complain(input); form.reset(); setSuccess('Complaint submitted successfully.'); state.reload(); }
    catch (failure) { setError(failure.message); } finally { setBusy(false); }
  }
  return <><h1>Complaints</h1><form onSubmit={submit}><fieldset disabled={busy}><legend>Submit a complaint</legend><label>Category<select name="category">{categories.map(c => <option key={c}>{c}</option>)}</select></label><label>Subject<input name="subject" required maxLength={160} /></label><label>Description<textarea name="description" required maxLength={5000} /></label>
    <label>Related booking (optional)<select name="bookingId"><option value="">None</option>{bookings.data?.map(b => <option key={b.id} value={b.id}>#{b.id} · {b.trip_snapshot.route} · {b.travel_date}</option>)}</select></label><LoadState state={bookings} /><button type="submit">{busy ? 'Submitting…' : 'Submit complaint'}</button></fieldset></form>
    <ErrorMessage error={error} />{success && <p role="status">{success}</p>}<h2>My Complaints</h2><LoadState state={state} />{state.data && !state.data.length && <p>No complaints submitted.</p>}{state.data?.map(c => <article key={c.id}><h3><Link to={`/complaints/${c.id}`}>#{c.id} {c.subject}</Link></h3><p>{c.category} · {c.status}</p><p className="m2-description">{c.description}</p><p>{stamp(c.created_at)}</p></article>)}</>;
}
export function ComplaintDetails() {
  const { id } = useParams(), state = useLoad(() => api.complaint(id), [id]);
  return <><h1>Complaint Details</h1><LoadState state={state} />{state.data && <article><h2>#{state.data.id} {state.data.subject}</h2><p>{state.data.category} · {state.data.status}</p><p className="m2-description">{state.data.description}</p><p>{stamp(state.data.created_at)}</p>{state.data.booking_id && <Link to={`/bookings/${state.data.booking_id}`}>Related booking</Link>}</article>}<Link to="/complaints">Back to My Complaints</Link></>;
}
