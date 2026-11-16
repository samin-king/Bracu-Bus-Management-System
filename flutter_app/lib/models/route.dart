import 'transport_record.dart';

class BusRoute extends TransportRecord {
  BusRoute(super.json);
  @override
  String get title => data['route_name'] as String;
  List<String> get stops => List<String>.from(data['stops'] as List);
  @override
  Map<String, String> get details => {
        'Route name': title,
        'Origin': data['origin'] as String,
        'Destination': data['destination'] as String,
        'Stops': stops.isEmpty ? 'No stops recorded' : stops.join(' → '),
      };
  @override
  Json get writable => {
        for (final k in ['route_name', 'origin', 'destination', 'stops'])
          k: data[k],
      };
}
