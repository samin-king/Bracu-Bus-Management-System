import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bracu_member4/member4.dart';

void main() {
  test('all existing endpoints, verbs, filters and request bodies', () async {
    final calls = <http.Request>[];
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
      client: MockClient((r) async {
        calls.add(r);
        final path = r.url.path;
        if (path.endsWith('unread-count')) return http.Response('{"count":2}', 200);
        if (r.method == 'GET' && !RegExp(r'/\d+$').hasMatch(path)) {
          return http.Response('[]', 200);
        }
        return http.Response('{"id":1,"category":"service","description":"Late","status":"pending"}', 200);
      }));
    await api.complaints(1);
    await api.complaint('1');
    await api.submitComplaint({'category': 'service', 'description': 'Late'});
    await api.complaints(0, management: true, filters: {'search': 'a & b', 'status': 'pending'});
    await api.complaint('1', management: true);
    await api.updateComplaint('1', {'status': 'resolved', 'response': 'Reviewed'});
    await api.feedback(0);
    await api.submitFeedback({'target': 'trip', 'trip_id': 1, 'rating': 4, 'comment': ''});
    await api.notifications(2);
    expect(await api.unread(), 2);
    await api.markRead('1');
    await api.markAllRead();
    expect(calls.map((r) => '${r.method} ${r.url.path}'), [
      'GET /api/complaints', 'GET /api/complaints/1', 'POST /api/complaints',
      'GET /api/authority/complaints', 'GET /api/authority/complaints/1',
      'PATCH /api/authority/complaints/1', 'GET /api/feedback', 'POST /api/feedback',
      'GET /api/notifications', 'GET /api/notifications/unread-count',
      'PATCH /api/notifications/1/read', 'PATCH /api/notifications/read-all',
    ]);
    expect(calls.first.url.queryParameters, {'limit': '50', 'offset': '50'});
    expect(calls[3].url.queryParameters['search'], 'a & b');
    expect(jsonDecode(calls[5].body), {'status': 'resolved', 'response': 'Reviewed'});
    expect(jsonDecode(calls[7].body), {'target': 'trip', 'trip_id': 1, 'rating': 4, 'comment': ''});
    for (final call in calls) {
      expect(call.headers.containsKey('x-user-id'), false);
      expect(call.headers.containsKey('x-role'), false);
    }
  });

  for (final status in [400, 401, 403, 404, 500]) {
    test('preserves server error and HTTP status $status', () async {
      final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
        client: MockClient((_) async => http.Response('{"error":"server message"}', status)));
      await expectLater(api.notifications(0), throwsA(isA<Member4Exception>()
        .having((e) => e.status, 'status', status)
        .having((e) => e.message, 'message', 'server message')));
    });
  }
  test('malformed response and network failures give usable errors', () async {
    for (final client in [MockClient((_) async => http.Response('<html>', 502)),
      MockClient((_) async => throw http.ClientException('offline'))]) {
      final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'), client: client);
      await expectLater(api.notifications(0), throwsA(isA<Member4Exception>()));
    }
  });
  test('validation matches backend raw text length, whitespace and ID bounds', () {
    expect(requiredText(' '), isNotNull);
    expect(requiredText('a' * 5001), isNotNull);
    expect(requiredText('a' * 5000), isNull);
    expect(referenceId(''), isNull);
    for (final id in ['', '0', '-1', '01', '1.5', '2147483648', ' 1']) {
      expect(referenceId(id, required: true), isNotNull);
    }
    expect(referenceId('2147483647', required: true), isNull);
  });

  test('malformed success payloads return controlled errors, not cast failures', () async {
    for (final payload in ['{}', 'null', '[null]', '[{"id":1}]',
      '[{"id":1,"title":4,"message":"hello"}]',
      '[{"id":1,"title":"hello","message":"world","read_at":5}]']) {
      final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
        client: MockClient((_) async => http.Response(payload, 200)));
      await expectLater(api.notifications(0), throwsA(isA<Member4Exception>()
        .having((e) => e.message, 'message', 'Unexpected API response')));
    }
    for (final payload in ['{"count":"2"}', '{"count":-1}', '[]']) {
      final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
        client: MockClient((_) async => http.Response(payload, 200)));
      await expectLater(api.unread(), throwsA(isA<Member4Exception>()));
    }
  });

  test('UTF-8 notification content is preserved without a charset header', () async {
    const title = 'বাসের সময়সূচি';
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
      client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode([
        {'id': 1, 'title': title, 'message': 'সকাল ৮টা', 'read_at': null},
      ])), 200, headers: {'content-type': 'application/json'})));
    expect((await api.notifications(0)).single.title, title);
  });

  test('timeout is bounded and never retries a submission automatically', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
      timeout: const Duration(milliseconds: 1), client: MockClient((_) {
        calls++;
        return pending.future;
      }));
    await expectLater(api.submitFeedback({'target': 'service', 'rating': 5}),
      throwsA(isA<Member4Exception>().having((e) => e.message, 'message', contains('timed out'))));
    expect(calls, 1);
    pending.complete(http.Response('{}', 201));
  });

  test('invalid IDs, pages and base URLs never reach the transport', () async {
    final client = MockClient((_) async => throw StateError('Must not request'));
    for (final url in ['https://example.test/api', '/api/',
      'https://example.test/api/?x=1', 'https://user:pass@example.test/api/']) {
      expect(() => Member4Api(baseUrl: Uri.parse(url), client: client), throwsArgumentError);
    }
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'), client: client);
    await expectLater(api.complaints(-1), throwsArgumentError);
    await expectLater(api.notifications(42949673), throwsArgumentError);
    await expectLater(api.complaint('../feedback'), throwsArgumentError);
    await expectLater(api.markRead('1/read-all'), throwsArgumentError);
  });

  test('host authenticated client supplies credentials through send()', () async {
    final transport = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-only-token');
      expect(request.headers.containsKey('x-role'), false);
      return http.Response('[]', 200);
    });
    final client = _AuthenticatedTestClient(transport);
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'), client: client);
    await api.complaints(0);
    client.close();
  });

  test('realistic complaint, feedback and notification list records parse', () async {
    final api = Member4Api(baseUrl: Uri.parse('https://example.test/api/'),
      client: MockClient((r) async {
        final rows = r.url.path.endsWith('feedback') ? [
          {'id': 7, 'user_id': 'student-a', 'target': 'route', 'route_id': 2,
            'bus_id': null, 'trip_id': null, 'rating': 4, 'comment': null},
        ] : r.url.path.endsWith('complaints') ? [
          {'id': '9', 'user_id': 'student-a', 'category': 'safety',
            'description': 'Unsafe driving', 'status': 'in_review',
            'trip_id': 2, 'route_id': null, 'response': 'Investigating'},
        ] : [
          {'id': 1, 'title': 'Complaint updated', 'message': 'Investigating',
            'read_at': '2026-10-25T06:00:00Z', 'reference_type': 'complaint', 'reference_id': '9'},
        ];
        return http.Response(jsonEncode(rows), 200);
      }));
    final complaint = (await api.complaints(0)).single;
    expect(complaint.id, '9');
    expect(complaint.status, 'in_review');
    expect(complaint.response, 'Investigating');
    final feedback = (await api.feedback(0)).single;
    expect(feedback.data['rating'], 4);
    expect(feedback.data['comment'], isNull);
    expect((await api.notifications(0)).single.isRead, true);
    expect(() => complaint.data['status'] = 'resolved', throwsUnsupportedError);
  });
}

// Test-only adapter. Production credentials come exclusively from the host.
class _AuthenticatedTestClient extends http.BaseClient {
  _AuthenticatedTestClient(this.transport);
  final http.Client transport;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer test-only-token';
    return transport.send(request);
  }
  @override
  void close() => transport.close();
}
