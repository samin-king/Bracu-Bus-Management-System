import 'dart:async';
import 'dart:convert';

import 'package:bracu_transport/main.dart';
import 'package:bracu_transport/models/bus.dart';
import 'package:bracu_transport/services/api_client.dart';
import 'package:bracu_transport/services/bus_service.dart';
import 'package:bracu_transport/services/driver_service.dart';
import 'package:bracu_transport/services/route_service.dart';
import 'package:bracu_transport/services/trip_service.dart';
import 'package:bracu_transport/screens/bus/bus_screen.dart';
import 'package:bracu_transport/screens/routes/route_screen.dart';
import 'package:bracu_transport/screens/trips/trip_screen.dart';
import 'package:bracu_transport/screens/driver/driver_screen.dart';
import 'package:bracu_transport/screens/driver/driver_assignment_screen.dart';
import 'package:bracu_transport/screens/driver/driver_dashboard.dart';
import 'package:bracu_transport/screens/driver/passenger_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const bus = {
  'id': 1,
  'bus_number': 'BRACU-01',
  'registration_number': 'DEV-001',
  'capacity': 37,
  'status': 'ACTIVE',
};
const route = {
  'id': 1,
  'route_name': 'Mirpur to BRACU',
  'origin': 'Mirpur',
  'destination': 'BRACU',
  'stops': ['Mirpur', 'Farmgate', 'BRACU'],
};
const driver = {
  'id': 1,
  'name': 'Driver One',
  'license_number': 'DEV-DL-001',
  'status': 'ACTIVE',
};
Map<String, dynamic> trip([String status = 'SCHEDULED']) => {
      'id': 1,
      'bus_id': 1,
      'route_id': 1,
      'driver_id': 1,
      'driver': driver,
      'travel_date': '2026-11-05',
      'departure_time': '06:30:00',
      'status': status,
      'bus': bus,
      'route': route,
    };

class Fixture {
  bool empty = false, fail = false, inactive = false;
  String status = 'SCHEDULED';
  final requests = <http.Request>[];
  Completer<void>? gate;
  late final client = MockClient((request) async {
    requests.add(request);
    if (gate != null) await gate!.future;
    if (fail) {
      return http.Response(jsonEncode({'error': 'Server unavailable'}), 503);
    }
    final path = request.url.path.replaceFirst('/api/', '');
    dynamic data;
    if (path.endsWith('/start') || path.endsWith('/stop')) {
      status = path.endsWith('/start') ? 'ACTIVE' : 'COMPLETED';
      data = {
        ...trip(status),
        'started_at': '2026-11-05T00:30:00Z',
        if (status == 'COMPLETED') 'completed_at': '2026-11-05T01:30:00Z',
      };
    } else if (path.endsWith('/driver')) {
      final id = (jsonDecode(request.body) as Map)['driver_id'];
      data = {...trip(), 'driver_id': id, 'driver': id == null ? null : driver};
    } else if (path == 'drivers/me') {
      data = {...driver, if (inactive) 'status': 'INACTIVE'};
    } else if (path == 'drivers/me/trips') {
      data = empty ? [] : [trip(status)];
    } else {
      final resource = path.split('/').first;
      final record = switch (resource) {
        'buses' => bus,
        'routes' => route,
        'drivers' => driver,
        _ => trip(status),
      };
      if (request.method != 'GET') {
        data = {...record, ...jsonDecode(request.body) as Map};
      } else {
        data = path.contains('/')
            ? record
            : empty
                ? []
                : [record];
      }
    }
    return http.Response(
      jsonEncode(data),
      request.method == 'POST' &&
              !path.endsWith('/start') &&
              !path.endsWith('/stop')
          ? 201
          : 200,
    );
  });
  ApiClient api([TransportRole role = TransportRole.authority]) => ApiClient(
        baseUrl: 'https://example.test/api',
        session: TransportSession(
          role: role,
          headers: () async => {'Authorization': 'Bearer verified'},
        ),
        client: client,
      );
}

Future<void> show(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(MaterialApp(home: widget));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  test('malformed records become API errors before rendering', () async {
    final f = Fixture();
    final api = ApiClient(
        baseUrl: 'https://example.test/api',
        session: f.api().session,
        client: MockClient((_) async => http.Response('[{"id":1}]', 200)));
    await expectLater(BusService(api).list(), throwsA(isA<ApiException>()));
  });
  test('backend authorization and conflict errors remain authoritative',
      () async {
    final f = Fixture();
    for (final status in [401, 403, 409]) {
      final api = ApiClient(
          baseUrl: 'https://example.test/api',
          session: f.api(TransportRole.driver).session,
          client: MockClient((_) async => http.Response(
              jsonEncode({'error': 'Rejected by backend'}), status)));
      await expectLater(
          DriverService(api).transition(1, 'start'),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'status', status)));
    }
  });
  test('models preserve writable contracts and ordered stops', () {
    expect(Bus(bus).writable, {
      'bus_number': 'BRACU-01',
      'registration_number': 'DEV-001',
      'capacity': 37,
      'status': 'ACTIVE',
    });
    expect(Bus(bus).details['Capacity'], '37');
  });
  test(
    'services reuse list/detail/create/update and attach current credentials',
    () async {
      final f = Fixture(), api = Fixture();
      final buses = BusService(f.api());
      expect((await buses.list()).single.title, 'BRACU-01');
      expect((await buses.get(1)).capacity, 37);
      await buses.save(Bus(bus).writable);
      await buses.save({...Bus(bus).writable, 'capacity': 28}, id: 1);
      expect(f.requests.map((r) => r.method), ['GET', 'GET', 'POST', 'PUT']);
      expect(
        f.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer verified',
        ),
        isTrue,
      );
      expect((await RouteService(api.api()).get(1)).stops, [
        'Mirpur',
        'Farmgate',
        'BRACU',
      ]);
      final trips = TripService(api.api());
      expect((await trips.get(1)).driverName, 'Driver One');
      expect((await trips.get(1)).writable.containsKey('driver_id'), isFalse);
    },
  );
  test(
      'assignment supports unassign; transitions use POST without identity in body',
      () async {
    final f = Fixture();
    expect((await DriverService(f.api()).assign(1, null)).driverId, isNull);
    final service = DriverService(f.api(TransportRole.driver));
    expect((await service.transition(1, 'start')).status, 'ACTIVE');
    expect((await service.transition(1, 'stop')).status, 'COMPLETED');
    expect(f.requests.last.method, 'POST');
    expect(f.requests.last.body, isEmpty);
  });
  test('errors preserve backend status and message', () async {
    final f = Fixture()..fail = true;
    await expectLater(
      BusService(f.api()).list(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 503)
            .having((e) => e.message, 'message', 'Server unavailable'),
      ),
    );
  });
  test('invalid JSON and network errors produce clear errors', () async {
    final f = Fixture();
    for (final client in [
      MockClient((_) async => http.Response('<html>', 502)),
      MockClient((_) async => throw http.ClientException('offline')),
    ]) {
      final api = ApiClient(
        baseUrl: 'https://example.test/api',
        session: f.api().session,
        client: client,
      );
      await expectLater(BusService(api).list(), throwsA(isA<ApiException>()));
    }
  });
  for (final role in [TransportRole.student, TransportRole.driver]) {
    test('$role cannot call authority services', () async {
      final f = Fixture(), api = Fixture();
      await expectLater(
        BusService(f.api(role)).list(),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        RouteService(f.api(role)).get(1),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        TripService(f.api(role)).save({}),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        DriverService(api.api(role)).assign(1, 1),
        throwsA(isA<ApiException>()),
      );
      expect(f.requests, isEmpty);
      expect(api.requests, isEmpty);
    });
    testWidgets('$role cannot open any authority management screen directly', (
      tester,
    ) async {
      final f = Fixture();
      final api = f.api(role);
      for (final screen in [
        BusScreen(api: api),
        RouteScreen(api: api),
        TripScreen(api: api),
        DriverScreen(api: api),
        DriverAssignmentScreen(api: api),
      ]) {
        await show(tester, screen);
        expect(find.textContaining('Access denied'), findsOneWidget);
      }
      expect(f.requests, isEmpty);
    });
  }
  testWidgets('student cannot open driver dashboard or passenger screen', (
    tester,
  ) async {
    final f = Fixture();
    for (final screen in [
      DriverDashboard(api: f.api(TransportRole.student)),
      PassengerListScreen(api: f.api(TransportRole.student)),
    ]) {
      await show(tester, screen);
      expect(find.textContaining('Access denied'), findsOneWidget);
    }
    expect(f.requests, isEmpty);
  });
  testWidgets(
    'signed out app and student app expose no management navigation',
    (tester) async {
      await tester.pumpWidget(const TransportApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('Sign in through'), findsOneWidget);
      await tester.pumpWidget(
        TransportApp(session: Fixture().api(TransportRole.student).session),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buses'), findsNothing);
      expect(find.text('Driver Dashboard'), findsNothing);
    },
  );
  testWidgets('bus list and detail use their API endpoints', (tester) async {
    final f = Fixture();
    await show(tester, BusScreen(api: f.api()));
    expect(find.text('BRACU-01'), findsOneWidget);
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('bus details'), findsOneWidget);
    expect(find.text('Capacity: 37'), findsOneWidget);
    expect(f.requests.last.url.path, '/api/buses/1');
  });
  testWidgets('bus loading, API error, retry and empty state', (tester) async {
    final f = Fixture()..gate = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: BusScreen(api: f.api())));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    f.fail = true;
    f.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Server unavailable'), findsOneWidget);
    f.fail = false;
    f.empty = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No buses found.'), findsOneWidget);
  });
  for (final kind in ['route', 'trip', 'driver']) {
    testWidgets('$kind list and details', (tester) async {
      final f = Fixture();
      await show(
          tester,
          switch (kind) {
            'route' => RouteScreen(api: f.api()),
            'trip' => TripScreen(api: f.api()),
            _ => DriverScreen(api: f.api()),
          });
      expect(
        find.text(kind == 'driver' ? 'Driver One' : 'Mirpur to BRACU'),
        findsOneWidget,
      );
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('$kind details'), findsOneWidget);
      expect(
        f.requests.last.url.path,
        '/api/${kind == 'driver' ? 'drivers' : kind == 'route' ? 'routes' : 'trips'}/1',
      );
    });
  }
  testWidgets('bus create validates capacity and submits typed data', (
    tester,
  ) async {
    final f = Fixture();
    await show(tester, BusScreen(api: f.api()));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'BRACU-02');
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a positive integer'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '28');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final request = f.requests.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(request.body)['capacity'], 28);
    expect(jsonDecode(request.body)['registration_number'], isNull);
  });
  testWidgets('bus edit retains API errors and form values', (tester) async {
    final f = Fixture();
    await show(tester, BusScreen(api: f.api()));
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit bus'));
    await tester.pumpAndSettle();
    f.fail = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Server unavailable'), findsOneWidget);
    expect(find.text('BRACU-01'), findsOneWidget);
    expect(f.requests.last.method, 'PUT');
  });
  testWidgets(
    'driver dashboard and assigned trip start and stop from server results',
    (tester) async {
      final f = Fixture();
      await show(tester, DriverDashboard(api: f.api(TransportRole.driver)));
      expect(find.text('Driver One'), findsOneWidget);
      expect(find.text('Assigned Trips'), findsOneWidget);
      expect(find.textContaining('Departure: 2026-11-05'), findsOneWidget);
      await reveal(tester, 'Start Trip');
      await tester.tap(find.text('Start Trip'));
      await tester.pumpAndSettle();
      expect(find.text('Trip started'), findsOneWidget);
      expect(find.text('Status: ACTIVE'), findsNWidgets(2));
      await reveal(tester, 'Stop Trip');
      await tester.tap(find.text('Stop Trip'));
      await tester.pumpAndSettle();
      expect(find.text('Trip completed'), findsOneWidget);
      expect(find.text('Status: COMPLETED'), findsOneWidget);
      expect(find.text('Stop Trip'), findsNothing);
    },
  );
  testWidgets(
    'driver action disables controls while pending and retains status on failure',
    (tester) async {
      final f = Fixture();
      await show(tester, DriverDashboard(api: f.api(TransportRole.driver)));
      f.gate = Completer<void>();
      await reveal(tester, 'Start Trip');
      await tester.tap(find.text('Start Trip'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Updating...'),
            )
            .onPressed,
        isNull,
      );
      f.fail = true;
      f.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Server unavailable'), findsOneWidget);
      expect(find.text('Status: SCHEDULED'), findsOneWidget);
      expect(find.text('Start Trip'), findsOneWidget);
    },
  );
  testWidgets('inactive driver cannot operate trips', (tester) async {
    final f = Fixture()..inactive = true;
    await show(tester, DriverDashboard(api: f.api(TransportRole.driver)));
    await reveal(tester, 'Start Trip');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start Trip'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('empty driver assignments and load failure retry', (
    tester,
  ) async {
    final f = Fixture()..fail = true;
    await show(tester, DriverDashboard(api: f.api(TransportRole.driver)));
    expect(find.text('Server unavailable'), findsOneWidget);
    f.fail = false;
    f.empty = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No assigned trips.'), findsOneWidget);
  });
  testWidgets('passenger screen is honest and makes no unsupported API call', (
    tester,
  ) async {
    final f = Fixture();
    await show(tester, DriverDashboard(api: f.api(TransportRole.driver)));
    final count = f.requests.length;
    await reveal(tester, 'View passengers');
    await tester.tap(find.text('View passengers'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not expose a passenger'), findsOneWidget);
    expect(f.requests.length, count);
  });
  testWidgets('assignment saves scheduled trip with selected active driver', (
    tester,
  ) async {
    final f = Fixture();
    await show(tester, DriverAssignmentScreen(api: f.api()));
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('BRACU-01 /').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect(find.text('Driver assignment saved'), findsOneWidget);
    final request = f.requests.firstWhere(
      (r) => r.url.path.endsWith('/driver'),
    );
    expect(request.method, 'PUT');
    expect(jsonDecode(request.body), {'driver_id': 1});
  });
  testWidgets('assignment errors remain visible and no result is invented', (
    tester,
  ) async {
    final f = Fixture();
    await show(tester, DriverAssignmentScreen(api: f.api()));
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('BRACU-01 /').last);
    await tester.pumpAndSettle();
    f.fail = true;
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect(find.text('Server unavailable'), findsOneWidget);
    expect(find.text('Driver assignment saved'), findsNothing);
  });
  testWidgets('phone portrait layout fits a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(
      tester,
      DriverDashboard(api: Fixture().api(TransportRole.driver)),
    );
    await reveal(tester, 'Start Trip');
    expect(tester.takeException(), isNull);
  });
}
