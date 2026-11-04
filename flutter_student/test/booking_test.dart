import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bracu_student_booking/student_booking.dart';

final trip = Trip({
  'id': 'trip-a',
  'bus': 'Bus A',
  'route': 'Campus → City',
  'departureTime': '14:00',
});
Booking receipt({String status = 'confirmed'}) => Booking({
      'id': '42',
      'trip_id': trip.id,
      'trip_snapshot': trip.json,
      'travel_date': '2026-11-04',
      'standing': false,
      'seat_number': 19,
      'status': status,
      'section': status == 'cancelled' ? 'Cancelled' : 'Upcoming',
    });

class FakeApi implements StudentApi {
  bool open = true;
  bool cancelled = false;
  int posts = 0, reads = 0;
  Json? input;
  ApiFailure? failure;
  Completer<Booking>? pending;
  @override
  Future<List<Trip>> trips(String date) async => [trip];
  @override
  Future<Availability> seats(String id, String date) async {
    reads++;
    return Availability({
      'trip': trip.json,
      'bookingOpen': open,
      'genderKnown': true,
      'standingAvailable': 2,
      'seats': [
        {'number': 1, 'state': 'Reserved', 'selectable': false},
        {'number': 19, 'state': 'Available', 'selectable': true},
        {'number': 20, 'state': 'Booked', 'selectable': false},
      ],
    });
  }

  @override
  Future<Booking> book(Json input) async {
    posts++;
    this.input = input;
    if (failure != null) throw failure!;
    return pending == null ? receipt() : pending!.future;
  }

  @override
  Future<List<Booking>> bookings() async =>
      posts > 0 ? [receipt(status: cancelled ? 'cancelled' : 'confirmed')] : [];
  @override
  Future<Booking> booking(String id) async =>
      receipt(status: cancelled ? 'cancelled' : 'confirmed');
  @override
  Future<Booking> cancel(String id) async {
    cancelled = true;
    return receipt(status: 'cancelled');
  }
}

Future<BookingState> ready(FakeApi api) async {
  final state = BookingState(api);
  await state.load();
  await state.selectTrip(trip);
  return state;
}

Widget receiptApp(Booking booking, [ConfirmedTicketBuilder? ticket]) =>
    MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: BookingSummary(booking: booking, ticketBuilder: ticket))),
    );
void main() {
  test(
      'seat and standing selections respect server eligibility and replace each other',
      () async {
    final state = await ready(FakeApi());
    state.selectSeat(1);
    expect(state.hasSelection, false);
    state.selectSeat(19);
    expect(state.seat, 19);
    state.selectStanding();
    expect(state.standing, true);
    expect(state.seat, null);
    state.selectSeat(20);
    expect(state.standing, true);
    state.selectSeat(19);
    expect(state.standing, false);
  });
  test(
    'closed window permits selection/review but prevents submission',
    () async {
      final api = FakeApi()..open = false;
      final state = await ready(api);
      state.selectSeat(19);
      expect(state.hasSelection, true);
      expect(state.canSubmit, false);
      expect(await state.submit(), null);
      expect(api.posts, 0);
    },
  );
  test('window closing after review is caught by server recheck', () async {
    final api = FakeApi();
    final state = await ready(api);
    state.selectSeat(19);
    api.open = false;
    expect(await state.submit(), null);
    expect(api.posts, 0);
    expect(state.error, contains('closed'));
  });
  test(
      'successful booking refreshes availability/history and prevents duplicate submit',
      () async {
    final api = FakeApi()..pending = Completer<Booking>();
    final state = await ready(api);
    state.selectSeat(19);
    final first = state.submit();
    final second = await state.submit();
    expect(second, null);
    api.pending!.complete(receipt());
    expect((await first)!.id, '42');
    expect(api.posts, 1);
    expect(state.confirmed!.id, '42');
    expect(state.history.single.id, '42');
    expect(api.reads, 3);
    expect(await state.submit(), null);
  });
  test(
    'standing submission sends only the existing booking contract',
    () async {
      final api = FakeApi();
      final state = await ready(api);
      state.selectStanding();
      await state.submit();
      expect(api.input, {
        'tripId': 'trip-a',
        'travelDate': state.date,
        'seatNumber': null,
        'standing': true,
      });
    },
  );
  test('backend rejection is shown without false confirmation', () async {
    final api = FakeApi()..failure = ApiFailure('booking_window_closed');
    final state = await ready(api);
    state.selectStanding();
    expect(await state.submit(), null);
    expect(state.confirmed, null);
    expect(state.error, contains('closed'));
    expect(state.busy, false);
  });
  test('uncertain network failure blocks retries', () async {
    final api = FakeApi()..failure = ApiFailure('network');
    final state = await ready(api);
    state.selectSeat(19);
    await state.submit();
    expect(state.uncertain, true);
    await state.submit();
    expect(api.posts, 1);
  });
  test(
    'history/details survive a fresh frontend state and cancellation',
    () async {
      final api = FakeApi();
      final state = await ready(api);
      state.selectSeat(19);
      await state.submit();
      final restored = await ready(api);
      expect(restored.history.single.id, '42');
      expect((await restored.details('42'))!.id, '42');
      await state.cancel('42');
      expect(state.confirmed!.status, 'cancelled');
      expect(state.history.single.section, 'Cancelled');
      await restored.load();
      expect(restored.history.single.status, 'cancelled');
    },
  );
  testWidgets('selected seat and standing visual state', (tester) async {
    final state = await ready(FakeApi());
    await tester.pumpWidget(
      MaterialApp(home: StudentBookingScreen(state: state)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book Bus').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('19\nAvailable'));
    await tester.pump();
    expect(find.text('19\nSelected'), findsOneWidget);
    await tester.ensureVisible(find.text('Standing · 2 available'));
    await tester.tap(find.text('Standing · 2 available'));
    await tester.pump();
    expect(state.standing, true);
  });
  testWidgets('review retains selection and disables closed-window confirm', (
    tester,
  ) async {
    final state = await ready(FakeApi()..open = false);
    state.selectSeat(19);
    await tester.pumpWidget(
      MaterialApp(home: BookingReviewScreen(state: state)),
    );
    expect(find.textContaining('Seat 19'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm & Book'),
    );
    expect(button.onPressed, null);
  });
  testWidgets(
    'only confirmed bookings render an injected real ticket; cancellation removes it',
    (tester) async {
      Widget ticket(BuildContext context, Booking booking) =>
          Text('Existing server ticket #${booking.id}');
      await tester.pumpWidget(
        receiptApp(receipt(), ticket),
      );
      expect(find.text('Existing server ticket #42'), findsOneWidget);
      await tester.pumpWidget(
        receiptApp(receipt(status: 'cancelled'), ticket),
      );
      expect(find.text('Existing server ticket #42'), findsNothing);
    },
  );
  testWidgets(
    'details cancellation removes the active ticket and shows cancelled status',
    (tester) async {
      final api = FakeApi()..posts = 1;
      final state = await ready(api);
      await tester.pumpWidget(
        MaterialApp(
          home: BookingDetailsScreen(
            state: state,
            id: '42',
            ticketBuilder: (_, booking) => Text('Server ticket #${booking.id}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Server ticket #42'), findsOneWidget);
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel booking').last);
      await tester.pumpAndSettle();
      expect(find.text('Server ticket #42'), findsNothing);
      expect(find.text('Status: cancelled'), findsOneWidget);
    },
  );
  testWidgets('absent server QR never generates a fake QR', (tester) async {
    await tester.pumpWidget(
      receiptApp(receipt()),
    );
    expect(find.textContaining('QR ticket unavailable'), findsOneWidget);
    expect(find.text('Fare: Unavailable from server'), findsOneWidget);
  });
}
