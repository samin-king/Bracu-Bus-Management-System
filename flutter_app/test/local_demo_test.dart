import 'package:bracu_transport/demo/demo_store.dart';
import 'package:bracu_transport/demo/local_demo_app.dart';
import 'package:bracu_transport/services/api_client.dart';
import 'package:bracu_transport/services/bus_service.dart';
import 'package:bracu_transport/services/driver_service.dart';
import 'package:bracu_transport/services/route_service.dart';
import 'package:bracu_transport/services/trip_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selecting the same Authority module leaves its detail route', (
    tester,
  ) async {
    await tester.pumpWidget(const LocalDemoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Authority'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bus Management'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details').first);
    await tester.pumpAndSettle();
    expect(find.text('bus details'), findsOneWidget);
    await tester.tap(find.text('Bus Management'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Search buses'), findsOneWidget);
    expect(find.text('bus details'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'isolated CRUD, cross-role assignments, bookings and timestamped driver workflow',
    () async {
      final store = DemoStore();
      final authority = store.api(TransportRole.authority),
          driver = store.api(TransportRole.driver);
      addTearDown(() {
        authority.client.close();
        driver.client.close();
        store.dispose();
      });
      final buses = BusService(authority);
      final created = await buses.save({
        'bus_number': 'DEMO-NEW',
        'registration_number': 'DEMO-NEW-REG',
        'capacity': 20,
        'status': 'ACTIVE',
      });
      await buses.save({...created.writable, 'capacity': 24}, id: created.id);
      expect((await buses.get(created.id)).capacity, 24);
      expect((await RouteService(authority).list()).length, 2);
      store.book(1, 2);
      expect(store.availableSeats(1), 33);
      expect(() => store.book(1, 1), throwsA(isA<ApiException>()));
      store.cancelBooking(3);
      expect(store.availableSeats(1), 35);
      final assigned = await DriverService(authority).assign(3, 1);
      expect(assigned.driverId, 1);
      expect((await DriverService(driver).assignedTrips()).length, 2);
      final started = await DriverService(driver).transition(1, 'start');
      expect(started.status, 'ACTIVE');
      expect(started.data['started_at'], isNotNull);
      await expectLater(
        DriverService(driver).transition(3, 'start'),
        throwsA(isA<ApiException>()),
      );
      final finished = await DriverService(driver).transition(1, 'stop');
      expect(finished.status, 'COMPLETED');
      expect(finished.data['completed_at'], isNotNull);
      expect((await TripService(authority).get(1)).status, 'COMPLETED');
      await expectLater(
        DriverService(authority).assign(1, 2),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'demo HTTP adapter handles error/empty states and never targets a real host',
    () async {
      final store = DemoStore();
      final demoApi = store.api(TransportRole.authority);
      addTearDown(() {
        demoApi.client.close();
        store.dispose();
      });
      final external = await demoApi.client.get(
        Uri.parse('https://production.invalid/api/buses'),
      );
      expect(external.statusCode, 403);
      expect(demoApi.baseUrl, 'https://local-demo.invalid/api');
      store.setViewState('Empty');
      expect(await BusService(demoApi).list(), isEmpty);
      store.setViewState('Error');
      await expectLater(
        BusService(demoApi).list(),
        throwsA(isA<ApiException>()),
      );
      store.setViewState('Normal');
      expect((await BusService(demoApi).list()).length, 3);
    },
  );
  testWidgets('demo role login, student booking, shared history and logout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LocalDemoApp());
    await tester.pumpAndSettle();
    expect(find.text('Local Demo Login'), findsOneWidget);
    await tester.tap(find.text('Demo Student'));
    await tester.pumpAndSettle();
    expect(find.textContaining('DEMO MODE'), findsOneWidget);
    await tester.tap(find.text('Student Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'DEMO-01777777777');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(find.textContaining('DEMO-01777777777'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Bus Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book trip #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Booking History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Booking DEMO-3'), findsOneWidget);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Local Demo Login'), findsOneWidget);
    await tester.tap(find.text('Demo Driver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passenger List'));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Rahman'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
