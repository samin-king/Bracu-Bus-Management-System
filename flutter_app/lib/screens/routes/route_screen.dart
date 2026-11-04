import '../../services/api_client.dart';
import '../../services/route_service.dart';
import '../management_screen.dart';
import '../../models/route.dart';

class RouteScreen extends ManagementScreen<BusRoute> {
  RouteScreen({super.key, required ApiClient api})
      : super(service: RouteService(api), title: 'Routes', kind: 'route');
}
