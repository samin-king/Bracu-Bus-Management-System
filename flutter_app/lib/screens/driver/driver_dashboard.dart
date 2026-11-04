import 'package:flutter/material.dart';

import '../../models/driver.dart';
import '../../models/trip.dart';
import '../../services/api_client.dart';
import '../../services/driver_service.dart';
import '../../widgets/async_body.dart';
import '../../widgets/record_card.dart';
import '../../widgets/role_gate.dart';
import 'passenger_list_screen.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => RoleGate(
        api: api,
        role: TransportRole.driver,
        builder: (_) => _DashboardBody(api: api),
      );
}

class _DashboardData {
  _DashboardData(this.driver, this.trips);
  final Driver driver;
  final List<Trip> trips;
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({required this.api});
  final ApiClient api;
  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  late final service = DriverService(widget.api);
  late Future<_DashboardData> future;
  bool busy = false;
  String? error, notice;
  Future<_DashboardData> load() async {
    final results = await Future.wait<dynamic>([
      service.me(),
      service.assignedTrips(),
    ]);
    return _DashboardData(results[0] as Driver, results[1] as List<Trip>);
  }

  @override
  void initState() {
    super.initState();
    future = load();
  }

  void reload() => setState(() {
        error = null;
        future = load();
      });
  Future<void> action(_DashboardData data, Trip trip) async {
    final operation = trip.action!;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final updated = await service.transition(trip.id, operation);
      if (!mounted) return;
      setState(() {
        data.trips[data.trips.indexWhere((t) => t.id == updated.id)] = updated;
        notice = operation == 'start' ? 'Trip started' : 'Trip completed';
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Driver Dashboard'),
          actions: [
            IconButton(
              onPressed: busy ? null : reload,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: AsyncBody<_DashboardData>(
            future: future,
            retry: reload,
            builder: (data) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                RecordCard(record: data.driver),
                if (data.driver.status != 'ACTIVE')
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Your driver profile is inactive. Contact transport management.',
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (notice != null)
                  Padding(
                      padding: const EdgeInsets.all(12), child: Text(notice!)),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Assigned Trips', style: TextStyle(fontSize: 22)),
                ),
                if (data.trips.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No assigned trips.'),
                  ),
                for (final trip in data.trips)
                  RecordCard(
                    record: trip,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PassengerListScreen(api: widget.api),
                          ),
                        ),
                        child: const Text('View passengers'),
                      ),
                      if (trip.action != null)
                        FilledButton(
                          onPressed: busy || data.driver.status != 'ACTIVE'
                              ? null
                              : () => action(data, trip),
                          child: Text(
                            busy
                                ? 'Updating...'
                                : trip.action == 'start'
                                    ? 'Start Trip'
                                    : 'Stop Trip',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
}
