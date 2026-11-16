import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../models/transport_record.dart';
import '../services/api_client.dart';

/// All data and writes stay in this browser tab. No network client is used.
class DemoStore extends ChangeNotifier {
  DemoStore() {
    reset();
  }
  final tables = <String, List<Json>>{};
  String viewState = 'Normal';
  Completer<void>? _loading;
  Json profile = {};
  void changed() => notifyListeners();

  void reset() {
    final date = DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    profile = {
      'name': 'Ayesha Rahman',
      'email': 'demo.student@example.invalid',
      'student_id': 'DEMO-2026001',
      'phone': 'DEMO-01000000000',
    };
    tables.addAll({
      'buses': [
        {
          'id': 1,
          'bus_number': 'BRACU-01',
          'registration_number': 'DEMO-DHK-1001',
          'capacity': 37,
          'status': 'ACTIVE',
        },
        {
          'id': 2,
          'bus_number': 'BRACU-02',
          'registration_number': 'DEMO-DHK-1002',
          'capacity': 28,
          'status': 'ACTIVE',
        },
        {
          'id': 3,
          'bus_number': 'BRACU-03',
          'registration_number': 'DEMO-DHK-1003',
          'capacity': 40,
          'status': 'MAINTENANCE',
        },
      ],
      'routes': [
        {
          'id': 1,
          'route_name': 'Mirpur to BRACU',
          'origin': 'Mirpur 10',
          'destination': 'BRAC University',
          'stops': ['Mirpur 10', 'Agargaon', 'Farmgate', 'BRAC University'],
        },
        {
          'id': 2,
          'route_name': 'Uttara to BRACU',
          'origin': 'Uttara',
          'destination': 'BRAC University',
          'stops': ['Uttara', 'Airport', 'Badda', 'BRAC University'],
        },
      ],
      'drivers': [
        {
          'id': 1,
          'name': 'Karim Ahmed (Demo)',
          'license_number': 'DEMO-DL-1001',
          'status': 'ACTIVE',
        },
        {
          'id': 2,
          'name': 'Rahim Uddin (Demo)',
          'license_number': 'DEMO-DL-1002',
          'status': 'ACTIVE',
        },
        {
          'id': 3,
          'name': 'Hasan Ali (Demo)',
          'license_number': 'DEMO-DL-1003',
          'status': 'INACTIVE',
        },
      ],
      'trips': [
        {
          'id': 1,
          'bus_id': 1,
          'route_id': 1,
          'driver_id': 1,
          'travel_date': date,
          'departure_time': '07:00:00',
          'status': 'SCHEDULED',
        },
        {
          'id': 2,
          'bus_id': 2,
          'route_id': 2,
          'driver_id': 2,
          'travel_date': date,
          'departure_time': '08:00:00',
          'status': 'SCHEDULED',
        },
        {
          'id': 3,
          'bus_id': 1,
          'route_id': 2,
          'driver_id': null,
          'travel_date': date,
          'departure_time': '15:30:00',
          'status': 'SCHEDULED',
        },
      ],
      'bookings': [
        {
          'id': 1,
          'trip_id': 1,
          'name': 'Nadia Islam (Synthetic)',
          'student_id': 2,
          'seats': 1,
          'status': 'CONFIRMED',
        },
        {
          'id': 2,
          'trip_id': 1,
          'name': 'Farhan Hasan (Synthetic)',
          'student_id': 3,
          'seats': 1,
          'status': 'CONFIRMED',
        },
      ],
      'complaints': [
        {
          'id': 1,
          'title': 'Late departure',
          'message':
              'Please notify passengers if the morning departure is delayed.',
          'status': 'OPEN',
          'student_id': 1,
        },
      ],
      'feedback': [
        {
          'id': 1,
          'title': 'Comfortable journey',
          'message': 'The morning Mirpur service was comfortable.',
          'rating': '5',
          'status': 'SUBMITTED',
          'student_id': 1,
        },
      ],
      'notifications': [
        {
          'id': 1,
          'title': 'Welcome to BRACU Transport',
          'message': 'Explore the local demo. All records are synthetic.',
          'audience': 'ALL',
          'status': 'PUBLISHED',
          'read': false,
        },
        {
          'id': 2,
          'title': 'Morning departure reminder',
          'message': 'Please arrive at your stop ten minutes before departure.',
          'audience': 'STUDENT',
          'status': 'PUBLISHED',
          'read': false,
        },
      ],
    });
    notifyListeners();
  }

  Json record(String resource, int id) => tables[resource]!.firstWhere(
    (r) => r['id'] == id,
    orElse: () => throw const ApiException('Demo record not found.', 404),
  );
  int nextId(String resource) =>
      tables[resource]!.fold<int>(
        0,
        (a, b) => a > (b['id'] as int) ? a : b['id'] as int,
      ) +
      1;
  Json joinedTrip(Json trip) => {
    ...trip,
    'bus': record('buses', trip['bus_id'] as int),
    'route': record('routes', trip['route_id'] as int),
    'driver': trip['driver_id'] == null
        ? null
        : record('drivers', trip['driver_id'] as int),
  };

  void setViewState(String state) {
    if (_loading != null && !_loading!.isCompleted) _loading!.complete();
    _loading = state == 'Loading' ? Completer<void>() : null;
    viewState = state;
    notifyListeners();
  }

  Future<void> waitForView() async {
    if (viewState == 'Loading') await _loading?.future;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (viewState == 'Error') {
      throw const ApiException(
        'Demo: server unavailable. Choose Normal, then Retry.',
        503,
      );
    }
  }

  ApiClient api(TransportRole role) => ApiClient(
    baseUrl: 'https://local-demo.invalid/api',
    // This session is ONLY for the intercepted in-memory client below.
    session: TransportSession(role: role, headers: () async => {}),
    client: MockClient((request) async {
      try {
        if (request.url.host != 'local-demo.invalid') {
          throw const ApiException(
            'External requests are forbidden in demo mode.',
            403,
          );
        }
        await waitForView();
        final path = request.url.path.replaceFirst('/api/', '').split('/');
        final resource = path.first;
        if (resource == 'drivers' && path.length > 1 && path[1] == 'me') {
          if (role != TransportRole.driver) {
            throw const ApiException('Demo Driver permission required.', 403);
          }
          return _response(
            path.length == 2
                ? record('drivers', 1)
                : viewState == 'Empty'
                ? []
                : tables['trips']!
                      .where((t) => t['driver_id'] == 1)
                      .map(joinedTrip)
                      .toList(),
          );
        }
        if (resource == 'trips' &&
            path.length == 3 &&
            ['start', 'stop'].contains(path.last)) {
          if (role != TransportRole.driver) {
            throw const ApiException('Demo Driver permission required.', 403);
          }
          return _response(transition(int.parse(path[1]), path.last));
        }
        if (role != TransportRole.authority) {
          throw const ApiException('Demo Authority permission required.', 403);
        }
        if (!['buses', 'routes', 'trips', 'drivers'].contains(resource)) {
          throw const ApiException('Unsupported demo resource.', 404);
        }
        final id = path.length > 1 ? int.parse(path[1]) : null;
        if (request.method == 'GET') {
          dynamic data = id == null
              ? (viewState == 'Empty' ? <Json>[] : tables[resource]!)
              : record(resource, id);
          if (resource == 'trips') {
            data = id == null
                ? (data as List<Json>).map(joinedTrip).toList()
                : joinedTrip(data as Json);
          }
          return _response(data);
        }
        if (!['POST', 'PUT'].contains(request.method)) {
          throw const ApiException('Unsupported demo action.', 405);
        }
        final body = jsonDecode(request.body) as Json;
        if (resource == 'trips' && path.length == 3 && path.last == 'driver') {
          return _response(assign(id!, body['driver_id'] as int?));
        }
        final saved = saveResource(resource, body, id: id);
        return _response(
          resource == 'trips' ? joinedTrip(saved) : saved,
          request.method == 'POST' ? 201 : 200,
        );
      } on ApiException catch (e) {
        return _response({'error': e.message}, e.statusCode ?? 400);
      }
    }),
  );
  http.Response _response(dynamic data, [int status = 200]) =>
      http.Response(jsonEncode(data), status);

  Json saveResource(String resource, Json body, {int? id}) {
    final candidate = {
      ...(id == null ? <String, dynamic>{} : record(resource, id)),
      ...body,
      'id': id ?? nextId(resource),
    };
    if (resource == 'buses') {
      if ((candidate['capacity'] as num?) == null ||
          (candidate['capacity'] as num) < 1) {
        throw const ApiException('Capacity must be positive.', 400);
      }
      if (tables[resource]!.any(
        (r) =>
            r['id'] != id &&
            (r['bus_number'] == candidate['bus_number'] ||
                candidate['registration_number'] != null &&
                    r['registration_number'] ==
                        candidate['registration_number']),
      )) {
        throw const ApiException(
          'Bus number or registration already exists.',
          409,
        );
      }
    }
    if (resource == 'drivers' &&
        tables[resource]!.any(
          (r) =>
              r['id'] != id &&
              r['license_number'] == candidate['license_number'],
        )) {
      throw const ApiException('License number already exists.', 409);
    }
    if (resource == 'trips') {
      final bus = record('buses', candidate['bus_id'] as int);
      record('routes', candidate['route_id'] as int);
      if (bus['status'] != 'ACTIVE') {
        throw const ApiException('Choose an active demo bus.', 409);
      }
      if (id != null &&
          record(resource, id)['driver_id'] != null &&
          record(resource, id)['status'] != 'SCHEDULED') {
        throw const ApiException(
          'Assigned active/historical trips are locked.',
          409,
        );
      }
      if (tables[resource]!.any(
        (t) =>
            t['id'] != id &&
            t['bus_id'] == candidate['bus_id'] &&
            t['travel_date'] == candidate['travel_date'] &&
            '${t['departure_time']}'.substring(0, 5) ==
                '${candidate['departure_time']}'.substring(0, 5),
      )) {
        throw const ApiException(
          'This bus already has a trip at that departure.',
          409,
        );
      }
    }
    if (id == null) {
      tables[resource]!.add(candidate);
    } else {
      tables[resource]![tables[resource]!.indexWhere((r) => r['id'] == id)] =
          candidate;
    }
    notifyListeners();
    return candidate;
  }

  Json assign(int tripId, int? driverId) {
    final trip = record('trips', tripId);
    if (trip['status'] != 'SCHEDULED') {
      throw const ApiException('Only scheduled trips can be assigned.', 409);
    }
    if (driverId != null) {
      if (record('drivers', driverId)['status'] != 'ACTIVE') {
        throw const ApiException('Choose an active driver.', 409);
      }
      if (tables['trips']!.any(
        (t) =>
            t['id'] != tripId &&
            t['driver_id'] == driverId &&
            t['travel_date'] == trip['travel_date'] &&
            t['departure_time'] == trip['departure_time'] &&
            t['status'] != 'CANCELLED',
      )) {
        throw const ApiException(
          'Driver has another departure at this time.',
          409,
        );
      }
    }
    trip['driver_id'] = driverId;
    notifyListeners();
    return joinedTrip(trip);
  }

  Json transition(int id, String action) {
    final trip = record('trips', id);
    if (trip['driver_id'] != 1) {
      throw const ApiException(
        'This trip belongs to another demo driver.',
        403,
      );
    }
    if (record('drivers', 1)['status'] != 'ACTIVE') {
      throw const ApiException('Driver profile is inactive.', 409);
    }
    if (action == 'start' && trip['status'] == 'SCHEDULED') {
      if (tables['trips']!.any(
        (t) => t['driver_id'] == 1 && t['status'] == 'ACTIVE',
      )) {
        throw const ApiException('Complete your active trip first.', 409);
      }
      trip['status'] = 'ACTIVE';
      trip['started_at'] = DateTime.now().toUtc().toIso8601String();
    } else if (action == 'stop' && trip['status'] == 'ACTIVE') {
      trip['status'] = 'COMPLETED';
      trip['completed_at'] = DateTime.now().toUtc().toIso8601String();
    } else {
      throw const ApiException('Invalid trip state transition.', 409);
    }
    notifyListeners();
    return joinedTrip(trip);
  }

  int availableSeats(int tripId) {
    final trip = record('trips', tripId);
    return (record('buses', trip['bus_id'] as int)['capacity'] as int) -
        tables['bookings']!
            .where((b) => b['trip_id'] == tripId && b['status'] == 'CONFIRMED')
            .fold<int>(0, (a, b) => a + (b['seats'] as int));
  }

  void book(int tripId, int seats) {
    if (record('trips', tripId)['status'] != 'SCHEDULED') {
      throw const ApiException('Only scheduled trips can be booked.');
    }
    if (seats < 1 || seats > 4 || seats > availableSeats(tripId)) {
      throw const ApiException('Choose 1–4 available seats.');
    }
    if (tables['bookings']!.any(
      (b) =>
          b['trip_id'] == tripId &&
          b['student_id'] == 1 &&
          b['status'] == 'CONFIRMED',
    )) {
      throw const ApiException('You already have a booking for this trip.');
    }
    tables['bookings']!.add({
      'id': nextId('bookings'),
      'trip_id': tripId,
      'name': profile['name'],
      'student_id': 1,
      'seats': seats,
      'status': 'CONFIRMED',
    });
    notifyListeners();
  }

  void cancelBooking(int id) {
    final booking = record('bookings', id);
    if (booking['student_id'] != 1 ||
        record('trips', booking['trip_id'] as int)['status'] != 'SCHEDULED') {
      throw const ApiException(
        'Only your scheduled bookings can be cancelled.',
      );
    }
    booking['status'] = 'CANCELLED';
    notifyListeners();
  }
}
