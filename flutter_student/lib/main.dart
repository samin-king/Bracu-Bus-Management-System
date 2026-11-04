import 'package:flutter/material.dart';

import 'student_booking.dart';

/// The authentication owner supplies an authenticated StudentApi instance.
class StudentBookingApp extends StatelessWidget {
  const StudentBookingApp({super.key, required this.api, this.ticketBuilder});
  final StudentApi api;
  final ConfirmedTicketBuilder? ticketBuilder;
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: studentTheme(),
        home: _BookingHost(api: api, ticketBuilder: ticketBuilder),
      );
}

class _BookingHost extends StatefulWidget {
  const _BookingHost({required this.api, this.ticketBuilder});
  final StudentApi api;
  final ConfirmedTicketBuilder? ticketBuilder;
  @override
  State<_BookingHost> createState() => _BookingHostState();
}

class _BookingHostState extends State<_BookingHost> {
  late final BookingState state = BookingState(widget.api);
  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StudentBookingScreen(state: state, ticketBuilder: widget.ticketBuilder);
}
