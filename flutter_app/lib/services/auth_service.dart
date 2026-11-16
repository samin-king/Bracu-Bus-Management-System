import 'package:dio/dio.dart';
import '../models/auth_session.dart';
import 'auth_failure.dart';
import 'oauth_browser.dart';
import 'session_http_client.dart';

class AuthService {
  AuthService(this.http, {OAuthBrowser? browser})
    : browser = browser ?? AndroidOAuthBrowser();
  final SessionHttpClient http;
  final OAuthBrowser browser;

  Never _fail(Response<dynamic> response) {
    final body = response.data;
    throw AuthFailure(
      response.statusCode == 429
          ? 'too_many_attempts'
          : body is Map && body['error'] is String
          ? body['error'] as String
          : 'unavailable',
    );
  }

  Future<AuthSession?> currentUser() async {
    final response = await http.request('auth/me', protected: true);
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) _fail(response);
    return _identity(response.data);
  }

  AuthSession _identity(dynamic body) {
    try {
      return AuthSession.fromJson(body);
    } on FormatException {
      throw const AuthFailure('unsupported_role');
    }
  }

  Future<void> requestEmail(String email) async {
    // Eligibility and account lookup remain on the existing backend.
    final response = await http.request(
      'auth/email',
      method: 'POST',
      data: {'email': email},
    );
    if (response.statusCode != 202) _fail(response);
  }

  Future<AuthSession> verifyEmail(String token) async {
    http.nextGeneration();
    final generation = http.generation;
    final response = await http.request(
      'auth/email/verify',
      method: 'POST',
      data: {'token': token},
      generation: generation,
    );
    if (response.statusCode != 200) _fail(response);
    _identity(
      response.data,
    ); // Reject malformed verification responses as well.
    final user = await currentUser();
    if (user == null) throw const AuthFailure('unauthenticated');
    return user;
  }

  Uri _redirect(Response<dynamic> response, Uri base) {
    if (response.statusCode != 302) _fail(response);
    final location = response.headers.value('location');
    if (location == null) throw const AuthFailure('invalid_callback');
    try {
      return base.resolve(location);
    } on FormatException {
      throw const AuthFailure('invalid_callback');
    }
  }

  Future<AuthSession> googleLogin() async {
    final callbackUrl = http.config.callback;
    if (callbackUrl == null) throw const AuthFailure('configuration');
    http.nextGeneration();
    final generation = http.generation;
    final start = http.config.api.resolve('/api/auth/google');
    final authorization = _redirect(
      await http.request('auth/google', generation: generation),
      start,
    );
    final state = authorization.queryParameters['state'];
    if (authorization.scheme != 'https' ||
        authorization.host != 'accounts.google.com' ||
        authorization.port != 443 ||
        authorization.userInfo.isNotEmpty ||
        authorization.hasFragment ||
        state == null ||
        state.isEmpty ||
        authorization.queryParameters['redirect_uri'] !=
            callbackUrl.toString()) {
      throw const AuthFailure('configuration');
    }
    final callback = await browser.authenticate(authorization, callbackUrl);
    final params = callback.queryParametersAll;
    final code = params['code'];
    final error = params['error'];
    if (callback.scheme != 'https' ||
        callback.origin != callbackUrl.origin ||
        callback.path != callbackUrl.path ||
        callback.userInfo.isNotEmpty ||
        callback.hasFragment ||
        params['state']?.length != 1 ||
        params['state']!.single != state ||
        (code == null) == (error == null) ||
        (code != null &&
            (code.length != 1 ||
                code.single.isEmpty ||
                code.single.length > 4096)) ||
        (error != null && (error.length != 1 || error.single.isEmpty))) {
      throw const AuthFailure('invalid_callback');
    }
    final destination = _redirect(
      await http.request(
        'auth/google/callback?${callback.query}',
        generation: generation,
      ),
      callback,
    );
    if (destination.origin != http.config.frontend.origin ||
        destination.userInfo.isNotEmpty ||
        destination.hasFragment) {
      throw const AuthFailure('invalid_callback');
    }
    if (destination.path == '/login') {
      throw AuthFailure(
        destination.queryParameters['error'] ?? 'google_failed',
      );
    }
    if (destination.path != '/') throw const AuthFailure('invalid_callback');
    final user = await currentUser();
    if (user == null) throw const AuthFailure('unauthenticated');
    return user;
  }

  Future<void> logout() async {
    // Any in-flight refresh or transport response belongs to an older epoch.
    http.nextGeneration();
    final response = await http.request('auth/logout', method: 'POST');
    if (response.statusCode != 204) _fail(response);
    await http.clearCookies();
  }
}
