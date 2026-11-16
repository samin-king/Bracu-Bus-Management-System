typedef Json = Map<String, dynamic>;

abstract class TransportRecord {
  TransportRecord(Json json) : data = Map.unmodifiable(json);
  final Json data;
  int get id => (data['id'] as num).toInt();
  String get title;
  String get status => data['status'] as String? ?? '';
  Map<String, String> get details;
  Json get writable;
}
