import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/transport_record.dart';

enum TransportRole { authority, driver, student }

/// Construct from the host application's verified login; never from a role picker.
class TransportSession {
  const TransportSession({required this.role, required this.headers});
  final TransportRole role;

  /// Supplies the current verified token/cookie on every request, including refresh.
  final Future<Map<String, String>> Function() headers;
}

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.session,
    required this.client,
  });
  final String baseUrl;
  final TransportSession? session;
  final http.Client client;
  void requireRole(TransportRole role) {
    if (session?.role != role) {
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
    try {
      final headers = await session!.headers();
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$path',
      );
      final req = http.Request(method, uri)..headers.addAll(headers);
      req.headers['Accept'] = 'application/json';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(await client.send(req))
          .timeout(const Duration(seconds: 20));
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          'Unexpected API response (${response.statusCode}).',
          response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          decoded is Map && decoded['error'] is String
              ? decoded['error'] as String
              : 'Request failed (${response.statusCode}).',
          response.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException('Request timed out. Please retry.');
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the server. Check your connection and retry.',
      );
    }
  }
}
