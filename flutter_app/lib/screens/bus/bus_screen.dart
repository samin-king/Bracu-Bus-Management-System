import '../../services/api_client.dart';
import '../../services/bus_service.dart';
import '../management_screen.dart';
import '../../models/bus.dart';

class BusScreen extends ManagementScreen<Bus> {
  BusScreen({super.key, required ApiClient api})
      : super(service: BusService(api), title: 'Buses', kind: 'bus');
}
