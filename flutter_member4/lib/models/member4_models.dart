typedef Json = Map<String, dynamic>;

const categories = ['service', 'driver', 'safety', 'schedule', 'other'];
const statuses = ['pending', 'in_review', 'resolved', 'rejected'];
const targets = ['service', 'bus', 'trip', 'route'];

class Complaint {
  Complaint.fromJson(Json json) : data = Map.unmodifiable(json) {
    _id(json);
    _choice(json, 'category', categories);
    _choice(json, 'status', statuses);
    _string(json, 'description');
    _optionalString(json, 'response');
  }
  final Json data;
  String get id => '${data['id']}';
  String get category => data['category'] as String;
  String get description => data['description'] as String;
  String get status => data['status'] as String;
  String? get response => data['response'] as String?;
}

class FeedbackEntry {
  FeedbackEntry.fromJson(Json json) : data = Map.unmodifiable(json) {
    _id(json);
    _choice(json, 'target', targets);
    final rating = json['rating'];
    if (rating is! int || rating < 1 || rating > 5) {
      throw const FormatException('Invalid feedback rating');
    }
    _optionalString(json, 'comment');
  }
  final Json data;
}

class BusNotification {
  BusNotification.fromJson(Json json) : data = Map.unmodifiable(json) {
    _id(json);
    _string(json, 'title');
    _string(json, 'message');
    _optionalString(json, 'read_at');
    if (json['read_at'] != null && DateTime.tryParse(json['read_at'] as String) == null) {
      throw const FormatException('Invalid read timestamp');
    }
  }
  final Json data;
  String get id => '${data['id']}';
  String get title => data['title'] as String;
  String get message => data['message'] as String;
  bool get isRead => data['read_at'] != null;
}

void _id(Json json) {
  final value = json['id'];
  if ((value is! int && value is! String) || referenceId('$value', required: true) != null) {
    throw const FormatException('Invalid record ID');
  }
}

void _string(Json json, String key) {
  if (json[key] is! String) throw FormatException('Invalid $key');
}

void _optionalString(Json json, String key) {
  if (json[key] != null) _string(json, key);
}

void _choice(Json json, String key, List<String> values) {
  if (!values.contains(json[key])) throw FormatException('Invalid $key');
}

String? requiredText(String? value, {int max = 5000}) {
  if (value == null || value.trim().isEmpty || value.length > max) {
    return 'Enter 1–$max characters';
  }
  return null;
}

String? referenceId(String? value, {bool required = false}) {
  if ((value ?? '').isEmpty && !required) return null;
  final number = int.tryParse(value ?? '');
  if (!RegExp(r'^[1-9]\d*$').hasMatch(value ?? '') ||
      number == null || number > 2147483647) {
    return 'Enter an ID from 1 to 2147483647';
  }
  return null;
}
