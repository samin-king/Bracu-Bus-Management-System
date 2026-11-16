import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../services/api_client.dart';
import 'platform_client.dart';
import '../design/transport_theme.dart';

/// The HttpOnly cookie stays in the browser. Roles are read from the server.
class AuthenticatedTransportHost extends StatefulWidget {
  const AuthenticatedTransportHost({
    super.key,
    required this.baseUrl,
    this.client,
  });
  final String baseUrl;
  final http.Client? client;
  @override
  State<AuthenticatedTransportHost> createState() => _HostState();
}

class _HostState extends State<AuthenticatedTransportHost> {
  late final client = widget.client ?? createSessionClient();
  TransportSession? session;
  String? accountId, error;
  bool loading = true;
  String get base => widget.baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<Map<String, dynamic>?> readSession() async {
    final response = await client
        .get(Uri.parse('$base/auth/me'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) {
      throw const ApiException(
        'Authentication service unavailable. Please retry.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['id'] == null ||
        !['student', 'driver', 'authority'].contains(data['role'])) {
      throw const ApiException('Invalid authenticated session response.');
    }
    return {'user': data, 'role': data['role']};
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await readSession();
      if (!mounted) return;
      final role = data == null
          ? null
          : TransportRole.values.byName(data['role'] as String);
      accountId = data == null ? null : '${(data['user'] as Map)['id']}';
      session = role == null
          ? null
          : TransportSession(
              role: role,
              headers: () async {
                final current = await readSession();
                if (current == null ||
                    current['role'] != role.name ||
                    '${(current['user'] as Map)['id']}' != accountId) {
                  if (mounted) {
                    setState(() {
                      session = null;
                      accountId = null;
                    });
                  }
                  throw const ApiException(
                    'Your session changed or expired. Sign in again.',
                    401,
                  );
                }
                return {}; // BrowserClient supplies the HttpOnly cookie automatically.
              },
            );
    } catch (_) {
      if (mounted) {
        setState(() {
          session = null;
          error =
              'Cannot verify your session. Check the authentication server and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    try {
      final response = await client.post(Uri.parse('$base/auth/logout'));
      if (response.statusCode != 204) throw const ApiException('Logout failed');
      if (mounted) {
        setState(() {
          session = null;
          accountId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          session = null;
          error =
              'Logout failed. Your server session may still be active. Check session and retry sign out.';
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.client == null) client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (session != null) {
      return TransportApp(
        session: session,
        client: client,
        baseUrl: base,
        onLogout: logout,
      );
    }
    return MaterialApp(
      title: 'BRACU Transport',
      theme: TransportTheme.light,
      home: Scaffold(
        appBar: AppBar(title: const Text('BRACU Transport')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    error ??
                        _loginError(Uri.base.queryParameters['error']) ??
                        'Sign in with your authorized BRACU Google account.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (!openLogin('$base/auth/google')) {
                        setState(
                          () => error =
                              'Browser login is currently supported on Flutter Web.',
                        );
                      }
                    },
                    child: const Text('Sign in with Google'),
                  ),
                  TextButton(
                    onPressed: refresh,
                    child: const Text('Check session / Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _loginError(String? code) => switch (code) {
  null => null,
  'account_not_authorized' =>
    'This Google account is not authorized. Contact your BRACU administrator.',
  'invalid_institution' =>
    'Use an eligible, verified BRACU institutional Google account.',
  'google_denied' => 'Google sign-in was cancelled. You can try again.',
  'oauth_not_configured' =>
    'Google sign-in is not configured on the server yet.',
  'invalid_callback' =>
    'The sign-in request expired or was invalid. Please try again.',
  _ => 'Google sign-in failed. Please try again or contact your administrator.',
};
