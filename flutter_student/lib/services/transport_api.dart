import '../models/booking.dart';
import '../models/transport.dart';
import 'student_api.dart';

abstract class TransportApi {
  Future<List<RoutePattern>> routes();
  Future<Json> pattern(String id);
  Future<Json> schedules(
      {String? variantId,
      String? date,
      String? direction,
      int page = 1,
      bool admin = false});
  Future<bool> adminAccess();
  Future<Json> resources(String kind, {int page = 1});
  Future<Json> saveResource(String kind, Json input, {String? id});
  Future<Json> saveSchedule(Json input, {String? id});
  Future<Json> saveStop(String id, Json input);
  Future<Json> reorder(String id, List<String> ids);
  Future<Json> verifyVariant(String id, String reference);
  Future<Json> removeException(String date);
}

class HttpTransportApi implements TransportApi {
  HttpTransportApi(this.http);
  final HttpStudentApi http;
  Future<dynamic> _request(String path,
          {bool admin = false, String? method, Json? body}) =>
      http.request(path,
          namespace: admin ? '/api/transport-admin' : '/api/student/transport',
          method: method,
          body: body);
  @override
  Future<List<RoutePattern>> routes() async =>
      (await _request('/routes') as List)
          .map((row) => RoutePattern(row as Json))
          .toList();
  @override
  Future<Json> pattern(String id) async =>
      await _request('/patterns/${Uri.encodeComponent(id)}') as Json;
  @override
  Future<Json> schedules(
      {String? variantId,
      String? date,
      String? direction,
      int page = 1,
      bool admin = false}) async {
    final query = Uri(queryParameters: {
      'page': '$page',
      if (variantId != null) 'variantId': variantId,
      if (date != null) 'date': date,
      if (direction != null) 'direction': direction
    }).query;
    return await _request('/schedules?$query', admin: admin) as Json;
  }

  @override
  Future<bool> adminAccess() async =>
      (await _request('/access'))['transportAdmin'] == true;
  @override
  Future<Json> resources(String kind, {int page = 1}) async =>
      await _request('/resources/${Uri.encodeComponent(kind)}?page=$page',
          admin: true) as Json;
  @override
  Future<Json> saveResource(String kind, Json input, {String? id}) async =>
      await _request(
          '/resources/${Uri.encodeComponent(kind)}${id == null ? '' : '/${Uri.encodeComponent(id)}'}',
          admin: true,
          method: id == null ? 'POST' : 'PUT',
          body: input) as Json;
  @override
  Future<Json> saveSchedule(Json input, {String? id}) async => await _request(
      '/schedules${id == null ? '' : '/${Uri.encodeComponent(id)}'}',
      admin: true,
      method: id == null ? 'POST' : 'PUT',
      body: input) as Json;
  @override
  Future<Json> saveStop(String id, Json input) async =>
      await _request('/stops/${Uri.encodeComponent(id)}',
          admin: true, method: 'PUT', body: input) as Json;
  @override
  Future<Json> reorder(String id, List<String> ids) async =>
      await _request('/patterns/${Uri.encodeComponent(id)}/order',
          admin: true, method: 'PUT', body: {'stopIds': ids}) as Json;
  @override
  Future<Json> verifyVariant(String id, String reference) async =>
      await _request('/variants/${Uri.encodeComponent(id)}/verification',
          admin: true, method: 'PUT', body: {'reference': reference}) as Json;
  @override
  Future<Json> removeException(String date) async =>
      await _request('/exceptions/${Uri.encodeComponent(date)}',
          admin: true, method: 'DELETE') as Json;
}
