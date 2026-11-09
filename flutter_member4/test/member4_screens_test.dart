import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bracu_member4/member4.dart';

const complaint = <String, dynamic>{'id': 1, 'category': 'service',
  'description': 'Late bus', 'status': 'pending', 'response': null,
  'user_id': 'test-student', 'created_at': '2026-10-25T06:00:00Z'};

Future<void> render(WidgetTester tester, Widget screen,
    Future<http.Response> Function(http.Request) handler,
    {String? role = 'student', bool authenticated = true, double textScale = 1}) async {
  await tester.pumpWidget(Member4Session(
    api: Member4Api(baseUrl: Uri.parse('https://example.test/api/'), client: MockClient(handler)),
    role: role, authenticated: authenticated, sessionKey: 'test-session',
    child: MaterialApp(home: screen, builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!))));
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('student validates, submits, reloads history and opens details', (tester) async {
    final submitted = <Map<String, dynamic>>[];
    await render(tester, const ComplaintsScreen(), (r) async {
      if (r.method == 'POST') submitted.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(r.method == 'GET' && !r.url.path.endsWith('/1')
        ? (submitted.isEmpty ? [] : [complaint]) : complaint), 200);
    });
    await tester.pumpAndSettle();
    await tapText(tester, 'Submit complaint');
    expect(find.text('Enter 1–5000 characters'), findsOneWidget);
    expect(submitted, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'Late bus');
    await tapText(tester, 'Submit complaint');
    expect(submitted.single, {'category': 'service', 'description': 'Late bus', 'trip_id': null, 'route_id': null});
    expect(find.text('Complaint submitted'), findsOneWidget);
    await tapText(tester, '#1 · service');
    expect(find.text('Response: Awaiting response'), findsOneWidget);
  });

  testWidgets('authority inspects complaint and saves only supported update', (tester) async {
    Map<String, dynamic>? update;
    await render(tester, const ComplaintDetailScreen(id: '1', management: true), (r) async {
      if (r.method == 'PATCH') update = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({...complaint, ...?update}), 200);
    }, role: 'authority');
    await tester.pumpAndSettle();
    expect(find.text('Student: test-student'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('resolved').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'We are investigating');
    await tapText(tester, 'Update complaint');
    expect(update, {'status': 'resolved', 'response': 'We are investigating'});
    expect(find.text('Complaint updated'), findsOneWidget);
  });

  testWidgets('authority management filters existing list API', (tester) async {
    final calls = <Uri>[];
    await render(tester, const ComplaintManagementScreen(), (r) async {
      calls.add(r.url);
      return http.Response('[]', 200);
    }, role: 'admin');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Late');
    await tapText(tester, 'Filter complaints');
    expect(calls.last.path, '/api/authority/complaints');
    expect(calls.last.queryParameters['search'], 'Late');
    expect(calls.last.queryParameters['offset'], '0');
  });

  testWidgets('feedback submits valid service rating and shows confirmation', (tester) async {
    Map<String, dynamic>? body;
    await render(tester, const FeedbackScreen(), (r) async {
      if (r.method == 'POST') body = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(r.method == 'GET' ? '[]' : '{}', 200);
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Comfortable ride');
    await tapText(tester, 'Submit feedback');
    expect(body, {'target': 'service', 'rating': 5, 'comment': 'Comfortable ride'});
    expect(find.text('Feedback submitted'), findsOneWidget);
  });

  testWidgets('notifications open details, mark one/all and refresh', (tester) async {
    var count = 2, loads = 0;
    final patches = <String>[];
    await render(tester, const NotificationsScreen(), (r) async {
      if (r.method == 'PATCH') { patches.add(r.url.path); count = r.url.path.endsWith('read-all') ? 0 : 1; return http.Response('{}', 200); }
      if (r.url.path.endsWith('unread-count')) return http.Response('{"count":$count}', 200);
      loads++;
      return http.Response(jsonEncode([{'id': 1, 'title': 'Complaint updated',
        'message': 'Reviewed', 'read_at': count < 2 ? '2026-10-25T06:00:00Z' : null}]), 200);
    });
    await tester.pumpAndSettle();
    expect(find.text('Unread: 2'), findsOneWidget);
    await tapText(tester, 'Complaint updated');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tapText(tester, 'Close');
    await tapText(tester, 'Mark as read');
    expect(find.text('Unread: 1'), findsOneWidget);
    await tapText(tester, 'Mark all as read');
    expect(find.text('Unread: 0'), findsOneWidget);
    expect(patches, ['/api/notifications/1/read', '/api/notifications/read-all']);
    final previous = loads;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(loads, previous + 1);
  });

  testWidgets('bus feedback requires valid matching reference and rejects whitespace comment', (tester) async {
    Map<String, dynamic>? submitted;
    await render(tester, const FeedbackScreen(), (r) async {
      if (r.method == 'POST') submitted = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(r.method == 'GET' ? '[]' : '{}', 200);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('bus').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Submit feedback');
    expect(submitted, isNull);
    expect(find.text('Enter an ID from 1 to 2147483647'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '7');
    await tester.enterText(find.byType(TextFormField).last, '   ');
    await tapText(tester, 'Submit feedback');
    expect(submitted, isNull);
    expect(find.text('Enter 1–5000 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'Good bus');
    await tapText(tester, 'Submit feedback');
    expect(submitted, {'target': 'bus', 'bus_id': 7, 'rating': 5, 'comment': 'Good bus'});
  });

  testWidgets('loading, API failure and retry states', (tester) async {
    final pending = Completer<http.Response>();
    var attempts = 0;
    await render(tester, const NotificationsScreen(), (r) async {
      if (r.url.path.endsWith('unread-count')) return http.Response('{"count":0}', 200);
      attempts++;
      return attempts == 1 ? pending.future : http.Response('[]', 200);
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(http.Response('{"error":"Service unavailable"}', 503));
    await tester.pumpAndSettle();
    expect(find.text('Service unavailable'), findsOneWidget);
    await tapText(tester, 'Retry');
    expect(find.text('You have no notifications. Pull down to refresh.'), findsOneWidget);
  });

  testWidgets('access guards deny unauthorized screens without requests', (tester) async {
    for (final entry in <(Widget, String)>[
      (const ComplaintsScreen(), 'driver'), (const FeedbackScreen(), 'authority'),
      (const ComplaintsScreen(), 'admin'), (const ComplaintManagementScreen(), 'student'),
      (const ComplaintManagementScreen(), 'driver'),
    ]) {
      await render(tester, entry.$1, (_) async => throw StateError('Must not request'), role: entry.$2);
      expect(find.text('Insufficient permission'), findsOneWidget);
    }
    await render(tester, const NotificationsScreen(), (_) async => throw StateError('Must not request'), authenticated: false);
    expect(find.text('Authenticated user required'), findsOneWidget);
  });

  testWidgets('server permission denial is displayed despite local student role', (tester) async {
    await render(tester, const ComplaintsScreen(), (_) async => http.Response('{"error":"Authenticated user required"}', 401));
    await tester.pumpAndSettle();
    expect(find.text('Authenticated user required'), findsOneWidget);
  });

  testWidgets('pending feedback blocks duplicate submission and preserves input on failure', (tester) async {
    final pending = Completer<http.Response>();
    var submits = 0;
    await render(tester, const FeedbackScreen(), (r) async {
      if (r.method == 'GET') return http.Response('[]', 200);
      submits++;
      return pending.future;
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Keep my feedback');
    await tester.ensureVisible(find.text('Submit feedback'));
    await tester.tap(find.text('Submit feedback'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit feedback'));
    expect(button.onPressed, isNull);
    expect(submits, 1);
    pending.complete(http.Response('{"error":"Cannot save feedback"}', 500));
    await tester.pumpAndSettle();
    expect(find.text('Cannot save feedback'), findsOneWidget);
    expect(find.text('Keep my feedback'), findsOneWidget);
    expect(find.text('Feedback submitted'), findsNothing);
  });

  testWidgets('notification pagination and pull refresh preserve current offset', (tester) async {
    final offsets = <String>[];
    await render(tester, const NotificationsScreen(), (r) async {
      if (r.url.path.endsWith('unread-count')) return http.Response('{"count":0}', 200);
      offsets.add(r.url.queryParameters['offset']!);
      return http.Response(jsonEncode(offsets.last == '0' ? List.generate(50,
        (i) => {'id': i + 1, 'title': 'Notice $i', 'message': 'Message', 'read_at': '2026-10-25'}) : []), 200);
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Next'), 700);
    await tapText(tester, 'Next');
    expect(offsets.last, '50');
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    final before = offsets.length;
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(offsets.length, greaterThan(before));
    expect(offsets.last, '50');
  });

  testWidgets('failed authority save preserves the editable draft', (tester) async {
    await render(tester, const ComplaintDetailScreen(id: '1', management: true), (r) async =>
      r.method == 'PATCH' ? http.Response('{"error":"Update unavailable"}', 503) :
        http.Response(jsonEncode(complaint), 200), role: 'authority');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Keep this draft');
    await tapText(tester, 'Update complaint');
    expect(find.text('Update unavailable'), findsOneWidget);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Update complaint'), findsOneWidget);
    expect(find.text('Complaint updated'), findsNothing);
  });

  testWidgets('status-only update omits blank response and unchanged save makes no request', (tester) async {
    final updates = <Json>[];
    await render(tester, const ComplaintDetailScreen(id: '1', management: true), (r) async {
      if (r.method == 'PATCH') updates.add(jsonDecode(r.body) as Json);
      return http.Response(jsonEncode({...complaint, if (updates.isNotEmpty) ...updates.last}), 200);
    }, role: 'admin');
    await tester.pumpAndSettle();
    await tapText(tester, 'Update complaint');
    expect(updates, isEmpty);
    expect(find.text('No changes to save'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('resolved').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Update complaint');
    expect(updates.single, {'status': 'resolved'});
  });

  testWidgets('forms cannot submit while the initial history request is pending', (tester) async {
    final pending = Completer<http.Response>();
    var submits = 0;
    await render(tester, const ComplaintsScreen(), (r) async {
      if (r.method == 'POST') submits++;
      return pending.future;
    });
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit complaint'));
    expect(button.onPressed, isNull);
    expect(submits, 0);
    pending.complete(http.Response('[]', 200));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit complaint')).onPressed, isNotNull);
  });

  testWidgets('failed next-page request retries the requested offset', (tester) async {
    final offsets = <String>[];
    var nextAttempts = 0;
    await render(tester, const NotificationsScreen(), (r) async {
      if (r.url.path.endsWith('unread-count')) return http.Response('{"count":0}', 200);
      final offset = r.url.queryParameters['offset']!;
      offsets.add(offset);
      if (offset == '50' && nextAttempts++ == 0) return http.Response('{"error":"Try again"}', 503);
      return http.Response(jsonEncode(offset == '0' ? List.generate(50,
        (i) => {'id': i + 1, 'title': 'Notice $i', 'message': 'Message'}) : []), 200);
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Next'), 700);
    await tapText(tester, 'Next');
    await tapText(tester, 'Retry');
    expect(offsets, ['0', '50', '50']);
    expect(find.text('Page 2'), findsOneWidget);
  });

  testWidgets('ordinary host rebuild preserves draft; account switch clears it', (tester) async {
    var requests = 0;
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
      client: MockClient((_) async { requests++; return http.Response('[]', 200); }));
    Widget host(String key) => Member4Session(api: api, role: 'student',
      authenticated: true, sessionKey: key,
      child: MaterialApp(home: ComplaintsScreen()));
    await tester.pumpWidget(host('account-a'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Private draft');
    await tester.pumpWidget(host('account-a'));
    await tester.pumpAndSettle();
    expect(find.text('Private draft'), findsOneWidget);
    expect(requests, 1);
    await tester.pumpWidget(host('account-b'));
    await tester.pumpAndSettle();
    expect(find.text('Private draft'), findsNothing);
    expect(requests, 2);
  });

  testWidgets('sign-out removes content from an already-open notification dialog', (tester) async {
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
      client: MockClient((r) async => http.Response(r.url.path.endsWith('unread-count') ?
        '{"count":0}' : '[{"id":1,"title":"Private notice","message":"Account A only"}]', 200)));
    Widget host(String key, bool authenticated) => Member4Session(api: api, role: 'student',
      authenticated: authenticated, sessionKey: key,
      child: const MaterialApp(home: NotificationsScreen()));
    await tester.pumpWidget(host('account-a', true));
    await tester.pumpAndSettle();
    await tapText(tester, 'Private notice');
    expect(find.text('Account A only'), findsWidgets);
    await tester.pumpWidget(host('signed-out', false));
    await tester.pumpAndSettle();
    expect(find.text('Account A only'), findsNothing);
    expect(find.text('Session changed'), findsOneWidget);
  });

  testWidgets('disposed page ignores a late request completion', (tester) async {
    final pending = Completer<http.Response>();
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
      client: MockClient((_) => pending.future));
    Widget host(bool authenticated) => Member4Session(api: api, role: 'student',
      authenticated: authenticated, sessionKey: authenticated ? 'account-a' : 'signed-out',
      child: const MaterialApp(home: ComplaintsScreen()));
    await tester.pumpWidget(host(true));
    await tester.pump();
    await tester.pumpWidget(host(false));
    pending.complete(http.Response(jsonEncode([complaint]), 200));
    await tester.pumpAndSettle();
    expect(find.text('Late bus'), findsNothing);
    expect(find.text('Authenticated user required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone layouts tolerate enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in <(Widget, String)>[
      (const ComplaintsScreen(), 'student'), (const FeedbackScreen(), 'student'),
      (const ComplaintManagementScreen(), 'authority'),
      (const ComplaintDetailScreen(id: '1', management: true), 'admin'),
      (const NotificationsScreen(), 'driver'),
    ]) {
      await render(tester, entry.$1, (r) async {
        if (r.url.path.endsWith('unread-count')) return http.Response('{"count":0}', 200);
        return http.Response(r.url.path.endsWith('/1') ? jsonEncode(complaint) : '[]', 200);
      }, role: entry.$2, textScale: 1.8);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('successful submission with failed refresh retries only the GET', (tester) async {
    var loads = 0, submits = 0;
    await render(tester, const FeedbackScreen(), (r) async {
      if (r.method == 'POST') { submits++; return http.Response('{}', 201); }
      loads++;
      return loads == 2 ? http.Response('{"error":"History unavailable"}', 503) : http.Response('[]', 200);
    });
    await tester.pumpAndSettle();
    await tapText(tester, 'Submit feedback');
    expect(find.text('Feedback submitted'), findsOneWidget);
    expect(find.text('History unavailable'), findsOneWidget);
    await tapText(tester, 'Retry');
    expect(submits, 1);
    expect(loads, 3);
  });

  testWidgets('server denial hides records and stays closed after a transient retry failure', (tester) async {
    var denied = false;
    await render(tester, const NotificationsScreen(), (r) async {
      if (r.method == 'PATCH') {
        denied = true;
        return http.Response('{"error":"Session expired"}', 401);
      }
      if (denied) return http.Response('{"error":"Unavailable"}', 503);
      if (r.url.path.endsWith('unread-count')) return http.Response('{"count":1}', 200);
      return http.Response('[{"id":1,"title":"Private record","message":"Student only"}]', 200);
    });
    await tester.pumpAndSettle();
    await tapText(tester, 'Mark as read');
    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Private record'), findsNothing);
    expect(find.text('Mark all as read'), findsNothing);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Mark all as read'), findsNothing);
  });
}
