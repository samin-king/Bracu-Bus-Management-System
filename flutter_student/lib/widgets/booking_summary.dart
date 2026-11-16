import 'package:flutter/material.dart';

import '../models/booking.dart';

/// Supply the existing ticket renderer when its real contract is available.
/// Called only with a server-confirmed booking; cancelled bookings never render QR.
typedef ConfirmedTicketBuilder = Widget Function(
  BuildContext context,
  Booking booking,
);

class BookingSummary extends StatelessWidget {
  const BookingSummary({super.key, required this.booking, this.ticketBuilder});
  final Booking booking;
  final ConfirmedTicketBuilder? ticketBuilder;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in {
            'Booking ID': booking.id,
            'Route': booking.trip.route,
            'Trip': booking.trip.id,
            if (booking.trip.json['variantCode'] != null)
              'Route variant': booking.trip.json['variantCode'],
            'Bus': booking.trip.bus,
            'Departure': '${booking.date} ${booking.trip.time} (Asia/Dhaka)',
            'Seat/Standing': booking.place,
            if (booking.trip.json['direction'] != null)
              'Direction': booking.trip.json['direction'],
            if (booking.trip.json['pickup'] != null)
              'Pickup': booking.trip.json['pickup']['name'],
            if (booking.trip.json['pickup'] != null)
              'Scheduled pickup':
                  '${booking.trip.json['pickup']['pickupTime']} (Asia/Dhaka)',
            if (booking.trip.json['dropoff'] != null)
              'Drop-off': booking.trip.json['dropoff']['name'],
            'Fare': booking.fare,
            'Status': booking.status,
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text('${entry.key}: ${entry.value}'),
            ),
          if (booking.status == 'confirmed')
            ticketBuilder?.call(context, booking) ??
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'QR ticket unavailable: the connected booking API does not provide a QR ticket.',
                  ),
                ),
        ],
      );
}
