import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:bracu_transport/services/auth_config.dart';
import 'package:bracu_transport/services/session_http_client.dart';

Map<String, dynamic> identity([String role = 'student', String id = '42']) => {
  'id': id,
  'name': 'Test User',
  'email': 'test.user@g.bracu.ac.bd',
  'role': role,
  if (role == 'driver') 'driver_id': 1,
};

ResponseBody jsonResponse(int status, [Object? body, String? cookie]) =>
    ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (cookie != null) HttpHeaders.setCookieHeader: [cookie],
      },
    );

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.handle);
  final FutureOr<ResponseBody> Function(RequestOptions request) handle;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}

final testConfig = AuthConfig(
  apiOrigin: 'https://api.example.test',
  frontendOrigin: 'https://frontend.example.test',
  googleCallbackUrl: 'https://api.example.test/api/auth/google/callback',
);

class SessionFixture {
  SessionFixture({this.jar, this.config}) {
    adapter = FixtureAdapter(
      (request) => handler?.call(request) ?? _handle(request),
    );
    http = SessionHttpClient(
      config: config ?? testConfig,
      cookies: jar ?? CookieJar(),
      dio: Dio()..httpClientAdapter = adapter,
    );
  }
  final CookieJar? jar;
  final AuthConfig? config;
  late final FixtureAdapter adapter;
  late final SessionHttpClient http;
  FutureOr<ResponseBody> Function(RequestOptions)? handler;
  String role = 'student';
  bool signedIn = false;
  int logoutStatus = 204;
  Completer<void>? refreshGate;
  int get checks =>
      adapter.requests.where((r) => r.uri.path.endsWith('/me')).length;
  ResponseBody _handle(RequestOptions r) {
    final path = r.uri.path;
    if (path == '/api/drivers/me') {
      return jsonResponse(200, {
        'id': 1,
        'name': 'Test Driver',
        'license_number': 'TEST-001',
        'status': 'ACTIVE',
      });
    }
    if (path.endsWith('/email')) {
      return jsonResponse(202, {'message': 'Check your email.'});
    }
    if (path.endsWith('/email/verify')) {
      if ((r.data as Map)['token'] != 'valid-token') {
        return jsonResponse(401, {'error': 'invalid_email_token'});
      }
      signedIn = true;
      return jsonResponse(
        200,
        identity(role),
        '__Host-bracu.sid=verified; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=3600',
      );
    }
    if (path.endsWith('/me')) {
      return jsonResponse(
        signedIn ? 200 : 401,
        signedIn ? identity(role) : {'error': 'unauthenticated'},
      );
    }
    if (path.endsWith('/logout')) {
      if (logoutStatus == 204) signedIn = false;
      return jsonResponse(logoutStatus, {'error': 'server_error'});
    }
    return jsonResponse(200, []);
  }
}
