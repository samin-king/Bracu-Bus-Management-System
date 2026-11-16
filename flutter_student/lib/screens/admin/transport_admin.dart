import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/transport_api.dart';

class TransportAdminEntry extends StatefulWidget {
  const TransportAdminEntry({super.key, required this.api});
  final TransportApi api;
  @override
  State<TransportAdminEntry> createState() => _TransportAdminEntryState();
}

class _TransportAdminEntryState extends State<TransportAdminEntry> {
  late final Future<bool> access = widget.api.adminAccess();
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: access,
      builder: (context, snapshot) => snapshot.data == true
          ? OutlinedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => TransportAdminScreen(api: widget.api))),
              child: const Text('Transport administration'))
          : const SizedBox.shrink());
}

class TransportAdminScreen extends StatefulWidget {
  const TransportAdminScreen({super.key, required this.api});
  final TransportApi api;
  @override
  State<TransportAdminScreen> createState() => _TransportAdminScreenState();
}

class _TransportAdminScreenState extends State<TransportAdminScreen> {
  String section = 'schedules';
  int page = 1;
  late Future<Json> content = load();
  Future<Json> load() async {
    if (section == 'routes')
      return {
        'items': (await widget.api.routes()).map((r) => r.json).toList(),
        'hasMore': false
      };
    return section == 'schedules'
        ? widget.api.schedules(page: page, admin: true)
        : widget.api.resources(section, page: page);
  }

  void refresh() {
    final pending = load();
    setState(() {
      content = pending;
    });
  }

  Future<void> edit([Json? row]) async {
    if (section == 'routes') {
      if (row != null)
        await Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => AdminStopsScreen(api: widget.api, route: row)));
    } else if (section == 'schedules') {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  AdminScheduleScreen(api: widget.api, schedule: row)));
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => AdminResourceScreen(
                  api: widget.api, kind: section, resource: row)));
    }
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Transport administration'), actions: [
        IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))
      ]),
      floatingActionButton: section == 'routes'
          ? null
          : FloatingActionButton(
              onPressed: () => edit(), child: const Icon(Icons.add)),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButton<String>(
                isExpanded: true,
                value: section,
                items: [
                  for (final value in [
                    'schedules',
                    'routes',
                    'buses',
                    'drivers',
                    'devices',
                    'exceptions'
                  ])
                    DropdownMenuItem(
                        value: value,
                        child: Text(
                            value == 'exceptions' ? 'Service closures' : value))
                ],
                onChanged: (value) {
                  if (value != null)
                    setState(() {
                      section = value;
                      page = 1;
                      content = load();
                    });
                })),
        Expanded(
            child: FutureBuilder<Json>(
                future: content,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${snapshot.error}'),
                      TextButton(onPressed: refresh, child: const Text('Retry'))
                    ]));
                  final data = snapshot.data!;
                  final items = (data['items'] as List).cast<Json>();
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    const Text(
                        'Only verified, active schedules with real assignments can accept bookings. Changes affecting future confirmed bookings are blocked; preserve the booking before changing operations.'),
                    if (items.isEmpty) const Text('No entries.'),
                    for (final row in items)
                      Card(
                          child: ListTile(
                              title: Text(
                                  '${row['variant_name'] ?? row['name'] ?? row['external_id'] ?? row['travel_date']}'),
                              subtitle: Text(section == 'schedules'
                                  ? '${row['direction']} · ${row['label']} · ${row['departure_time']} · ${row['active'] == true ? 'Active' : 'Inactive'}${row['verified'] == true ? '' : ' · Requires verification'}'
                                  : section == 'routes'
                                      ? '${row['direction']} · ${row['variant_code']}'
                                      : '${row['registration'] ?? row['staff_reference'] ?? row['reason'] ?? ''}'),
                              onTap: () => edit(row))),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                              onPressed: page > 1
                                  ? () {
                                      setState(() {
                                        page--;
                                        content = load();
                                      });
                                    }
                                  : null,
                              child: const Text('Previous')),
                          Text('Page $page'),
                          TextButton(
                              onPressed: data['hasMore'] == true
                                  ? () {
                                      setState(() {
                                        page++;
                                        content = load();
                                      });
                                    }
                                  : null,
                              child: const Text('Next'))
                        ]),
                  ]);
                })),
      ]));
}

Future<String?> chooseResource(
        BuildContext context, TransportApi api, String kind) =>
    showDialog<String>(
        context: context,
        builder: (_) => _ResourcePicker(api: api, kind: kind));

class _ResourcePicker extends StatefulWidget {
  const _ResourcePicker({required this.api, required this.kind});
  final TransportApi api;
  final String kind;
  @override
  State<_ResourcePicker> createState() => _ResourcePickerState();
}

class _ResourcePickerState extends State<_ResourcePicker> {
  int page = 1;
  late Future<Json> data = widget.api.resources(widget.kind);
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text('Select ${widget.kind}'),
          content: SizedBox(
              width: 500,
              height: 400,
              child: FutureBuilder<Json>(
                  future: data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Text('${snapshot.error}');
                    return Column(children: [
                      Expanded(
                          child: ListView(children: [
                        for (final row
                            in (snapshot.data!['items'] as List).cast<Json>())
                          ListTile(
                              title:
                                  Text('${row['name'] ?? row['external_id']}'),
                              subtitle: Text(
                                  '${row['registration'] ?? row['staff_reference'] ?? ''}'),
                              enabled: row['active'] == true,
                              onTap: () =>
                                  Navigator.pop(context, row['id'].toString()))
                      ])),
                      Row(children: [
                        TextButton(
                            onPressed: page > 1
                                ? () => setState(() {
                                      page--;
                                      data = widget.api
                                          .resources(widget.kind, page: page);
                                    })
                                : null,
                            child: const Text('Previous')),
                        TextButton(
                            onPressed: snapshot.data!['hasMore'] == true
                                ? () => setState(() {
                                      page++;
                                      data = widget.api
                                          .resources(widget.kind, page: page);
                                    })
                                : null,
                            child: const Text('Next'))
                      ])
                    ]);
                  })),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'))
          ]);
}

class AdminResourceScreen extends StatefulWidget {
  const AdminResourceScreen(
      {super.key, required this.api, required this.kind, this.resource});
  final TransportApi api;
  final String kind;
  final Json? resource;
  @override
  State<AdminResourceScreen> createState() => _AdminResourceScreenState();
}

class _AdminResourceScreenState extends State<AdminResourceScreen> {
  final fields = <String, TextEditingController>{};
  bool busy = false, active = true;
  String? error, device;
  @override
  void initState() {
    super.initState();
    active = widget.resource?['active'] != false;
    device = widget.resource?['gps_device_id']?.toString();
    final keys = switch (widget.kind) {
      'buses' => ['name', 'registration', 'capacity', 'standing_capacity'],
      'drivers' => ['name', 'staff_reference'],
      'devices' => ['external_id'],
      _ => ['travel_date', 'reason']
    };
    for (final key in keys)
      fields[key] = TextEditingController(
          text: widget.resource?[key]?.toString() ??
              (key == 'standing_capacity' ? '0' : ''));
  }

  @override
  void dispose() {
    for (final field in fields.values) field.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final Json input = {'active': active};
      if (widget.kind == 'buses')
        input.addAll({
          'name': fields['name']!.text,
          'registration': fields['registration']!.text,
          'capacity': int.parse(fields['capacity']!.text),
          'standingCapacity': int.parse(fields['standing_capacity']!.text),
          'gpsDeviceId': device
        });
      if (widget.kind == 'drivers')
        input.addAll({
          'name': fields['name']!.text,
          'staffReference': fields['staff_reference']!.text
        });
      if (widget.kind == 'devices')
        input['externalId'] = fields['external_id']!.text;
      if (widget.kind == 'exceptions')
        input.addAll({
          'travelDate': fields['travel_date']!.text.split('T').first,
          'reason': fields['reason']!.text
        });
      await widget.api.saveResource(widget.kind, input,
          id: widget.kind == 'exceptions'
              ? null
              : widget.resource?['id']?.toString());
      if (mounted) Navigator.pop(context);
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
          appBar: AppBar(title: Text('Manage ${widget.kind}')),
          body: ListView(padding: const EdgeInsets.all(24), children: [
            for (final field in fields.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: field.value,
                    enabled: !busy,
                    decoration: InputDecoration(
                        labelText: switch (field.key) {
                      'staff_reference' => 'Staff reference',
                      'external_id' => 'Actual Traccar device ID',
                      'travel_date' => 'Closure date (YYYY-MM-DD)',
                      'standing_capacity' => 'Standing capacity',
                      _ => field.key
                    }),
                  )),
            if (widget.kind != 'exceptions')
              SwitchListTile(
                  title: const Text('Active'),
                  value: active,
                  onChanged: busy ? null : (v) => setState(() => active = v)),
            if (widget.kind == 'buses')
              OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final value = await chooseResource(
                              context, widget.api, 'devices');
                          if (mounted && value != null)
                            setState(() => device = value);
                        },
                  child: Text(device == null
                      ? 'Associate GPS device (optional)'
                      : 'GPS device #$device')),
            if (widget.kind == 'devices')
              const Text(
                  'Register a real device identifier only. This prepares mapping; no live GPS feed is implemented.'),
            if (error != null) Text(error!),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Saving…' : 'Save')),
            if (widget.kind == 'exceptions' && widget.resource != null)
              OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await widget.api.removeException(
                                fields['travel_date']!.text.split('T').first);
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            if (mounted)
                              setState(() {
                                error = '$e';
                                busy = false;
                              });
                          }
                        },
                  child: const Text('Remove closure')),
          ])));
}

class AdminStopsScreen extends StatefulWidget {
  const AdminStopsScreen({super.key, required this.api, required this.route});
  final TransportApi api;
  final Json route;
  @override
  State<AdminStopsScreen> createState() => _AdminStopsScreenState();
}

class _AdminStopsScreenState extends State<AdminStopsScreen> {
  List<Json>? stops;
  String? error;
  bool busy = false;
  bool verified = false;
  String get id => widget.route['pattern_id'].toString();
  @override
  void initState() {
    super.initState();
    verified = widget.route['verified'] == true;
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.api.pattern(id);
      if (mounted)
        setState(() => stops = (value['stops'] as List).cast<Json>());
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> updateStop(Json stop) async {
    final label = TextEditingController(text: stop['label'] as String);
    final lat = TextEditingController(text: stop['latitude']?.toString() ?? '');
    final lng =
        TextEditingController(text: stop['longitude']?.toString() ?? '');
    final reference = TextEditingController(
        text: stop['coordinate_reference'] as String? ?? '');
    final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Edit stoppage'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: label,
                      decoration: const InputDecoration(
                          labelText: 'Stop name and landmark')),
                  TextField(
                      controller: lat,
                      decoration: const InputDecoration(
                          labelText: 'Verified latitude (optional)')),
                  TextField(
                      controller: lng,
                      decoration: const InputDecoration(
                          labelText: 'Verified longitude (optional)')),
                  TextField(
                      controller: reference,
                      decoration: const InputDecoration(
                          labelText: 'Coordinate verification reference'))
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'))
                ]));
    if (save == true) {
      setState(() => busy = true);
      try {
        await widget.api.saveStop(stop['id'].toString(), {
          'label': label.text,
          'latitude': lat.text.isEmpty ? null : double.parse(lat.text),
          'longitude': lng.text.isEmpty ? null : double.parse(lng.text),
          'coordinateReference': reference.text
        });
        await load();
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    // The dialog can still be completing its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    label.dispose();
    lat.dispose();
    lng.dispose();
    reference.dispose();
  }

  Future<void> verify() async {
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Verify source entry'),
                content: TextField(
                    controller: ref,
                    decoration: const InputDecoration(
                        labelText: 'Official confirmation reference')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Verify'))
                ]));
    if (ok == true) {
      setState(() => busy = true);
      try {
        await widget.api
            .verifyVariant(widget.route['variant_id'].toString(), ref.text);
        if (mounted) setState(() => verified = true);
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    ref.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('${widget.route['variant_name']} · Stops')),
      body: Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Drag to reorder, then save. Reordering deactivates affected schedules until their pickup/arrival times are reviewed. Future confirmed bookings block changes.')),
        if (error != null) Text(error!),
        if (!verified)
          TextButton(
              onPressed: busy ? null : verify,
              child: const Text('Verify source entry')),
        Expanded(
            child: stops == null
                ? Center(
                    child: error == null
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: load, child: const Text('Retry')))
                : ReorderableListView(
                    onReorderItem: busy
                        ? (_, __) {}
                        : (oldIndex, newIndex) {
                            setState(() {
                              final stop = stops!.removeAt(oldIndex);
                              stops!.insert(newIndex, stop);
                            });
                          },
                    children: [
                        for (final stop in stops!)
                          ListTile(
                              key: ValueKey(stop['id']),
                              title: Text(stop['label'] as String),
                              trailing: IconButton(
                                  onPressed:
                                      busy ? null : () => updateStop(stop),
                                  icon: const Icon(Icons.edit)))
                      ])),
        FilledButton(
            onPressed: busy || stops == null
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await widget.api.reorder(
                          id, stops!.map((s) => s['id'].toString()).toList());
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Order saved. Review and reactivate affected schedules.')));
                    } catch (e) {
                      if (mounted) setState(() => error = '$e');
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Save stop order')),
      ]));
}

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key, required this.api, this.schedule});
  final TransportApi api;
  final Json? schedule;
  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final fields = <String, TextEditingController>{};
  final pickup = <String, TextEditingController>{};
  final arrival = <String, TextEditingController>{};
  List<Json> patterns = [];
  Json? pattern;
  String? patternId, bus, driver, error;
  String period = 'morning_1';
  bool active = false, verified = false, busy = false, loading = true;
  List<int> days = [0, 1, 2, 3, 4, 6];
  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    for (final key in [
      'label',
      'departure_time',
      'arrival_time',
      'effective_from',
      'effective_to',
      'verification_reference'
    ]) fields[key] = TextEditingController(text: s?[key]?.toString() ?? '');
    if (s != null) {
      patternId = s['pattern_id'].toString();
      bus = s['bus_id']?.toString();
      driver = s['driver_id']?.toString();
      period = s['period'] as String;
      active = s['active'] == true;
      verified = s['verified'] == true;
      days = (s['service_days'] as List).cast<int>();
    }
    load();
  }

  Future<void> load() async {
    try {
      patterns = (await widget.api.routes()).map((r) => r.json).toList();
      if (patternId != null) await loadPattern(patternId!);
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<void> loadPattern(String value) async {
    final p = await widget.api.pattern(value);
    if (!mounted) return;
    for (final controller in [...pickup.values, ...arrival.values])
      controller.dispose();
    pickup.clear();
    arrival.clear();
    for (final stop in (p['stops'] as List).cast<Json>()) {
      final t = (stop['times'] as List)
          .cast<Json>()
          .where((t) =>
              t['schedule_id'].toString() == widget.schedule?['id'].toString())
          .firstOrNull;
      final stopId = stop['id'].toString();
      if (stop['pickup_allowed'] == true)
        pickup[stopId] =
            TextEditingController(text: t?['pickup_time'] as String? ?? '');
      if (stop['dropoff_allowed'] == true)
        arrival[stopId] =
            TextEditingController(text: t?['arrival_time'] as String? ?? '');
    }
    if (mounted)
      setState(() {
        patternId = value;
        pattern = p;
      });
  }

  @override
  void dispose() {
    for (final c in [...fields.values, ...pickup.values, ...arrival.values])
      c.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || pattern == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.saveSchedule({
        'patternId': patternId,
        'label': fields['label']!.text,
        'period': period,
        'departureTime': fields['departure_time']!.text,
        'arrivalTime': fields['arrival_time']!.text.isEmpty
            ? null
            : fields['arrival_time']!.text,
        'effectiveFrom': fields['effective_from']!.text,
        'effectiveTo': fields['effective_to']!.text.isEmpty
            ? null
            : fields['effective_to']!.text,
        'serviceDays': days,
        'busId': bus,
        'driverId': driver,
        'active': active,
        'verified': verified,
        'verificationReference': fields['verification_reference']!.text,
        'stopTimes': [
          for (final stop in (pattern!['stops'] as List).cast<Json>())
            {
              'patternStopId': stop['id'].toString(),
              'pickupTime': pickup[stop['id'].toString()]?.text,
              'arrivalTime': arrival[stop['id'].toString()]?.text
            }
        ]
      }, id: widget.schedule?['id'].toString());
      if (mounted) Navigator.pop(context);
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
          appBar: AppBar(title: const Text('Manage trip schedule')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(24), children: [
                  if (error != null) Text(error!),
                  DropdownButton<String>(
                      isExpanded: true,
                      value: patterns.any(
                              (r) => r['pattern_id'].toString() == patternId)
                          ? patternId
                          : null,
                      hint: const Text('Route and direction'),
                      items: [
                        for (final r in patterns)
                          DropdownMenuItem(
                              value: r['pattern_id'].toString(),
                              child: Text(
                                  '${r['variant_name']} · ${r['direction']}'))
                      ],
                      onChanged: busy || widget.schedule != null
                          ? null
                          : (value) async {
                              if (value != null) {
                                setState(() => busy = true);
                                try {
                                  await loadPattern(value);
                                } catch (e) {
                                  if (mounted) setState(() => error = '$e');
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              }
                            }),
                  for (final field in fields.entries)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextField(
                            controller: field.value,
                            enabled: !busy,
                            decoration: InputDecoration(
                                labelText: switch (field.key) {
                              'departure_time' =>
                                'First pickup/departure (HH:mm)',
                              'arrival_time' =>
                                'Scheduled arrival (HH:mm, leave unknown blank)',
                              'effective_from' => 'Effective from (YYYY-MM-DD)',
                              'effective_to' =>
                                'Effective to (optional YYYY-MM-DD)',
                              'verification_reference' =>
                                'Official verification reference',
                              _ => field.key
                            }))),
                  DropdownButton<String>(
                      isExpanded: true,
                      value: period,
                      items: [
                        for (final value in [
                          'morning_1',
                          'morning_2',
                          'afternoon',
                          'evening'
                        ])
                          DropdownMenuItem(value: value, child: Text(value))
                      ],
                      onChanged: busy
                          ? null
                          : (v) {
                              if (v != null) setState(() => period = v);
                            }),
                  const Text('Service days'),
                  Wrap(children: [
                    for (var day = 0; day < 7; day++)
                      FilterChip(
                          label: Text([
                            'Sun',
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat'
                          ][day]),
                          selected: days.contains(day),
                          onSelected: busy
                              ? null
                              : (selected) => setState(() {
                                    if (selected)
                                      days.add(day);
                                    else
                                      days.remove(day);
                                  }))
                  ]),
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final value = await chooseResource(
                                  context, widget.api, 'buses');
                              if (value != null && mounted)
                                setState(() => bus = value);
                            },
                      child: Text(bus == null ? 'Assign bus' : 'Bus #$bus')),
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final value = await chooseResource(
                                  context, widget.api, 'drivers');
                              if (value != null && mounted)
                                setState(() => driver = value);
                            },
                      child: Text(driver == null
                          ? 'Assign driver'
                          : 'Driver #$driver')),
                  SwitchListTile(
                      title: const Text('Source verified'),
                      value: verified,
                      onChanged:
                          busy ? null : (v) => setState(() => verified = v)),
                  SwitchListTile(
                      title: const Text('Active for booking'),
                      value: active,
                      onChanged:
                          busy ? null : (v) => setState(() => active = v)),
                  if (pattern != null) ...[
                    const Text('Stop times (HH:mm, Asia/Dhaka)'),
                    for (final stop in (pattern!['stops'] as List).cast<Json>())
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: TextField(
                              controller: pickup[stop['id'].toString()] ??
                                  arrival[stop['id'].toString()],
                              enabled: !busy,
                              decoration: InputDecoration(
                                  labelText:
                                      '${stop['label']} · ${pickup.containsKey(stop['id'].toString()) ? 'Pickup' : 'Arrival'}')))
                  ],
                  FilledButton(
                      onPressed: busy || pattern == null ? null : save,
                      child: Text(busy ? 'Saving…' : 'Save schedule')),
                ])));
}
