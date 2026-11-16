import 'dart:async';
import 'dart:io';
import 'package:bracu_transport/providers/auth_provider.dart';
import 'package:bracu_transport/services/api_client.dart';
import 'package:bracu_transport/services/auth_config.dart';
import 'package:bracu_transport/services/auth_failure.dart';
import 'package:bracu_transport/services/auth_service.dart';
import 'package:bracu_transport/services/oauth_browser.dart';
import 'package:bracu_transport/services/secure_cookie_storage.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/session_fixture.dart';

class CancelledBrowser implements OAuthBrowser {
  @override
  Future<Uri> authenticate(Uri authorizationUrl, Uri callback) async =>
      throw const AuthFailure('cancelled');
}

class FakeBrowser implements OAuthBrowser {
  FakeBrowser([this.transform]);
  final Uri Function(Uri)? transform;
  @override
  Future<Uri> authenticate(Uri url, Uri callback) async {
    final result = callback.replace(
      queryParameters: {
        'code': 'provider-code',
        'state': url.queryParameters['state']!,
      },
    );
    return transform?.call(result) ?? result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final query in [
    'state=real',
    'state=real&code=',
    'state=real&error=',
    'state=real&code=one&code=two',
    'state=real&error=one&error=two',
    'state=real&code=code&error=access_denied',
    'state=real&state=other&code=code',
  ]) {
    test('Google rejects ambiguous or incomplete callback: $query', () async {
      final f = SessionFixture();
      f.handler = (_) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            Uri.https('accounts.google.com', '/oauth', {
              'state': 'real',
              'redirect_uri': testConfig.callback.toString(),
            }).toString(),
          ],
        },
      );
      await expectLater(
        AuthService(
          f.http,
          browser: FakeBrowser((u) => u.replace(query: query)),
        ).googleLogin(),
        throwsA(
          isA<AuthFailure>().having((e) => e.code, 'code', 'invalid_callback'),
        ),
      );
      expect(f.adapter.requests.length, 1);
    });
  }

  test(
    'Google cancellation leaves login retryable without a callback request',
    () async {
      final f = SessionFixture();
      f.handler = (_) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            Uri.https('accounts.google.com', '/oauth', {
              'state': 'real',
              'redirect_uri': testConfig.callback.toString(),
            }).toString(),
          ],
        },
      );
      final auth = AuthProvider(
        AuthService(f.http, browser: CancelledBrowser()),
      );
      addTearDown(auth.dispose);
      await auth.googleLogin();
      expect(auth.authenticated, isFalse);
      expect(auth.busy, isFalse);
      expect(auth.error, contains('cancelled'));
      expect(f.adapter.requests.length, 1);
    },
  );

  test(
    'valid Google denial is handled by the existing backend callback',
    () async {
      final f = SessionFixture();
      f.handler = (r) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            r.uri.path.endsWith('/google')
                ? Uri.https('accounts.google.com', '/oauth', {
                    'state': 'real',
                    'redirect_uri': testConfig.callback.toString(),
                  }).toString()
                : '${testConfig.frontend.origin}/login?error=google_denied',
          ],
        },
      );
      final auth = AuthProvider(
        AuthService(
          f.http,
          browser: FakeBrowser(
            (u) => u.replace(
              queryParameters: {'state': 'real', 'error': 'access_denied'},
            ),
          ),
        ),
      );
      addTearDown(auth.dispose);
      await auth.googleLogin();
      expect(auth.authenticated, isFalse);
      expect(auth.error, contains('cancelled'));
      expect(f.adapter.requests.length, 2);
    },
  );

  test(
    'invalid cold-start link error survives anonymous session restoration',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      auth.receiveEmailLink(
        Uri.parse('${testConfig.frontend.origin}/login#email_token=broken'),
      );
      await auth.refresh();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.error, contains('Request a new link'));
    },
  );

  test(
    'network failure is actionable and session restoration can retry',
    () async {
      final f = SessionFixture();
      f.handler = (r) => throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      );
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      await auth.refresh();
      expect(auth.status, AuthStatus.unavailable);
      expect(auth.error, contains('Check your connection'));
      expect(auth.session, isNull);
      f.handler = null;
      await auth.refresh();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.error, isNull);
    },
  );

  test(
    'malformed incoming email link clears old token and explains recovery',
    () {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      auth.receiveEmailLink(
        Uri.parse(
          '${testConfig.frontend.origin}/login#email_token=${'a' * 43}',
        ),
      );
      expect(auth.linkToken, isNotNull);
      for (final suffix in [
        '#email_token=broken',
        '#email_token=${'a' * 43}&email_token=${'b' * 43}',
        '?unexpected=1#email_token=${'a' * 43}',
      ]) {
        auth.receiveEmailLink(
          Uri.parse('${testConfig.frontend.origin}/login$suffix'),
        );
        expect(auth.linkToken, isNull);
        expect(auth.error, contains('Request a new link'));
      }
      expect(f.adapter.requests, isEmpty);
    },
  );
  test(
    'unsupported link schemes are rejected without throwing or signing in',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      final link = 'ftp://frontend.example.test/login#email_token=${'a' * 43}';
      auth.receiveEmailLink(Uri.parse(link));
      expect(auth.linkToken, isNull);
      expect(f.adapter.requests, isEmpty);
      await auth.verifyEmail(link);
      expect(auth.authenticated, isFalse);
      expect(auth.error, contains('invalid or expired'));
    },
  );

  test(
    'cold-start email link survives the pending anonymous session check',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      final response = Completer<ResponseBody>();
      final started = Completer<void>();
      f.handler = (_) {
        started.complete();
        return response.future;
      };
      final refresh = auth.refresh();
      await started.future;
      final token = 'a' * 43;
      auth.receiveEmailLink(
        Uri.parse('${testConfig.frontend.origin}/login#email_token=$token'),
      );
      response.complete(jsonResponse(401, {'error': 'unauthenticated'}));
      await refresh;
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.linkToken, token);
      expect(f.adapter.requests.length, 1);
    },
  );
  test(
    'email APIs share cookies with transport and send valid Origin',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      await auth.requestEmail('test.user@g.bracu.ac.bd');
      expect(auth.authenticated, isFalse);
      await auth.verifyEmail('valid-token');
      expect(auth.authenticated, isTrue);
      final api = ApiClient(client: f.http, session: () => auth.session);
      await api.request('buses');
      await api.request('trips/1/start', method: 'POST');
      final requests = f.adapter.requests;
      expect(requests.map((r) => r.uri.path), [
        '/api/auth/email',
        '/api/auth/email/verify',
        '/api/auth/me',
        '/api/buses',
        '/api/trips/1/start',
      ]);
      expect(requests[0].data, {'email': 'test.user@g.bracu.ac.bd'});
      for (final r in requests) {
        expect(r.headers.containsKey('Authorization'), isFalse);
        if (r.method != 'GET') {
          expect(r.headers['Origin'], testConfig.frontend.origin);
        }
      }
      expect(
        requests[3].headers[HttpHeaders.cookieHeader],
        contains('verified'),
      );
      expect(
        requests[4].headers[HttpHeaders.cookieHeader],
        contains('verified'),
      );
    },
  );

  test('invalid email verification cannot establish authentication', () async {
    final f = SessionFixture();
    final auth = AuthProvider(AuthService(f.http));
    addTearDown(auth.dispose);
    await auth.verifyEmail('invalid-token');
    expect(auth.authenticated, isFalse);
    expect(auth.error, contains('invalid or expired'));
  });

  for (final role in TransportRole.values) {
    test('preserves ${role.name} from /me', () async {
      final f = SessionFixture()..role = role.name;
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      await auth.verifyEmail('valid-token');
      expect(auth.session!.role, role);
      expect(
        auth.session!.role.allows(TransportRole.authority),
        role == TransportRole.authority || role == TransportRole.admin,
      );
    });
  }

  test('unknown server role fails closed', () async {
    final f = SessionFixture()..role = 'superuser';
    final auth = AuthProvider(AuthService(f.http));
    addTearDown(auth.dispose);
    await auth.verifyEmail('valid-token');
    expect(auth.authenticated, isFalse);
    expect(auth.session, isNull);
  });

  test(
    'protected 401 invalidates shared identity and persisted cookies',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      await auth.verifyEmail('valid-token');
      f.handler = (_) => jsonResponse(401, {'error': 'unauthenticated'});
      final api = ApiClient(client: f.http, session: () => auth.session);
      await expectLater(
        api.request('buses'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(auth.authenticated, isFalse);
      expect(await f.http.cookies.loadForRequest(testConfig.api), isEmpty);
    },
  );

  test('403 preserves authenticated session and server denial', () async {
    final f = SessionFixture();
    final auth = AuthProvider(AuthService(f.http));
    addTearDown(auth.dispose);
    await auth.verifyEmail('valid-token');
    f.handler = (_) => jsonResponse(403, {'error': 'forbidden'});
    await expectLater(
      ApiClient(client: f.http, session: () => auth.session).request('buses'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
    expect(auth.authenticated, isTrue);
    expect(await f.http.cookies.loadForRequest(testConfig.api), isNotEmpty);
  });

  test(
    'logout executes during refresh; late /me cannot restore identity OR cookie',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      await auth.verifyEmail('valid-token');
      final gate = Completer<ResponseBody>();
      final started = Completer<void>();
      f.handler = (r) {
        if (r.uri.path.endsWith('/me')) {
          started.complete();
          return gate.future;
        }
        return jsonResponse(204);
      };
      final refresh = auth.refresh();
      await started.future;
      await auth.logout();
      expect(auth.authenticated, isFalse);
      gate.complete(
        jsonResponse(
          200,
          identity(),
          '__Host-bracu.sid=stale-restored; Path=/; Secure; HttpOnly; Max-Age=3600',
        ),
      );
      await refresh;
      expect(auth.session, isNull);
      expect(await f.http.cookies.loadForRequest(testConfig.api), isEmpty);
      expect(
        f.adapter.requests.where((r) => r.uri.path.endsWith('/logout')).length,
        1,
      );
    },
  );

  test('logout queued behind verification is not dropped', () async {
    final f = SessionFixture();
    final auth = AuthProvider(AuthService(f.http));
    addTearDown(auth.dispose);
    final signIn = auth.verifyEmail('valid-token');
    final signOut = auth.logout();
    await Future.wait([signIn, signOut]);
    expect(auth.authenticated, isFalse);
    expect(f.adapter.requests.last.uri.path, '/api/auth/logout');
    expect(await f.http.cookies.loadForRequest(testConfig.api), isEmpty);
  });

  test(
    'failed logout preserves retryable session and retry clears it',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      await auth.verifyEmail('valid-token');
      f.logoutStatus = 503;
      await auth.logout();
      expect(auth.authenticated, isTrue);
      expect(auth.error, isNotNull);
      expect(await f.http.cookies.loadForRequest(testConfig.api), isNotEmpty);
      f.logoutStatus = 204;
      await auth.logout();
      expect(auth.session, isNull);
      expect(await f.http.cookies.loadForRequest(testConfig.api), isEmpty);
    },
  );

  test(
    'secure persistence restores session across clients; scoped logout clears it',
    () async {
      FlutterSecureStorage.setMockInitialValues({'unrelated': 'keep'});
      PersistCookieJar jar() => PersistCookieJar(
        persistSession: false,
        storage: SecureCookieStorage(
          const FlutterSecureStorage(),
          origin: testConfig.api.origin,
        ),
      );
      final first = SessionFixture(jar: jar());
      await AuthService(first.http).verifyEmail('valid-token');
      final second = SessionFixture(jar: jar())..signedIn = true;
      final auth = AuthProvider(AuthService(second.http));
      addTearDown(auth.dispose);
      await auth.refresh();
      expect(auth.authenticated, isTrue);
      expect(
        second.adapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('verified'),
      );
      await auth.logout();
      expect(await jar().loadForRequest(testConfig.api), isEmpty);
      expect(await const FlutterSecureStorage().read(key: 'unrelated'), 'keep');
    },
  );

  test('expired cookies are not restored', () async {
    final jar = CookieJar();
    await jar.saveFromResponse(testConfig.api, [
      Cookie('bracu.sid', 'expired')
        ..expires = DateTime.now().subtract(const Duration(hours: 1)),
    ]);
    final f = SessionFixture(jar: jar);
    await AuthService(f.http).currentUser();
    expect(f.adapter.requests.single.headers[HttpHeaders.cookieHeader], isNull);
  });

  test('untrusted destinations cannot receive session cookies', () async {
    final f = SessionFixture();
    for (final path in ['https://evil.test/api', '//evil.test', '../private']) {
      await expectLater(f.http.request(path), throwsA(isA<ApiException>()));
    }
    expect(f.adapter.requests, isEmpty);
  });

  test(
    'Google reuses backend OAuth callback and native cookie rotation',
    () async {
      final f = SessionFixture();
      f.handler = (r) {
        if (r.uri.path.endsWith('/google')) {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': [
                Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
                  'state': 'server-state',
                  'redirect_uri': testConfig.callback.toString(),
                }).toString(),
              ],
              'set-cookie': [
                '__Host-bracu.sid=oauth; Path=/; HttpOnly; Secure; Max-Age=3600',
              ],
            },
          );
        }
        if (r.uri.path.endsWith('/callback')) {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['${testConfig.frontend.origin}/'],
              'set-cookie': [
                '__Host-bracu.sid=authenticated; Path=/; HttpOnly; Secure; Max-Age=3600',
              ],
            },
          );
        }
        return jsonResponse(200, identity());
      };
      expect(
        (await AuthService(f.http, browser: FakeBrowser()).googleLogin()).role,
        TransportRole.student,
      );
      expect(
        f.adapter.requests[1].headers[HttpHeaders.cookieHeader],
        contains('oauth'),
      );
      expect(
        f.adapter.requests[2].headers[HttpHeaders.cookieHeader],
        contains('authenticated'),
      );
      expect(
        await f.http.cookies.loadForRequest(
          Uri.parse('https://accounts.google.com'),
        ),
        isEmpty,
      );
    },
  );

  for (final field in ['state', 'host', 'path']) {
    test('Google rejects forged $field before callback API', () async {
      final f = SessionFixture();
      f.handler = (_) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            Uri.https('accounts.google.com', '/oauth', {
              'state': 'real',
              'redirect_uri': testConfig.callback.toString(),
            }).toString(),
          ],
        },
      );
      final browser = FakeBrowser(
        (u) => switch (field) {
          'host' => u.replace(host: 'evil.test'),
          'path' => u.replace(path: '/fake'),
          _ => u.replace(queryParameters: {'state': 'forged', 'code': 'code'}),
        },
      );
      await expectLater(
        AuthService(f.http, browser: browser).googleLogin(),
        throwsA(isA<AuthFailure>()),
      );
      expect(f.adapter.requests.length, 1);
    });
  }

  test(
    'email links require the configured frontend and are never auto-verified',
    () async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      addTearDown(auth.dispose);
      final token = 'a' * 43;
      auth.receiveEmailLink(
        Uri.parse('https://evil.test/login#email_token=$token'),
      );
      expect(auth.linkToken, isNull);
      auth.receiveEmailLink(
        Uri.parse('${testConfig.frontend.origin}/login#email_token=$token'),
      );
      expect(auth.linkToken, token);
      expect(f.adapter.requests, isEmpty);
    },
  );

  test(
    'release configuration requires HTTPS and optional Google requires matching callback',
    () {
      expect(
        () => AuthConfig(
          apiOrigin: 'http://10.0.2.2:3000',
          frontendOrigin: 'http://localhost:5173',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(
        () => AuthConfig(
          apiOrigin: testConfig.api.origin,
          frontendOrigin: testConfig.frontend.origin,
          googleCallbackUrl: 'https://evil.test/api/auth/google/callback',
        ),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
}
