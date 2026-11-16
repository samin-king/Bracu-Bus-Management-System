import '../models/route.dart';
import 'resource_service.dart';
import 'api_client.dart';

class RouteService extends ResourceService<BusRoute> {
  RouteService(ApiClient api) : super(api, 'routes', BusRoute.new);
}
