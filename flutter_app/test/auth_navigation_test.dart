import 'package:bracu_transport/app.dart';
import 'package:bracu_transport/providers/auth_provider.dart';
import 'package:bracu_transport/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/session_fixture.dart';

void main() {
  for (final role in ['student', 'driver', 'authority', 'admin']) {
    testWidgets(
      'email login routes $role through the single application router',
      (tester) async {
        final f = SessionFixture()..role = role;
        final auth = AuthProvider(AuthService(f.http));
        await tester.pumpWidget(TransportApp(auth: auth));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('email')),
          'test.user@g.bracu.ac.bd',
        );
        await tester.ensureVisible(find.byKey(const Key('request-email')));
        await tester.tap(find.byKey(const Key('request-email')));
        await tester.pumpAndSettle();
        expect(
          find.text('Check your email for a sign-in link.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('email-token')),
          'valid-token',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('verify-email')));
        await tester.tap(find.byKey(const Key('verify-email')));
        await tester.pumpAndSettle();
        expect(auth.session!.role.name, role);
        expect(find.byType(MaterialApp), findsOneWidget);
        if (role == 'authority' || role == 'admin') {
          expect(find.text('Buses'), findsOneWidget);
          expect(find.text('Driver Assignment'), findsOneWidget);
        } else if (role == 'driver') {
          expect(find.text('Driver Dashboard'), findsOneWidget);
          expect(find.text('Assigned Trips'), findsOneWidget);
          expect(find.text('Buses'), findsNothing);
        } else {
          expect(
            find.textContaining(
              'Student transport features will be integrated next',
            ),
            findsOneWidget,
          );
          expect(find.text('Buses'), findsNothing);
        }
        await tester.tap(find.byKey(const Key('logout')));
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('You have been signed out.'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Transport Management'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
      },
    );
  }

  testWidgets(
    'requested paths cannot grant anonymous or Student authority access',
    (tester) async {
      final f = SessionFixture();
      final auth = AuthProvider(AuthService(f.http));
      await tester.pumpWidget(TransportApp(auth: auth));
      await tester.pumpAndSettle();
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
              as AppRouter;
      await router.setNewRoutePath(Uri(path: '/authority/buses'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      await tester.runAsync(() => auth.verifyEmail('valid-token'));
      await router.setNewRoutePath(Uri(path: '/admin'));
      await tester.pumpAndSettle();
      expect(find.text('Buses'), findsNothing);
      expect(router.currentConfiguration.path, '/student');
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets(
    'background refresh preserves pushed screens; logout removes entire stack',
    (tester) async {
      final f = SessionFixture()
        ..role = 'authority'
        ..signedIn = true;
      final auth = AuthProvider(AuthService(f.http));
      await tester.pumpWidget(TransportApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buses'));
      await tester.pumpAndSettle();
      expect(find.text('No buses found.'), findsOneWidget);
      await tester.runAsync(auth.refresh);
      await tester.pumpAndSettle();
      expect(find.text('No buses found.'), findsOneWidget);
      await tester.runAsync(auth.logout);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('No buses found.'), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets('401 while viewing transport returns to Login and clears stack', (
    tester,
  ) async {
    final f = SessionFixture()
      ..role = 'authority'
      ..signedIn = true;
    final auth = AuthProvider(AuthService(f.http));
    await tester.pumpWidget(TransportApp(auth: auth));
    await tester.pumpAndSettle();
    f.handler = (_) => jsonResponse(401, {'error': 'unauthenticated'});
    await tester.tap(find.text('Buses'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Transport Management'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  testWidgets('email App Link waits for confirmation and sanitizes route', (
    tester,
  ) async {
    final f = SessionFixture();
    final auth = AuthProvider(AuthService(f.http));
    await tester.pumpWidget(TransportApp(auth: auth));
    await tester.pumpAndSettle();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
            as AppRouter;
    final requests = f.adapter.requests.length;
    await router.setNewRoutePath(
      Uri.parse('${testConfig.frontend.origin}/login#email_token=${'a' * 43}'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('verify-link')), findsOneWidget);
    expect(f.adapter.requests.length, requests);
    expect(router.currentConfiguration.hasFragment, isFalse);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
