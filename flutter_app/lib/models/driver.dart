import 'transport_record.dart';

class Driver extends TransportRecord {
  Driver(super.json);
  @override
  String get title => data['name'] as String;
  @override
  Map<String, String> get details => {
        'Name': title,
        'License number': data['license_number'] as String,
        'Status': status,
      };
  @override
  Json get writable => {
        for (final k in ['name', 'license_number', 'status']) k: data[k],
      };
}
