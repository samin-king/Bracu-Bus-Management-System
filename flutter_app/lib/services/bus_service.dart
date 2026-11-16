import '../models/bus.dart';
import 'resource_service.dart';
import 'api_client.dart';

class BusService extends ResourceService<Bus> {
  BusService(ApiClient api) : super(api, 'buses', Bus.new);
}
