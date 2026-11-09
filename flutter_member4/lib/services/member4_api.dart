import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/member4_models.dart';

class Member4Exception implements Exception {
  Member4Exception(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// The host owns this client and supplies its existing session/token transport.
/// No identity headers, credentials, or role claims are constructed here.
class Member4Api {
  Member4Api({required this.baseUrl, required this.client,
      this.timeout = const Duration(seconds: 30)}) {
    if (!baseUrl.isAbsolute || !['http', 'https'].contains(baseUrl.scheme) ||
        baseUrl.host.isEmpty || !baseUrl.path.endsWith('/') ||
        baseUrl.hasQuery || baseUrl.hasFragment || baseUrl.userInfo.isNotEmpty) {
      throw ArgumentError('Use an absolute HTTP(S) API base URL ending in /');
    }
    if (timeout <= Duration.zero) throw ArgumentError('Timeout must be positive');
  }
  final Uri baseUrl; // Absolute URL ending in /api/.
  final http.Client client;
  final Duration timeout;

  Future<dynamic> request(String path, {String method = 'GET', Json? body,
      Map<String, String>? query}) async {
    final uri = baseUrl.resolve(path).replace(queryParameters: query);
    try {
      final request = http.Request(method, uri);
      request.headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await (() async => http.Response.fromStream(
        await client.send(request)))().timeout(timeout);
      dynamic data;
      try { data = jsonDecode(utf8.decode(response.bodyBytes)); } on FormatException {
        throw Member4Exception('Unexpected API response', response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Member4Exception(data is Map && data['error'] is String
            ? data['error'] as String : 'Request failed', response.statusCode);
      }
      return data;
    } on TimeoutException {
      throw Member4Exception('Request timed out. Please retry.');
    } on http.ClientException {
      throw Member4Exception('Unable to reach the server. Please retry.');
    }
  }

  String complaintPath(bool management) =>
      management ? 'authority/complaints' : 'complaints';
  Map<String, String> _paging(int page) {
    if (page < 0 || page > 42949672) throw ArgumentError('Invalid page');
    return {'limit': '50', 'offset': '${page * 50}'};
  }
  String _id(String value) {
    if (referenceId(value, required: true) != null) throw ArgumentError('Invalid ID');
    return value;
  }
  T _parse<T>(T Function() parse) {
    try { return parse(); } on FormatException {
      throw Member4Exception('Unexpected API response');
    }
  }
  Json _object(dynamic data) {
    if (data is! Json) throw const FormatException('Expected JSON object');
    return data;
  }
  List<T> _list<T>(dynamic data, T Function(Json) parse) => _parse(() {
    if (data is! List) throw const FormatException('Expected JSON array');
    return data.map((x) => parse(_object(x))).toList();
  });
  Future<List<Complaint>> complaints(int page, {bool management = false,
      Map<String, String> filters = const {}}) async =>
    _list(await request(complaintPath(management), query: {
      ...filters, ..._paging(page),
    }), Complaint.fromJson);
  Future<Complaint> complaint(String id, {bool management = false}) async {
    final data = await request('${complaintPath(management)}/${_id(id)}');
    return _parse(() => Complaint.fromJson(_object(data)));
  }
  Future<Complaint> submitComplaint(Json body) async {
    final data = await request('complaints', method: 'POST', body: body);
    return _parse(() => Complaint.fromJson(_object(data)));
  }
  Future<Complaint> updateComplaint(String id, Json body) async {
    final data = await request('authority/complaints/${_id(id)}', method: 'PATCH', body: body);
    return _parse(() => Complaint.fromJson(_object(data)));
  }
  Future<List<FeedbackEntry>> feedback(int page) async =>
      _list(await request('feedback', query: _paging(page)), FeedbackEntry.fromJson);
  Future<void> submitFeedback(Json body) async {
    await request('feedback', method: 'POST', body: body);
  }
  Future<List<BusNotification>> notifications(int page) async =>
      _list(await request('notifications', query: _paging(page)), BusNotification.fromJson);
  Future<int> unread() async {
    final data = await request('notifications/unread-count');
    return _parse(() {
      final count = _object(data)['count'];
      if (count is! int || count < 0) throw const FormatException('Invalid unread count');
      return count;
    });
  }
  Future<void> markRead(String id) async { await request('notifications/${_id(id)}/read', method: 'PATCH'); }
  Future<void> markAllRead() async { await request('notifications/read-all', method: 'PATCH'); }
}
