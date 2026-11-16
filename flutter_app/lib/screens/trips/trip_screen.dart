import '../../services/api_client.dart';
import '../../services/trip_service.dart';
import '../management_screen.dart';
import '../../models/trip.dart';

class TripScreen extends ManagementScreen<Trip> {
  TripScreen({super.key, required ApiClient api})
      : super(service: TripService(api), title: 'Trips', kind: 'trip');
}
