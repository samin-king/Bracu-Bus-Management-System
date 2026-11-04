import 'dart:convert';
import 'dart:io';

import '../models/booking.dart';

class ApiFailure implements Exception {
  ApiFailure(this.code);
  final String code;
  @override
  String toString() =>
      const {
        'unauthenticated': 'Your session has expired. Please sign in again.',
        'booking_window_closed': 'Booking is closed for this trip.',
        'booking_conflict':
            'This seat or trip is already booked. Refresh and choose again.',
        'women_reserved':
            'Seats 1–18 require a verified female student profile.',
        'standing_male_only':
            'Standing requires a verified male student profile.',
        'standing_full': 'Standing tickets are sold out.',
        'daily_booking_limit':
            'You already have four confirmed trips on this date.',
        'cancellation_closed':
            'This trip has departed and cannot be cancelled.',
        'already_cancelled': 'This booking has already been cancelled.',
        'network':
            'Connection failed. Refresh booking history before retrying a booking.',
      }[code] ??
      'Request failed: ${code.replaceAll('_', ' ')}.';
}

abstract class StudentApi {
  Future<List<Trip>> trips(String date);
  Future<Availability> seats(String trip, String date);
  Future<Booking> book(Json input);
  Future<List<Booking>> bookings();
  Future<Booking> booking(String id);
  Future<Booking> cancel(String id);
}

/// Inject the authenticated app's cookie provider; no alternate login or identity.
class HttpStudentApi implements StudentApi {
  HttpStudentApi({
    required this.baseUrl,
    required this.frontendOrigin,
    required this.sessionCookie,
    HttpClient? client,
  }) : _client = client ?? HttpClient();
  final Uri baseUrl;
  final String frontendOrigin;
  final Future<String> Function() sessionCookie;
  final HttpClient _client;
  Future<dynamic> request(String path, {Json? body}) async {
    try {
      final req = await _client
          .openUrl(
            body == null ? 'GET' : 'POST',
            baseUrl.resolve('/api/student$path'),
          )
          .timeout(const Duration(seconds: 20));
      req.followRedirects = false;
      req.headers.set(HttpHeaders.cookieHeader, await sessionCookie());
      req.headers.set('Origin', frontendOrigin);
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      req.headers.contentType = ContentType.json;
      if (body != null) req.write(jsonEncode(body));
      final response = await req.close().timeout(const Duration(seconds: 20));
      final value = jsonDecode(
        await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 20)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw ApiFailure(
          value is Map
              ? value['error']?.toString() ?? 'http_${response.statusCode}'
              : 'http_${response.statusCode}',
        );
      return value;
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw ApiFailure('network');
    }
  }

  @override
  Future<List<Trip>> trips(String date) async =>
      (await request('/trips?date=${Uri.encodeQueryComponent(date)}') as List)
          .map((j) => Trip(j as Json))
          .toList();
  @override
  Future<Availability> seats(String trip, String date) async => Availability(
        await request(
          '/trips/${Uri.encodeComponent(trip)}/seats?date=${Uri.encodeQueryComponent(date)}',
        ) as Json,
      );
  @override
  Future<Booking> book(Json input) async =>
      Booking(await request('/bookings', body: input) as Json);
  @override
  Future<List<Booking>> bookings() async => (await request('/bookings') as List)
      .map((j) => Booking(j as Json))
      .toList();
  @override
  Future<Booking> booking(String id) async =>
      Booking(await request('/bookings/${Uri.encodeComponent(id)}') as Json);
  @override
  Future<Booking> cancel(String id) async => Booking(
        await request('/bookings/${Uri.encodeComponent(id)}/cancel', body: {})
            as Json,
      );
}
