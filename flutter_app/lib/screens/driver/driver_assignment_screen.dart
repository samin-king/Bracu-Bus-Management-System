import 'package:flutter/material.dart';

import '../../models/driver.dart';
import '../../models/trip.dart';
import '../../services/api_client.dart';
import '../../services/driver_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/async_body.dart';
import '../../widgets/record_card.dart';
import '../../widgets/role_gate.dart';

class DriverAssignmentScreen extends StatelessWidget {
  const DriverAssignmentScreen({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => RoleGate(
        api: api,
        role: TransportRole.authority,
        builder: (_) => _AssignmentBody(api: api),
      );
}

class _Choices {
  _Choices(this.drivers, this.trips);
  final List<Driver> drivers;
  final List<Trip> trips;
}

class _AssignmentBody extends StatefulWidget {
  const _AssignmentBody({required this.api});
  final ApiClient api;
  @override
  State<_AssignmentBody> createState() => _AssignmentBodyState();
}

class _AssignmentBodyState extends State<_AssignmentBody> {
  late final service = DriverService(widget.api);
  late Future<_Choices> future;
  int? tripId, driverId;
  bool busy = false;
  String? error;
  Trip? result;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_Choices> load() async {
    final lists = await Future.wait<dynamic>([
      service.list(),
      TripService(widget.api).list(),
    ]);
    return _Choices(
      (lists[0] as List<Driver>).where((d) => d.status == 'ACTIVE').toList(),
      (lists[1] as List<Trip>).where((t) => t.status == 'SCHEDULED').toList(),
    );
  }

  void reload() => setState(() {
        tripId = null;
        driverId = null;
        error = null;
        future = load();
      });
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final updated = await service.assign(tripId!, driverId);
      if (mounted) {
        setState(() {
          result = updated;
          tripId = null;
          driverId = null;
          future = load();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Driver Assignment'),
            actions: [
              IconButton(
                onPressed: busy ? null : reload,
                tooltip: 'Refresh choices',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: AsyncBody<_Choices>(
              future: future,
              retry: reload,
              builder: (choices) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (error != null)
                    Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  if (result != null) ...[
                    const Text('Driver assignment saved'),
                    RecordCard(record: result!),
                  ],
                  if (choices.trips.isEmpty)
                    const Text('No scheduled trips available.')
                  else ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey('trip-$tripId'),
                      initialValue: tripId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Scheduled trip',
                      ),
                      items: choices.trips
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.bus.title} / ${t.schedule} / ${t.driverName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (id) => setState(() {
                                tripId = id;
                                final assigned = choices.trips
                                    .firstWhere((t) => t.id == id)
                                    .driverId;
                                driverId =
                                    choices.drivers.any((d) => d.id == assigned)
                                        ? assigned
                                        : null;
                              }),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      key: ValueKey('driver-$tripId-$driverId'),
                      initialValue: driverId ?? 0,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Driver'),
                      items: [
                        const DropdownMenuItem(
                            value: 0, child: Text('Unassigned')),
                        ...choices.drivers.map(
                          (d) => DropdownMenuItem(
                              value: d.id, child: Text(d.title)),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (id) =>
                              setState(() => driverId = id == 0 ? null : id),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy || tripId == null ? null : save,
                      child: Text(busy ? 'Saving...' : 'Save assignment'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
