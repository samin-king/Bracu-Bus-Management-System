import '../models/driver.dart';
import '../models/trip.dart';
import 'api_client.dart';
import 'resource_service.dart';
import 'trip_service.dart';

class DriverService extends ResourceService<Driver> {
  DriverService(ApiClient api) : super(api, 'drivers', Driver.new);
  Future<Driver> me() async {
    api.requireRole(TransportRole.driver);
    return decode(await api.request('drivers/me'));
  }

  Future<List<Trip>> assignedTrips() async {
    api.requireRole(TransportRole.driver);
    return TripService(api).decodeList(await api.request('drivers/me/trips'));
  }

  Future<Trip> assign(int tripId, int? driverId) async {
    api.requireRole(TransportRole.authority);
    return TripService(api).decode(
      await api.request(
        'trips/$tripId/driver',
        method: 'PUT',
        body: {'driver_id': driverId},
      ),
    );
  }

  Future<Trip> transition(int tripId, String action) async {
    api.requireRole(TransportRole.driver);
    if (!['start', 'stop'].contains(action)) {
      throw const ApiException('Invalid trip action.');
    }
    return TripService(api)
        .decode(await api.request('trips/$tripId/$action', method: 'POST'));
  }
}
