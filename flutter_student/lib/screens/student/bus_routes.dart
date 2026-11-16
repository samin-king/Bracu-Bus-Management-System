import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../models/transport.dart';
import '../../services/transport_api.dart';

class BusRoutesScreen extends StatefulWidget {
  const BusRoutesScreen(
      {super.key, required this.api, this.selectForBooking = false});
  final TransportApi api;
  final bool selectForBooking;
  @override
  State<BusRoutesScreen> createState() => _BusRoutesScreenState();
}

class _BusRoutesScreenState extends State<BusRoutesScreen> {
  late Future<List<RoutePattern>> routes = widget.api.routes();
  void reload() {
    final pending = widget.api.routes();
    setState(() {
      routes = pending;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bus Routes'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
        ]),
        body: FutureBuilder<List<RoutePattern>>(
            future: routes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snapshot.error}'),
                  TextButton(onPressed: reload, child: const Text('Retry'))
                ]));
              final data = snapshot.data!;
              if (data.isEmpty)
                return const Center(
                    child: Text('No routes have been imported.'));
              return ListView(padding: const EdgeInsets.all(16), children: [
                const Text(
                    'Official schedule effective 3 October 2026. Entries requiring verification are marked. Operational availability depends on assignments and closures.'),
                for (final route in data)
                  Card(
                      child: ListTile(
                    title: Text('Route ${route.code} · ${route.name}'),
                    subtitle: Text(
                        '${route.direction}${route.verified ? '' : ' · Requires verification'}'),
                    onTap: widget.selectForBooking
                        ? () => Navigator.pop(context, route)
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => BusStoppagesScreen(
                                    api: widget.api, route: route))),
                    trailing: IconButton(
                        tooltip: 'View stoppages',
                        icon: const Icon(Icons.list_alt),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => BusStoppagesScreen(
                                    api: widget.api, route: route)))),
                  )),
              ]);
            }),
      );
}

class BusStoppagesScreen extends StatefulWidget {
  const BusStoppagesScreen({super.key, required this.api, required this.route});
  final TransportApi api;
  final RoutePattern route;
  @override
  State<BusStoppagesScreen> createState() => _BusStoppagesScreenState();
}

class _BusStoppagesScreenState extends State<BusStoppagesScreen> {
  late Future<Json> pattern = widget.api.pattern(widget.route.id);
  void reload() {
    final pending = widget.api.pattern(widget.route.id);
    setState(() {
      pattern = pending;
    });
  }

  String search = '';
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text('${widget.route.name} · ${widget.route.direction}')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                decoration: const InputDecoration(
                    labelText: 'Search stoppages',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (value) =>
                    setState(() => search = value.toLowerCase()))),
        Expanded(
            child: FutureBuilder<Json>(
                future: pattern,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${snapshot.error}'),
                      TextButton(onPressed: reload, child: const Text('Retry'))
                    ]));
                  final data = snapshot.data!;
                  final stops = (data['stops'] as List)
                      .cast<Json>()
                      .where((s) =>
                          (s['label'] as String).toLowerCase().contains(search))
                      .toList();
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    const Text(
                        'Timings reflect current transport administration updates.'),
                    if (data['sequence_verified'] != true)
                      const Text(
                          'Outbound drop-off stops/order are not supplied by this source. Only the documented departure point is shown.'),
                    if (!widget.route.verified)
                      const Text(
                          'This route entry requires source verification before bookings can be activated.'),
                    if (stops.isEmpty) const Text('No matching stoppages.'),
                    for (final stop in stops)
                      Card(
                          child: ListTile(
                              leading: CircleAvatar(
                                  child: Text('${stop['sequence']}')),
                              title: Text(stop['label'] as String),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final entry
                                        in (stop['times'] as List).cast<Json>())
                                      Text(
                                          '${entry['label']}: ${entry['pickup_time'] ?? entry['arrival_time']} · ${entry['arrival_time'] == null ? 'Pickup' : 'Arrival'}'),
                                  ]))),
                  ]);
                })),
      ]));
}
