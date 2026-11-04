import 'transport_record.dart';

class Bus extends TransportRecord {
  Bus(super.json);
  @override
  String get title => data['bus_number'] as String;
  int get capacity => (data['capacity'] as num).toInt();
  @override
  Map<String, String> get details => {
        'Bus number': title,
        'Registration number':
            data['registration_number'] as String? ?? 'Not provided',
        'Capacity': '$capacity',
        'Status': status,
      };
  @override
  Json get writable => {
        for (final k in [
          'bus_number',
          'registration_number',
          'capacity',
          'status'
        ])
          k: data[k],
      };
}
