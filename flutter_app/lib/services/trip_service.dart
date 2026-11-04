import '../models/trip.dart';
import 'resource_service.dart';
import 'api_client.dart';

class TripService extends ResourceService<Trip> {
  TripService(ApiClient api) : super(api, 'trips', Trip.new);
}
