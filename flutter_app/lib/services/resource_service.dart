import '../models/transport_record.dart';
import 'api_client.dart';

class ResourceService<T extends TransportRecord> {
  ResourceService(this.api, this.path, this.parse);
  final ApiClient api;
  final String path;
  final T Function(Json) parse;
  Future<List<T>> list() async {
    api.requireRole(TransportRole.authority);
    return decodeList(await api.request(path));
  }

  List<T> decodeList(dynamic value) {
    if (value is! List) throw const ApiException('Unexpected list response.');
    try {
      return value.map(decode).toList();
    } catch (_) {
      throw const ApiException('Unexpected record response.');
    }
  }

  T decode(dynamic value) {
    try {
      final record = parse(Json.from(value as Map));
      if (record.id < 1 || record.title.isEmpty || record.details.isEmpty) {
        throw const FormatException('Invalid record');
      }
      return record;
    } catch (_) {
      throw const ApiException('Unexpected record response.');
    }
  }

  Future<T> get(int id) async {
    api.requireRole(TransportRole.authority);
    return decode(await api.request('$path/$id'));
  }

  Future<T> save(Json body, {int? id}) async {
    api.requireRole(TransportRole.authority);
    return decode(
      await api.request(
        id == null ? path : '$path/$id',
        method: id == null ? 'POST' : 'PUT',
        body: body,
      ),
    );
  }
}
