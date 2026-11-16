import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bracu_student_booking/student_booking.dart';
import 'package:bracu_student_booking/widgets/trip_stops.dart';

final inbound = RoutePattern({
  'pattern_id': '10',
  'variant_id': '1',
  'variant_code': '01-A',
  'variant_name': 'Abdullahpur-A',
  'direction': 'inbound',
  'verified': true
});
final outbound = RoutePattern(
    {...inbound.json, 'pattern_id': '11', 'direction': 'outbound'});
final sourceStops = <Json>[
  {
    'id': '101',
    'stopId': '1',
    'name': 'Origin landmark',
    'sequence': 1,
    'pickupAllowed': true,
    'dropoffAllowed': false,
    'pickupTime': '06:40',
    'arrivalTime': null
  },
  {
    'id': '102',
    'stopId': '2',
    'name': 'BRAC University',
    'sequence': 2,
    'pickupAllowed': false,
    'dropoffAllowed': true,
    'pickupTime': null,
    'arrivalTime': '07:30'
  },
];
final officialTrip = Trip({
  'id': 'schedule:1',
  'variantId': '1',
  'variantCode': '01-A',
  'patternId': '10',
  'route': 'Abdullahpur-A',
  'bus': 'Assigned Bus',
  'direction': 'inbound',
  'departureTime': '06:40',
  'arrivalTime': '07:30',
  'requiresStops': true,
  'dropoffSupported': true,
  'stops': sourceStops
});

class ScheduleFixtureApi implements StudentApi {
  Json? submitted;
  @override
  Future<List<Trip>> trips(String date) async => [officialTrip];
  @override
  Future<Availability> seats(String trip, String date) async => Availability({
        'trip': officialTrip.json,
        'bookingOpen': true,
        'genderKnown': true,
        'standingAvailable': 0,
        'seats': [
          {'number': 19, 'state': 'Available', 'selectable': true}
        ]
      });
  Booking get receipt => Booking({
        'id': '42',
        'trip_id': officialTrip.id,
        'travel_date': '2030-01-02',
        'standing': false,
        'seat_number': 19,
        'status': 'confirmed',
        'section': 'Upcoming',
        'trip_snapshot': {
          ...officialTrip.json,
          'pickup': sourceStops.first,
          'dropoff': sourceStops.last
        }
      });
  @override
  Future<Booking> book(Json input) async {
    submitted = input;
    return receipt;
  }

  @override
  Future<List<Booking>> bookings() async => submitted == null ? [] : [receipt];
  @override
  Future<Booking> booking(String id) async => receipt;
  @override
  Future<Booking> cancel(String id) async =>
      Booking({...receipt.json, 'status': 'cancelled', 'section': 'Cancelled'});
}

class TransportFixtureApi implements TransportApi {
  bool failed = false, admin = false;
  Completer<List<RoutePattern>>? pending;
  @override
  Future<List<RoutePattern>> routes() async {
    if (failed) throw ApiFailure('network');
    return pending == null ? [inbound, outbound] : pending!.future;
  }

  @override
  Future<Json> pattern(String id) async {
    if (failed) throw ApiFailure('network');
    return {
      'id': id,
      'sequence_verified': id == '10',
      'stops': [
        {
          'id': '101',
          'label': 'Origin landmark',
          'sequence': 1,
          'pickup_allowed': true,
          'dropoff_allowed': false,
          'times': [
            {
              'schedule_id': '1',
              'label': '1st Trip',
              'pickup_time': '06:40',
              'arrival_time': null
            },
            {
              'schedule_id': '2',
              'label': '2nd Trip',
              'pickup_time': '08:30',
              'arrival_time': null
            }
          ]
        },
        if (id == '10')
          {
            'id': '102',
            'label': 'BRAC University',
            'sequence': 2,
            'pickup_allowed': false,
            'dropoff_allowed': true,
            'times': [
              {
                'schedule_id': '1',
                'label': '1st Trip',
                'pickup_time': null,
                'arrival_time': '07:30'
              },
              {
                'schedule_id': '2',
                'label': '2nd Trip',
                'pickup_time': null,
                'arrival_time': '10:40'
              }
            ]
          },
      ]
    };
  }

  @override
  Future<Json> schedules(
      {String? variantId,
      String? date,
      String? direction,
      int page = 1,
      bool admin = false}) async {
    if (failed) throw ApiFailure('network');
    return {'items': [], 'hasMore': false};
  }

  @override
  Future<bool> adminAccess() async => admin;
  @override
  Future<Json> resources(String kind, {int page = 1}) async =>
      {'items': [], 'hasMore': false};
  @override
  Future<Json> saveResource(String kind, Json input, {String? id}) async =>
      input;
  @override
  Future<Json> saveSchedule(Json input, {String? id}) async => input;
  @override
  Future<Json> saveStop(String id, Json input) async => input;
  @override
  Future<Json> reorder(String id, List<String> ids) async => {};
  @override
  Future<Json> verifyVariant(String id, String reference) async => {};
  @override
  Future<Json> removeException(String date) async => {};
}

void main() {
  test(
      'booking validates ordered pickup/drop-off and submits existing booking API contract',
      () async {
    final api = ScheduleFixtureApi();
    final state = BookingState(api, transportApi: TransportFixtureApi());
    await state.selectRoute(inbound);
    expect(state.visibleTrips.length, 1);
    await state.selectTrip(officialTrip);
    state.selectSeat(19);
    expect(state.canSubmit, false);
    state.choosePickup('102');
    expect(state.pickupStopId, null);
    state.choosePickup('101');
    state.chooseDropoff('101');
    expect(state.dropoffStopId, null);
    state.chooseDropoff('102');
    expect(state.canSubmit, true);
    await state.submit();
    expect(api.submitted!['pickupStopId'], '101');
    expect(api.submitted!['dropoffStopId'], '102');
    await state.selectRoute(outbound);
    expect(state.visibleTrips, isEmpty);
    expect(state.pickupStopId, null);
  });
  testWidgets('routes show loading, variants and both directions',
      (tester) async {
    final api = TransportFixtureApi()
      ..pending = Completer<List<RoutePattern>>();
    await tester.pumpWidget(MaterialApp(home: BusRoutesScreen(api: api)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.pending!.complete([inbound, outbound]);
    await tester.pumpAndSettle();
    expect(find.text('Route 01-A · Abdullahpur-A'), findsNWidgets(2));
    expect(find.text('inbound'), findsOneWidget);
    expect(find.text('outbound'), findsOneWidget);
  });
  testWidgets('route load failure offers retry and recovers', (tester) async {
    final api = TransportFixtureApi()..failed = true;
    await tester.pumpWidget(MaterialApp(home: BusRoutesScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    api.failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Route 01-A · Abdullahpur-A'), findsNWidgets(2));
  });
  testWidgets('stoppage search preserves first/second pickup versus arrival',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: BusStoppagesScreen(api: TransportFixtureApi(), route: inbound)));
    await tester.pumpAndSettle();
    expect(find.text('1st Trip: 06:40 · Pickup'), findsOneWidget);
    expect(find.text('2nd Trip: 08:30 · Pickup'), findsOneWidget);
    expect(find.text('1st Trip: 07:30 · Arrival'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'university');
    await tester.pump();
    expect(find.text('Origin landmark'), findsNothing);
    expect(find.text('BRAC University'), findsOneWidget);
  });
  testWidgets('outbound explains unspecified drop-offs', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: BusStoppagesScreen(api: TransportFixtureApi(), route: outbound)));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Outbound drop-off stops/order are not supplied'),
        findsOneWidget);
    expect(find.text('BRAC University'), findsNothing);
  });
  testWidgets('pickup/drop-off controls choose trip associations',
      (tester) async {
    final state = BookingState(ScheduleFixtureApi());
    await state.selectTrip(officialTrip);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListenableBuilder(
                listenable: state,
                builder: (_, __) => TripStopsSelection(state: state)))));
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Origin landmark · 06:40').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BRAC University').last);
    await tester.pumpAndSettle();
    expect(state.pickupStopId, '101');
    expect(state.dropoffStopId, '102');
    expect(state.validStops, true);
  });
  testWidgets(
      'ticket receipt preserves confirmed pickup/drop-off and pickup time',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child:
                    BookingSummary(booking: ScheduleFixtureApi().receipt)))));
    expect(find.text('Pickup: Origin landmark'), findsOneWidget);
    expect(find.text('Drop-off: BRAC University'), findsOneWidget);
    expect(find.text('Scheduled pickup: 06:40 (Asia/Dhaka)'), findsOneWidget);
  });
  testWidgets('admin entry respects backend access result', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TransportAdminEntry(api: TransportFixtureApi()))));
    await tester.pumpAndSettle();
    expect(find.text('Transport administration'), findsNothing);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TransportAdminEntry(
                key: UniqueKey(), api: TransportFixtureApi()..admin = true))));
    await tester.pumpAndSettle();
    expect(find.text('Transport administration'), findsOneWidget);
  });

  testWidgets('stoppage loading failure recovers through retry',
      (tester) async {
    final api = TransportFixtureApi()..failed = true;
    await tester.pumpWidget(
        MaterialApp(home: BusStoppagesScreen(api: api, route: inbound)));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    api.failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Origin landmark'), findsOneWidget);
  });
  testWidgets(
      'admin refresh and retry recover without asynchronous setState callbacks',
      (tester) async {
    final api = TransportFixtureApi()..failed = true;
    await tester.pumpWidget(MaterialApp(home: TransportAdminScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    api.failed = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No entries.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
