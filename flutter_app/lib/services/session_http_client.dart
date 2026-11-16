import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'auth_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// The application's single native HTTP/cookie boundary. Auth and transport use
/// this exact instance. No browser cookies, Bearer headers or cached roles.
class SessionHttpClient {
  SessionHttpClient({required this.config, required this.cookies, Dio? dio})
    : _dio = dio ?? Dio() {
    _dio.options
      ..followRedirects = false
      ..validateStatus = ((s) => s != null && s >= 200 && s < 600)
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 20);
  }
  final AuthConfig config;
  final CookieJar cookies;
  final Dio _dio;
  void Function()? onUnauthorized;
  int _generation = 0;
  int get generation => _generation;
  Future<void> _cookieTail = Future<void>.value();

  Future<T> _cookieOperation<T>(Future<T> Function() action) {
    final result = _cookieTail.then((_) => action());
    _cookieTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  /// Invalidates old requests synchronously, before any async storage work.
  void nextGeneration() {
    _generation++;
  }

  Future<void> clearCookies() => _cookieOperation(cookies.deleteAll);

  void _checkGeneration(int expected) {
    if (expected != _generation) {
      throw const ApiException('Authentication changed. Please try again.');
    }
  }

  Future<Response<dynamic>> request(
    String path, {
    String method = 'GET',
    Object? data,
    bool protected = false,
    int? generation,
  }) async {
    final expected = generation ?? _generation;
    final uri = config.api.resolve('/api/$path');
    if (uri.origin != config.api.origin ||
        !uri.path.startsWith('/api/') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        path.startsWith('/') ||
        path.contains('://')) {
      throw const ApiException('Invalid API destination.');
    }
    try {
      final cookieHeader = await _cookieOperation(() async {
        _checkGeneration(expected);
        final values = await cookies.loadForRequest(uri);
        return values.map((c) => '${c.name}=${c.value}').join('; ');
      });
      _checkGeneration(expected);
      final response = await _dio.requestUri<dynamic>(
        uri,
        data: data,
        options: Options(
          method: method,
          headers: {
            'Accept': 'application/json',
            'Cache-Control': 'no-store',
            if (cookieHeader.isNotEmpty) HttpHeaders.cookieHeader: cookieHeader,
            if (!['GET', 'HEAD'].contains(method.toUpperCase()))
              'Origin': config.frontend.origin,
          },
        ),
      );
      _checkGeneration(expected);
      // Store only against the actual API origin. Never copy cookies to a 302
      // Location (Google/browser navigation has a separate cookie store).
      await _cookieOperation(() async {
        _checkGeneration(expected);
        final values = response.headers[HttpHeaders.setCookieHeader];
        if (values != null) {
          await cookies.saveFromResponse(
            uri,
            values.map(Cookie.fromSetCookieValue).toList(),
          );
        }
      });
      _checkGeneration(expected);
      if (protected && response.statusCode == 401) {
        nextGeneration();
        onUnauthorized?.call();
        await clearCookies();
      }
      return response;
    } on DioException {
      throw const ApiException(
        'Cannot reach the server. Check your connection and retry.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      // No storage internals, cookies, URL codes or raw response bodies in UI.
      throw const ApiException(
        'Authentication storage is unavailable. Please retry.',
      );
    }
  }

  void close() => _dio.close(force: true);
}
