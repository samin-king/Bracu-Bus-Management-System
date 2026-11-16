import 'dart:convert';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:bracu_transport/services/auth_config.dart';
import 'package:bracu_transport/services/session_http_client.dart';

/// Preserve Member 3's HTTP/UI fixtures while routing every request through the
/// same production Dio/cookie boundary. This adapter exists only in tests.
class HttpFixtureAdapter implements HttpClientAdapter {
  HttpFixtureAdapter(this.client);
  final http.Client client;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final request = http.Request(options.method, options.uri);
    request.headers.addAll(options.headers.map((k, v) => MapEntry(k, '$v')));
    if (options.data != null) {
      request.body = options.data is String
          ? options.data as String
          : jsonEncode(options.data);
    }
    final response = await http.Response.fromStream(await client.send(request));
    return ResponseBody.fromString(
      response.body,
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final entry in response.headers.entries) entry.key: [entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {
    client.close();
  }
}

SessionHttpClient fixtureHttp(http.Client client) {
  final cookies = CookieJar();
  // Seed an opaque fixture session; the real client must attach it.
  cookies.saveFromResponse(Uri.parse('https://example.test'), [
    Cookie('__Host-bracu.sid', 'verified-session')
      ..secure = true
      ..httpOnly = true
      ..path = '/',
  ]);
  return SessionHttpClient(
    config: AuthConfig(
      apiOrigin: 'https://example.test',
      frontendOrigin: 'https://frontend.test',
    ),
    cookies: cookies,
    dio: Dio()..httpClientAdapter = HttpFixtureAdapter(client),
  );
}
