import 'bus.dart';
import 'route.dart';
import 'transport_record.dart';

class Trip extends TransportRecord {
  Trip(super.json);
  Bus get bus => Bus(Json.from(data['bus'] as Map));
  BusRoute get route => BusRoute(Json.from(data['route'] as Map));
  int? get driverId => (data['driver_id'] as num?)?.toInt();
  String get driverName =>
      (data['driver'] as Map?)?['name'] as String? ?? 'Unassigned';
  @override
  String get title => route.title;
  String get schedule =>
      '${data['travel_date']} / ${data['departure_time']} (Dhaka)';
  String? get action => status == 'SCHEDULED'
      ? 'start'
      : status == 'ACTIVE'
          ? 'stop'
          : null;
  @override
  Map<String, String> get details => {
        'Route': title,
        'Bus': bus.title,
        'Capacity': '${bus.capacity}',
        'Origin': route.details['Origin']!,
        'Destination': route.details['Destination']!,
        'Stops': route.details['Stops']!,
        'Departure': schedule,
        'Status': status,
        'Driver': driverName,
        if (data['started_at'] != null)
          'Started (Dhaka)': _dhaka(data['started_at'] as String),
        if (data['completed_at'] != null)
          'Completed (Dhaka)': _dhaka(data['completed_at'] as String),
      };
  static String _dhaka(String value) =>
      '${DateTime.parse(value).toUtc().add(const Duration(hours: 6)).toIso8601String().replaceFirst('T', ' ').replaceFirst('Z', '')} UTC+06';
  @override
  Json get writable => {
        for (final k in [
          'bus_id',
          'route_id',
          'travel_date',
          'departure_time',
          'status',
        ])
          k: data[k],
      };
}
