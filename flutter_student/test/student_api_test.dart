import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bracu_student_booking/student_booking.dart';

void main() {
  test(
      'adapter reuses booking paths, session, Origin and payload without fare or QR',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = <String>[];
    final bodies = <dynamic>[];
    final headers = <String?>[];
    server.listen((req) async {
      seen.add('${req.method} ${req.uri}');
      headers.add(req.headers.value('cookie'));
      expect(req.headers.value('origin'), 'https://existing-frontend.example');
      if (req.method == 'POST')
        bodies.add(jsonDecode(await utf8.decoder.bind(req).join()));
      req.response.headers.contentType = ContentType.json;
      final booking = {'id': '42', 'status': 'confirmed'};
      Object value = booking;
      if (req.uri.path.endsWith('/trips')) value = [];
      if (req.uri.path.endsWith('/seats')) value = {'bookingOpen': false};
      if (req.uri.path.endsWith('/bookings') && req.method == 'GET')
        value = [booking];
      req.response.write(jsonEncode(value));
      await req.response.close();
    });
    final client = HttpClient();
    final api = HttpStudentApi(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      frontendOrigin: 'https://existing-frontend.example',
      sessionCookie: () async => 'connect.sid=existing-session',
      client: client,
    );
    try {
      await api.trips('2026-11-04');
      await api.seats('trip-a', '2026-11-04');
      await api.book({
        'tripId': 'trip-a',
        'travelDate': '2026-11-04',
        'seatNumber': 19,
        'standing': false,
      });
      await api.bookings();
      await api.booking('42');
      await api.cancel('42');
      expect(seen, [
        'GET /api/student/trips?date=2026-11-04',
        'GET /api/student/trips/trip-a/seats?date=2026-11-04',
        'POST /api/student/bookings',
        'GET /api/student/bookings',
        'GET /api/student/bookings/42',
        'POST /api/student/bookings/42/cancel',
      ]);
      expect(headers, everyElement('connect.sid=existing-session'));
      expect(bodies, [
        {
          'tripId': 'trip-a',
          'travelDate': '2026-11-04',
          'seatNumber': 19,
          'standing': false,
        },
        {},
      ]);
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
  test('adapter preserves backend booking-window rejection', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      req.response.statusCode = 409;
      req.response.write('{"error":"booking_window_closed"}');
      await req.response.close();
    });
    final client = HttpClient();
    final api = HttpStudentApi(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      frontendOrigin: 'https://existing-frontend.example',
      sessionCookie: () async => 'existing',
      client: client,
    );
    try {
      await expectLater(
        api.book({}),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'booking_window_closed',
          ),
        ),
      );
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
}
