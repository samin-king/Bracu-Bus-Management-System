import 'booking.dart';

class RoutePattern {
  RoutePattern(this.json);
  final Json json;
  String get id => json['pattern_id'].toString();
  String get variantId => json['variant_id'].toString();
  String get code => json['variant_code'] as String;
  String get name => json['variant_name'] as String;
  String get direction => json['direction'] as String;
  bool get verified => json['verified'] == true;
}
