import 'package:flutter/material.dart';

import '../models/transport_record.dart';
import '../models/trip.dart';
import '../services/api_client.dart';
import '../services/bus_service.dart';
import '../services/route_service.dart';
import '../services/resource_service.dart';
import '../widgets/async_body.dart';
import '../widgets/role_gate.dart';

class RecordForm<T extends TransportRecord> extends StatelessWidget {
  const RecordForm({
    super.key,
    required this.service,
    required this.kind,
    this.item,
  });
  final ResourceService<T> service;
  final String kind;
  final T? item;
  @override
  Widget build(BuildContext context) => RoleGate(
        api: service.api,
        role: TransportRole.authority,
        builder: (_) => _FormBody<T>(service: service, kind: kind, item: item),
      );
}

class _FormBody<T extends TransportRecord> extends StatefulWidget {
  const _FormBody({required this.service, required this.kind, this.item});
  final ResourceService<T> service;
  final String kind;
  final T? item;
  @override
  State<_FormBody<T>> createState() => _FormBodyState<T>();
}

class _FormBodyState<T extends TransportRecord> extends State<_FormBody<T>> {
  final key = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final choices = <String, Map<String, String>>{};
  late Future<void> dependencies;
  bool busy = false;
  String? error;
  late String status;
  bool get historical =>
      widget.item is Trip &&
      (widget.item as Trip).driverId != null &&
      ['ACTIVE', 'COMPLETED', 'STOPPED'].contains(widget.item!.status);
  Map<String, String> get fields => switch (widget.kind) {
        'bus' => {
            'bus_number': 'Bus number',
            'registration_number': 'Registration number (optional)',
            'capacity': 'Capacity',
          },
        'route' => {
            'route_name': 'Route name',
            'origin': 'Origin',
            'destination': 'Destination',
            'stops': 'Stops (one per line, optional)',
          },
        'driver' => {'name': 'Name', 'license_number': 'License number'},
        _ => {
            'bus_id': 'Bus',
            'route_id': 'Route',
            'travel_date': 'Travel date (YYYY-MM-DD, Dhaka)',
            'departure_time': 'Departure time (HH:mm, Dhaka)',
          },
      };
  List<String> get statuses => switch (widget.kind) {
        'bus' => ['ACTIVE', 'INACTIVE', 'MAINTENANCE'],
        'driver' => ['ACTIVE', 'INACTIVE'],
        'trip' => ['SCHEDULED', 'ACTIVE', 'STOPPED', 'COMPLETED', 'CANCELLED'],
        _ => [],
      };
  @override
  void initState() {
    super.initState();
    final data = widget.item?.writable ?? {};
    status = data['status'] as String? ??
        (widget.kind == 'trip' ? 'SCHEDULED' : 'ACTIVE');
    for (final name in fields.keys) {
      final value = data[name];
      controllers[name] = TextEditingController(
        text: value is List ? value.join('\n') : value?.toString() ?? '',
      );
    }
    dependencies = loadChoices();
  }

  Future<void> loadChoices() async {
    if (widget.kind != 'trip') return;
    final result = await Future.wait([
      BusService(widget.service.api).list(),
      RouteService(widget.service.api).list(),
    ]);
    choices['bus_id'] = {for (final b in result[0]) '${b.id}': b.title};
    choices['route_id'] = {for (final r in result[1]) '${r.id}': r.title};
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? validate(String name, String? raw) {
    final value = raw?.trim() ?? '';
    if (name == 'registration_number' && value.isEmpty) return null;
    if (name == 'stops') {
      final stops =
          value.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty);
      return stops.length > 100 || stops.any((s) => s.length > 250)
          ? 'Use at most 100 stops, each at most 250 characters.'
          : null;
    }
    if (value.isEmpty) return 'This field is required.';
    if (['capacity', 'bus_id', 'route_id'].contains(name)) {
      final n = int.tryParse(value);
      return n == null || n < 1 || n > 2147483647
          ? 'Enter a positive integer up to 2147483647.'
          : null;
    }
    if (name == 'travel_date') {
      final date = DateTime.tryParse(value);
      return !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
              value.startsWith('0000') ||
              date == null ||
              date.toIso8601String().substring(0, 10) != value
          ? 'Enter a valid date as YYYY-MM-DD.'
          : null;
    }
    if (name == 'departure_time') {
      return RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$').hasMatch(value)
          ? null
          : 'Enter a valid time as HH:mm.';
    }
    return value.length > 250 ? 'Maximum 250 characters.' : null;
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final Json body = {
      for (final e in controllers.entries) e.key: e.value.text.trim(),
    };
    if (statuses.isNotEmpty) body['status'] = status;
    for (final name in ['capacity', 'bus_id', 'route_id']) {
      if (body.containsKey(name)) body[name] = int.parse(body[name] as String);
    }
    if (body['registration_number'] == '') body['registration_number'] = null;
    if (body.containsKey('stops')) {
      body['stops'] = (body['stops'] as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    try {
      await widget.service.save(body, id: widget.item?.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved successfully')));
      Navigator.pop(context, true);
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
            title:
                Text('${widget.item == null ? 'Add' : 'Edit'} ${widget.kind}'),
          ),
          body: SafeArea(
            child: AsyncBody<void>(
              future: dependencies,
              retry: () => setState(() {
                dependencies = loadChoices();
              }),
              builder: (_) => Form(
                key: key,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (historical)
                      const Text(
                        'The assigned trip schedule is locked. Use driver controls for trip status.',
                      ),
                    for (final field in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: choices.containsKey(field.key)
                            ? DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: choices[field.key]!.containsKey(
                                  controllers[field.key]!.text,
                                )
                                    ? controllers[field.key]!.text
                                    : null,
                                decoration:
                                    InputDecoration(labelText: field.value),
                                items: choices[field.key]!
                                    .entries
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(
                                          e.value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: busy || historical
                                    ? null
                                    : (v) =>
                                        controllers[field.key]!.text = v ?? '',
                                validator: (v) => validate(field.key, v),
                              )
                            : TextFormField(
                                controller: controllers[field.key],
                                enabled: !busy && !historical,
                                maxLines: field.key == 'stops' ? 4 : 1,
                                decoration: InputDecoration(
                                  labelText: field.value,
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: field.key == 'capacity'
                                    ? TextInputType.number
                                    : TextInputType.text,
                                validator: (v) => validate(field.key, v),
                              ),
                      ),
                    if (statuses.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: statuses
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: busy ||
                                (widget.item is Trip &&
                                    (widget.item as Trip).driverId != null)
                            ? null
                            : (v) => setState(() => status = v!),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy || historical ? null : save,
                      child: Text(busy ? 'Saving...' : 'Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
