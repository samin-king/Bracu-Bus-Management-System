import React from 'react';
import {Badge} from './Ui.jsx';
import {seatLabel} from './SeatMap.jsx';
const stamp=value=>new Date(value).toLocaleString('en-GB',{timeZone:'Asia/Dhaka'});
export function BookingSummary({ booking }) {
  const trip = booking.trip_snapshot;
  return <dl><dt>Booking ID</dt><dd>{booking.id}</dd><dt>Trip</dt><dd>{booking.trip_id}</dd><dt>Bus</dt><dd>{trip.bus}</dd><dt>Route</dt><dd>{trip.route}</dd><dt>Travel date</dt><dd>{booking.travel_date}</dd><dt>Trip time</dt><dd>{trip.departureTime} (Asia/Dhaka)</dd><dt>Seat</dt><dd>{booking.standing ? 'Standing' : `${seatLabel(booking.seat_number)} (Seat ${booking.seat_number})`}</dd>{trip.pickup && <><dt>Pickup stoppage</dt><dd>{trip.pickup.name} · {trip.pickup.pickupTime}</dd></>}{trip.dropoff && <><dt>Drop-off</dt><dd>{trip.dropoff.name} · {trip.dropoff.arrivalTime}</dd></>}<dt>Status</dt><dd><Badge status={booking.status}/></dd>{booking.created_at && <><dt>Created time</dt><dd>{stamp(booking.created_at)}</dd></>}</dl>;
}
