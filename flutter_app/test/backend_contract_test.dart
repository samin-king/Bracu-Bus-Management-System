import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bracu_transport/providers/auth_provider.dart';
import 'package:bracu_transport/services/api_client.dart';
import 'package:bracu_transport/services/auth_config.dart';
import 'package:bracu_transport/services/auth_failure.dart';
import 'package:bracu_transport/services/auth_service.dart';
import 'package:bracu_transport/services/bus_service.dart';
import 'package:bracu_transport/services/driver_service.dart';
import 'package:bracu_transport/services/session_http_client.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final enabled = Platform.environment['BRACU_BACKEND_CONTRACT'] == '1';
  group(
    'real Express/Dio contract',
    () {
      late Process server;
      late Stream<Map<String, dynamic>> events;
      late String origin;
      final clients = <SessionHttpClient>[];
      final controllers = <AuthProvider>[];
      setUpAll(() async {
        server = await Process.start(
          Platform.environment['BRACU_TEST_NODE'] ?? 'node',
          ['tool/contract_server.mjs'],
          workingDirectory: Directory.current.path,
        );
        unawaited(server.stderr.drain<void>());
        events = server.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .map((line) => Map<String, dynamic>.from(jsonDecode(line) as Map))
            .asBroadcastStream();
        final ready = await Future.any([
          events.firstWhere((event) => event['type'] == 'ready'),
          server.exitCode.then<Map<String, dynamic>>(
            (code) => throw StateError('Contract fixture exited: $code'),
          ),
        ]).timeout(const Duration(minutes: 1));
        origin = ready['origin'] as String;
      });
      tearDownAll(() async {
        for (final controller in controllers) {
          controller.dispose();
        }
        for (final client in clients) {
          client.close();
        }
        server.stdin.writeln('stop');
        await server.stdin.flush();
        try {
          await server.exitCode.timeout(const Duration(seconds: 10));
        } on TimeoutException {
          server.kill();
          await server.exitCode;
        }
      });
      SessionHttpClient client([CookieJar? jar]) {
        final result = SessionHttpClient(
          config: AuthConfig(
            apiOrigin: origin,
            frontendOrigin: 'http://localhost:5173',
            allowLocalHttp: true,
          ),
          cookies: jar ?? CookieJar(),
        );
        clients.add(result);
        return result;
      }

      Future<AuthProvider> login(String role) async {
        final auth = AuthProvider(AuthService(client()));
        controllers.add(auth);
        final email = '$role.fixture@g.bracu.ac.bd';
        final message = events.firstWhere(
          (e) => e['type'] == 'email' && e['email'] == email,
        );
        await auth.requestEmail(email);
        final delivered = await message.timeout(const Duration(seconds: 10));
        await auth.verifyEmail(delivered['token'] as String);
        expect(auth.error, isNull);
        expect(auth.session!.role.name, role);
        return auth;
      }

      test(
        'Student email login establishes actual session; logout revokes cookie replay',
        () async {
          final auth = await login('student');
          final cookies = await auth.service.http.cookies.loadForRequest(
            Uri.parse(origin),
          );
          expect(cookies.single.name, 'bracu.sid');
          final replay = Cookie(cookies.single.name, cookies.single.value)
            ..path = '/';
          expect(
            await ApiClient(
              client: auth.service.http,
              session: () => auth.session,
            ).request('trips'),
            isA<List>(),
          );
          expect(
            (await auth.service.http.request(
              'buses',
              method: 'POST',
              protected: true,
              data: {'bus_number': 'FORGED', 'capacity': 37},
            )).statusCode,
            403,
          );
          expect(auth.authenticated, isTrue);
          await auth.logout();
          expect(auth.session, isNull);
          final captured = CookieJar();
          await captured.saveFromResponse(Uri.parse(origin), [replay]);
          expect(await AuthService(client(captured)).currentUser(), isNull);
        },
      );
      test(
        'actual email token is one-use and malformed tokens cannot log in',
        () async {
          final http = client();
          final service = AuthService(http);
          final message = events.firstWhere(
            (e) =>
                e['type'] == 'email' &&
                e['email'] == 'student.fixture@g.bracu.ac.bd',
          );
          await service.requestEmail('student.fixture@g.bracu.ac.bd');
          final delivered = await message.timeout(const Duration(seconds: 10));
          final token = delivered['token'] as String;
          expect((await service.verifyEmail(token)).role.name, 'student');
          await service.logout();
          await expectLater(
            service.verifyEmail(token),
            throwsA(
              isA<AuthFailure>().having(
                (e) => e.code,
                'code',
                'invalid_email_token',
              ),
            ),
          );
          await expectLater(
            service.verifyEmail('expired-or-invalid'),
            throwsA(
              isA<AuthFailure>().having(
                (e) => e.code,
                'code',
                'invalid_email_token',
              ),
            ),
          );
          expect(await service.currentUser(), isNull);
        },
      );
      for (final role in ['authority', 'admin']) {
        test(
          '$role uses cookie and Origin for actual management mutation',
          () async {
            final auth = await login(role);
            final api = ApiClient(
              client: auth.service.http,
              session: () => auth.session,
            );
            final created = await BusService(api).save({
              'bus_number': 'CONTRACT-${role.toUpperCase()}',
              'capacity': 28,
              'status': 'ACTIVE',
            });
            expect(created.capacity, 28);
            expect(
              (await BusService(api).list()).any((b) => b.id == created.id),
              isTrue,
            );
            await auth.logout();
          },
        );
      }
      test(
        'Driver uses server-linked identity for assigned trips and start/stop',
        () async {
          final auth = await login('driver');
          final driver = DriverService(
            ApiClient(client: auth.service.http, session: () => auth.session),
          );
          expect((await driver.me()).title, 'Fixture Driver');
          final trip = (await driver.assignedTrips()).single;
          expect((await driver.transition(trip.id, 'start')).status, 'ACTIVE');
          expect(
            (await driver.transition(trip.id, 'stop')).status,
            'COMPLETED',
          );
          await auth.logout();
        },
      );
      test(
        'actual protected Express 401 invalidates controller and local cookie',
        () async {
          final auth = await login('student');
          expect(
            (await auth.service.http.request(
              'auth/logout',
              method: 'POST',
            )).statusCode,
            204,
          );
          await auth.service.http.request('trips', protected: true);
          expect(auth.session, isNull);
          expect(auth.status, AuthStatus.signedOut);
          expect(
            await auth.service.http.cookies.loadForRequest(Uri.parse(origin)),
            isEmpty,
          );
        },
      );
    },
    skip: enabled
        ? false
        : 'Set BRACU_BACKEND_CONTRACT=1 after npm ci; ephemeral PostgreSQL only.',
  );
}
