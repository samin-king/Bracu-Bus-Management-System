import '../../services/api_client.dart';
import '../../services/driver_service.dart';
import '../management_screen.dart';
import '../../models/driver.dart';

class DriverScreen extends ManagementScreen<Driver> {
  DriverScreen({super.key, required ApiClient api})
      : super(service: DriverService(api), title: 'Drivers', kind: 'driver');
}
