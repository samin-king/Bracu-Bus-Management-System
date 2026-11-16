import 'dart:convert';
import 'package:bracu_transport/auth/authenticated_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('401 shows real login option and exposes no privileged routes', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response('{"error":"unauthenticated"}', 401),
    );
    await tester.pumpWidget(
      AuthenticatedTransportHost(
        baseUrl: 'https://api.test/api',
        client: client,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Buses'), findsNothing);
  });
  for (final role in ['student', 'authority', 'driver']) {
    testWidgets(
      'server session supplies $role and logout disposes its routes',
      (tester) async {
        var signedIn = true;
        final requests = <String>[];
        final client = MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/logout')) {
            signedIn = false;
            return http.Response('', 204);
          }
          return signedIn
              ? http.Response(jsonEncode({'id': 42, 'role': role}), 200)
              : http.Response('{"error":"unauthenticated"}', 401);
        });
        await tester.pumpWidget(
          AuthenticatedTransportHost(
            baseUrl: 'https://api.test/api',
            client: client,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Buses'),
          role == 'authority' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Driver Dashboard'),
          role == 'driver' ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(find.text('Sign in with Google'), findsOneWidget);
        expect(requests, contains('POST /api/auth/logout'));
        expect(find.text('Buses'), findsNothing);
      },
    );
  }
  testWidgets('invalid server role fails closed', (tester) async {
    final client = MockClient(
      (_) async => http.Response('{"id":1,"role":"admin"}', 200),
    );
    await tester.pumpWidget(
      AuthenticatedTransportHost(
        baseUrl: 'https://api.test/api',
        client: client,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Cannot verify your session'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
  testWidgets('page reconstruction restores the same verified server session', (
    tester,
  ) async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        '{"id":42,"name":"Existing Authority","role":"authority"}',
        200,
      );
    });
    for (var refresh = 0; refresh < 2; refresh++) {
      await tester.pumpWidget(
        AuthenticatedTransportHost(
          baseUrl: 'https://api.test/api',
          client: client,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buses'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
    expect(paths, ['/api/auth/me', '/api/auth/me']);
  });
}
