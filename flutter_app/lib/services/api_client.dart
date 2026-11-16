import '../models/transport_record.dart';
import '../models/auth_session.dart';
import 'session_http_client.dart';
export '../models/auth_session.dart';
export 'session_http_client.dart' show ApiException;

class ApiClient {
  ApiClient({required this.client, required AuthSession? Function() session})
    : _session = session;
  final AuthSession? Function() _session;
  AuthSession? get session => _session();
  final SessionHttpClient client;
  bool hasRole(TransportRole role) => session?.role.allows(role) ?? false;
  void requireRole(TransportRole role) {
    if (!hasRole(role)) {
      throw const ApiException(
        'You do not have permission to open this feature.',
        403,
      );
    }
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
  }) async {
    if (session == null) {
      throw const ApiException('Sign in through the main application.', 401);
    }
    final response = await client.request(
      path,
      method: method,
      data: body,
      protected: true,
    );
    final decoded = response.data;
    final status = response.statusCode!;
    if (status < 200 || status >= 300) {
      throw ApiException(
        decoded is Map && decoded['error'] is String
            ? decoded['error'] as String
            : 'Request failed ($status).',
        status,
      );
    }
    if (decoded is! Map && decoded is! List) {
      throw const ApiException('Unexpected API response.');
    }
    return decoded;
  }
}
