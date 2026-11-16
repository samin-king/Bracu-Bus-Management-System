import 'package:flutter/material.dart';
import '../models/transport_record.dart';
import '../services/api_client.dart';
import 'demo_store.dart';
import '../design/transport_theme.dart';
import '../design/premium_dashboard.dart';

void demoNotice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
void demoAction(BuildContext context, VoidCallback action, String message) {
  try {
    action();
    demoNotice(context, message);
  } on ApiException catch (e) {
    demoNotice(context, e.message);
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({
    super.key,
    required this.store,
    required this.title,
    required this.builder,
    this.floatingActionButton,
  });
  final DemoStore store;
  final String title;
  final Widget Function(BuildContext) builder;
  final Widget? floatingActionButton;
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late Future<void> future;
  @override
  void initState() {
    super.initState();
    future = widget.store.waitForView();
  }

  void reload() => setState(() => future = widget.store.waitForView());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: reload,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: widget.floatingActionButton,
    body: SafeArea(
      child: FutureBuilder<void>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}'),
                  FilledButton(onPressed: reload, child: const Text('Retry')),
                ],
              ),
            );
          }
          if (widget.store.viewState == 'Empty') {
            return const Center(
              child: Text(
                'No demo records found. Choose Normal to restore the demonstration.',
              ),
            );
          }
          return AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) => widget.builder(context),
          );
        },
      ),
    ),
  );
}

class DemoDashboard extends StatelessWidget {
  const DemoDashboard({super.key, required this.store, required this.role, required this.open});
  final DemoStore store;
  final TransportRole role;
  final ValueChanged<String> open;
  @override
  Widget build(BuildContext context) => DemoPage(store: store,
    title: '${role.name[0].toUpperCase()}${role.name.substring(1)} Dashboard',
    builder: (_) => PremiumDashboardContent(store:store, role:role, open:open));
}

class DemoStudentProfile extends StatelessWidget {
  const DemoStudentProfile({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => DemoPage(
    store: store,
    title: 'Student Profile',
    builder: (context) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _recordCard(store.profile['name'] as String, {
          'Student ID': store.profile['student_id'],
          'Email': store.profile['email'],
          'Phone': store.profile['phone'],
          'Role': 'Demo Student',
        }),
        FilledButton(
          onPressed: () async {
            var name = store.profile['name'] as String;
            var phone = store.profile['phone'] as String;
            final key = GlobalKey<FormState>();
            final saved = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Edit demo profile'),
                content: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: name,
                        onChanged: (value) => name = value,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a name'
                            : null,
                      ),
                      TextFormField(
                        initialValue: phone,
                        onChanged: (value) => phone = value,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (key.currentState!.validate()) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('Save profile'),
                  ),
                ],
              ),
            );
            if (saved == true) {
              store.profile['name'] = name.trim();
              store.profile['phone'] = phone.trim();
              store.changed();
              if (context.mounted) demoNotice(context, 'Demo profile saved');
            }
          },
          child: const Text('Edit profile'),
        ),
      ],
    ),
  );
}

class DemoDriverProfile extends StatelessWidget {
  const DemoDriverProfile({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => DemoPage(
    store: store,
    title: 'Driver Profile',
    builder: (_) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _recordCard('${store.record('drivers', 1)['name']}', {
          'License': store.record('drivers', 1)['license_number'],
          'Status': store.record('drivers', 1)['status'],
          'Driver ID': 'DEMO-1',
          'Email': 'demo.driver@example.invalid',
        }),
        const Text(
          'Assignments and driver status can be changed in Demo Authority → Driver Management / Driver Assignment.',
        ),
      ],
    ),
  );
}

Widget _recordCard(
  String title,
  Map<String, dynamic> details, {
  List<Widget> actions = const [],
}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final entry in details.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text('${entry.key}: ${entry.value}'),
          ),
        ...actions,
      ],
    ),
  ),
);

class DemoBooking extends StatefulWidget {
  const DemoBooking({super.key, required this.store});
  final DemoStore store;
  @override
  State<DemoBooking> createState() => _DemoBookingState();
}

class _DemoBookingState extends State<DemoBooking> {
  String query = '';
  @override
  Widget build(BuildContext context) => DemoPage(
    store: widget.store,
    title: 'Bus Booking',
    builder: (context) {
      final trips = widget.store.tables['trips']!
          .where((t) => t['status'] == 'SCHEDULED')
          .map(widget.store.joinedTrip)
          .where(
            (t) => '${t['route']} ${t['bus']} ${t['travel_date']}'
                .toLowerCase()
                .contains(query.toLowerCase()),
          )
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search available trips',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: trips.isEmpty
                ? const Center(child: Text('No available trips found.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final t in trips)
                        _recordCard(
                          '${(t['route'] as Map)['route_name']}',
                          {
                            'Bus': (t['bus'] as Map)['bus_number'],
                            'Departure':
                                '${t['travel_date']} / ${t['departure_time']} (Dhaka)',
                            'Available seats': widget.store.availableSeats(
                              t['id'] as int,
                            ),
                            'Stops': ((t['route'] as Map)['stops'] as List)
                                .join(' → '),
                          },
                          actions: [
                            FilledButton(
                              onPressed: () => book(context, t),
                              child: Text('Book trip #${t['id']}'),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
  Future<void> book(BuildContext context, Json trip) async {
    int seats = 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book demo seats'),
        content: DropdownButtonFormField<int>(
          initialValue: 1,
          decoration: const InputDecoration(labelText: 'Seats'),
          items: [
            1,
            2,
            3,
            4,
          ].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
          onChanged: (n) => seats = n!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm booking'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      demoAction(
        context,
        () => widget.store.book(trip['id'] as int, seats),
        'Demo booking confirmed. See Booking History.',
      );
    }
  }
}

class DemoBookingHistory extends StatelessWidget {
  const DemoBookingHistory({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => DemoPage(
    store: store,
    title: 'Booking History',
    builder: (context) {
      final bookings = store.tables['bookings']!
          .where((b) => b['student_id'] == 1)
          .toList();
      if (bookings.isEmpty) {
        return const Center(
          child: Text(
            'No bookings yet. Open Bus Booking to reserve demo seats.',
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final b in bookings)
            _recordCard(
              'Booking DEMO-${b['id']}',
              {
                'Route':
                    (store.joinedTrip(
                          store.record('trips', b['trip_id'] as int),
                        )['route']
                        as Map)['route_name'],
                'Seats': b['seats'],
                'Booking status': b['status'],
                'Trip status': store.record(
                  'trips',
                  b['trip_id'] as int,
                )['status'],
              },
              actions: [
                if (b['status'] == 'CONFIRMED')
                  TextButton(
                    onPressed: () => demoAction(
                      context,
                      () => store.cancelBooking(b['id'] as int),
                      'Demo booking cancelled',
                    ),
                    child: const Text('Cancel booking'),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

class DemoSchedule extends StatelessWidget {
  const DemoSchedule({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => DemoPage(
    store: store,
    title: 'Trip Schedule',
    builder: (_) {
      final trips = store.tables['trips']!
          .where((t) => t['driver_id'] == 1)
          .map(store.joinedTrip)
          .toList();
      if (trips.isEmpty) return const Center(child: Text('No assigned trips.'));
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in trips)
            _recordCard(
              'Trip #${t['id']} · ${(t['route'] as Map)['route_name']}',
              {
                'Bus': (t['bus'] as Map)['bus_number'],
                'Departure':
                    '${t['travel_date']} / ${t['departure_time']} (Dhaka)',
                'Stops': ((t['route'] as Map)['stops'] as List).join(' → '),
                'Status': t['status'],
                if (t['started_at'] != null) 'Started (UTC)': t['started_at'],
                if (t['completed_at'] != null)
                  'Completed (UTC)': t['completed_at'],
              },
            ),
        ],
      );
    },
  );
}

class DemoPassengers extends StatelessWidget {
  const DemoPassengers({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => DemoPage(
    store: store,
    title: 'Passenger List',
    builder: (_) {
      final trips = store.tables['trips']!
          .where((t) => t['driver_id'] == 1)
          .toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Synthetic passenger records. Student bookings in this demo appear here.',
          ),
          if (trips.isEmpty) const Text('No assigned trips.'),
          for (final t in trips) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Trip #${t['id']} · ${store.record('routes', t['route_id'] as int)['route_name']}',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            if (!store.tables['bookings']!.any(
              (b) => b['trip_id'] == t['id'] && b['status'] == 'CONFIRMED',
            ))
              const Text('No passengers booked.'),
            for (final b in store.tables['bookings']!.where(
              (b) => b['trip_id'] == t['id'] && b['status'] == 'CONFIRMED',
            ))
              _recordCard('${b['name']}', {
                'Booking': 'DEMO-${b['id']}',
                'Seats': b['seats'],
                'Status': b['status'],
              }),
          ],
        ],
      );
    },
  );
}

class DemoCollection extends StatefulWidget {
  const DemoCollection({
    super.key,
    required this.store,
    required this.resource,
    this.authority = false,
    this.audience = 'STUDENT',
  });
  final DemoStore store;
  final String resource;
  final bool authority;
  final String audience;
  @override
  State<DemoCollection> createState() => _CollectionState();
}

class _CollectionState extends State<DemoCollection> {
  String query = '', filter = 'All';
  String get title => switch (widget.resource) {
    'complaints' => widget.authority ? 'Complaints Management' : 'Complaints',
    'notifications' =>
      widget.authority ? 'Notifications Management' : 'Notifications',
    _ => 'Feedback',
  };
  bool get canWrite => widget.authority || widget.resource != 'notifications';
  List<String> get statuses => switch (widget.resource) {
    'complaints' => ['OPEN', 'IN_REVIEW', 'RESOLVED'],
    'notifications' => ['DRAFT', 'PUBLISHED'],
    _ => ['SUBMITTED'],
  };
  @override
  Widget build(BuildContext context) => DemoPage(
    store: widget.store,
    title: title,
    floatingActionButton: canWrite
        ? FloatingActionButton(
            onPressed: () => form(),
            tooltip: 'Add ${widget.resource}',
            child: const Icon(Icons.add),
          )
        : null,
    builder: (context) {
      final rows = widget.store.tables[widget.resource]!.where((r) {
        if (widget.resource == 'notifications' &&
            !widget.authority &&
            (r['status'] != 'PUBLISHED' ||
                !['ALL', widget.audience].contains(r['audience']))) {
          return false;
        }
        if (widget.resource != 'notifications' &&
            !widget.authority &&
            r['student_id'] != 1) {
          return false;
        }
        return '${r['title']} ${r['message']}'.toLowerCase().contains(
              query.toLowerCase(),
            ) &&
            (filter == 'All' || r['status'] == filter);
      }).toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search ${widget.resource}',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: filter,
                    decoration: const InputDecoration(
                      labelText: 'Filter status',
                    ),
                    items: ['All', ...statuses]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => filter = v!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No matching demo records.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      for (final row in rows)
                        _recordCard(
                          '${row['title']}',
                          {
                            'Message': row['message'],
                            'Status': row['status'],
                            if (row['audience'] != null)
                              'Audience': row['audience'],
                            if (row['rating'] != null)
                              'Rating': '${row['rating']}/5',
                            if (widget.resource == 'notifications' &&
                                !widget.authority)
                              'Read':
                                  (row['read_by'] as List?)?.contains(
                                        widget.audience,
                                      ) ==
                                      true
                                  ? 'Yes'
                                  : 'No',
                          },
                          actions: [
                            TextButton(
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('${row['title']}'),
                                  content: Text(
                                    '${row['message']}\nStatus: ${row['status']}',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              ),
                              child: const Text('View details'),
                            ),
                            if (canWrite)
                              TextButton(
                                onPressed: () => form(row),
                                child: const Text('Edit'),
                              ),
                            if (widget.resource == 'notifications' &&
                                !widget.authority &&
                                ((row['read_by'] as List?)?.contains(
                                      widget.audience,
                                    ) !=
                                    true))
                              TextButton(
                                onPressed: () {
                                  (row['read_by'] ??= <String>[]).add(
                                    widget.audience,
                                  );
                                  widget.store.changed();
                                  demoNotice(
                                    context,
                                    'Notification marked as read',
                                  );
                                },
                                child: const Text('Mark as read'),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
  Future<void> form([Json? row]) async {
    var titleText = row?['title'] as String? ?? '';
    var messageText = row?['message'] as String? ?? '';
    var status = row?['status'] as String? ?? statuses.first;
    var audience = row?['audience'] as String? ?? 'ALL';
    var rating = row?['rating'] as String? ?? '5';
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${row == null ? 'Add' : 'Edit'} ${widget.resource}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: titleText,
                    onChanged: (value) => titleText = value,
                    decoration: const InputDecoration(labelText: 'Title'),
                    maxLength: 120,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  TextFormField(
                    initialValue: messageText,
                    onChanged: (value) => messageText = value,
                    decoration: const InputDecoration(labelText: 'Message'),
                    maxLines: 3,
                    maxLength: 1500,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter a message'
                        : null,
                  ),
                  if (widget.authority)
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: statuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => status = v!,
                    ),
                  if (widget.resource == 'notifications')
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(labelText: 'Audience'),
                      items: ['ALL', 'STUDENT', 'DRIVER', 'AUTHORITY']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => audience = v!,
                    ),
                  if (widget.resource == 'feedback')
                    DropdownButtonFormField<String>(
                      initialValue: rating,
                      decoration: const InputDecoration(labelText: 'Rating'),
                      items: ['1', '2', '3', '4', '5']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => rating = v!,
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final values = <String, dynamic>{
        'title': titleText.trim(),
        'message': messageText.trim(),
        'status': status,
        if (widget.resource == 'notifications') 'audience': audience,
        if (widget.resource == 'feedback') 'rating': rating,
        if (widget.resource != 'notifications')
          'student_id': row?['student_id'] ?? 1,
      };
      widget.store.saveResource(
        widget.resource,
        values,
        id: row?['id'] as int?,
      );
      if (mounted) demoNotice(context, 'Demo ${widget.resource} saved');
    }
  }
}
