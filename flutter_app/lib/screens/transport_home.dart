import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'bus/bus_screen.dart';
import 'routes/route_screen.dart';
import 'trips/trip_screen.dart';
import 'driver/driver_screen.dart';
import 'driver/driver_assignment_screen.dart';

/// Existing transport navigation, hosted by the single authenticated router.
class TransportHome extends StatelessWidget {
  const TransportHome({required this.api, super.key});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transport Management')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _link(context, 'Buses', () => BusScreen(api: api)),
          _link(context, 'Routes', () => RouteScreen(api: api)),
          _link(context, 'Trips', () => TripScreen(api: api)),
          _link(context, 'Drivers', () => DriverScreen(api: api)),
          _link(
            context,
            'Driver Assignment',
            () => DriverAssignmentScreen(api: api),
          ),
        ],
      ),
    ),
  );
  Widget _link(BuildContext context, String title, Widget Function() screen) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.tonal(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => screen())),
          child: Padding(padding: const EdgeInsets.all(12), child: Text(title)),
        ),
      );
}
