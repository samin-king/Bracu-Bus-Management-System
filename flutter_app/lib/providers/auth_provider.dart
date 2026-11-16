import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/auth_session.dart';
import '../services/auth_failure.dart';
import '../services/auth_service.dart';
import '../services/session_http_client.dart';

enum AuthStatus { checking, signedOut, signedIn, unavailable }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.service) {
    service.http.onUnauthorized = invalidate;
  }
  final AuthService service;
  AuthSession? session;
  AuthStatus status = AuthStatus.checking;
  String? error, notice, linkToken;
  bool get busy => _pendingMutations > 0;
  bool get authenticated => status == AuthStatus.signedIn && session != null;
  int _revision = 0, _pendingMutations = 0;
  bool _disposed = false;
  Future<void> _mutations = Future<void>.value();
  Future<void>? _refresh;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  String _message(Object failure) => switch (failure) {
    AuthFailure() => failure.message,
    ApiException() => failure.message,
    _ => const AuthFailure('unavailable').message,
  };

  void invalidate() {
    final hadSession = session != null;
    _revision++;
    session = null;
    status = AuthStatus.signedOut;
    // An anonymous startup /me may finish after an incoming email App Link.
    // Keep that new link available for explicit verification.
    if (hadSession) {
      linkToken = null;
    }
    error = hadSession ? const AuthFailure('unauthenticated').message : error;
    notice = null;
    _emit();
  }

  Future<void> refresh() {
    if (busy) return Future<void>.value();
    if (_refresh != null) return _refresh!;
    final revision = _revision;
    // A retry replaces the previous connection/storage failure. Incoming link
    // validation feedback remains available during an initial session check.
    if (status == AuthStatus.unavailable) error = null;
    final done = Completer<void>();
    _refresh = done.future;
    if (session == null) status = AuthStatus.checking;
    _emit();
    () async {
      try {
        final user = await service.currentUser();
        if (revision == _revision) {
          session = user;
          status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
          error = null;
        }
      } catch (failure) {
        if (revision == _revision) {
          session = null;
          status = AuthStatus.unavailable;
          error = _message(failure);
        }
      } finally {
        _refresh = null;
        _emit();
        done.complete();
      }
    }();
    return done.future;
  }

  // Only refreshes coalesce. Mutations are queued, never replaced by /me.
  // Revision checks also prevent an older response from undoing logout/401.
  Future<void> _mutate(Future<void> Function(int revision) action) {
    final revision = ++_revision;
    _pendingMutations++;
    error = null;
    notice = null;
    _emit();
    final result = _mutations.then((_) async {
      try {
        await action(revision);
      } catch (failure) {
        if (revision == _revision) {
          error = _message(failure);
          status = session == null ? AuthStatus.signedOut : AuthStatus.signedIn;
        }
      } finally {
        _pendingMutations--;
        _emit();
      }
    });
    _mutations = result;
    return result;
  }

  Future<void> requestEmail(String email) => _mutate((revision) async {
    await service.requestEmail(email);
    if (revision == _revision) notice = 'Check your email for a sign-in link.';
  });

  Future<void> _signIn(Future<AuthSession> Function() operation) =>
      _mutate((revision) async {
        final user = await operation();
        if (revision == _revision) {
          session = user;
          status = AuthStatus.signedIn;
          linkToken = null;
          notice = 'Signed in successfully.';
        }
      });

  Future<void> verifyEmail(String tokenOrLink) {
    String token = tokenOrLink.trim();
    final link = Uri.tryParse(token);
    if (link != null && link.hasScheme) token = _tokenFromLink(link) ?? '';
    linkToken = null;
    return _signIn(() => service.verifyEmail(token));
  }

  Future<void> googleLogin() => _signIn(service.googleLogin);

  Future<void> logout() {
    // Remove protected navigation immediately, even if refresh is in flight.
    status = AuthStatus.checking;
    linkToken = null;
    return _mutate((revision) async {
      await service.logout();
      if (revision == _revision) {
        session = null;
        status = AuthStatus.signedOut;
        notice = 'You have been signed out.';
      }
    });
  }

  String? _tokenFromLink(Uri uri) {
    if (!uri.hasAuthority ||
        uri.scheme != service.http.config.frontend.scheme ||
        uri.origin != service.http.config.frontend.origin ||
        uri.path != '/login' ||
        uri.hasQuery ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    try {
      final values = Uri(query: uri.fragment).queryParametersAll;
      final tokens = values['email_token'];
      if (values.length != 1 || tokens?.length != 1) return null;
      final token = tokens!.single;
      return RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token) ? token : null;
    } on FormatException {
      return null;
    }
  }

  void receiveEmailLink(Uri uri) {
    if (authenticated ||
        !uri.hasAuthority ||
        uri.scheme != service.http.config.frontend.scheme ||
        uri.origin != service.http.config.frontend.origin ||
        uri.path != '/login' ||
        uri.userInfo.isNotEmpty) {
      return;
    }
    final token = _tokenFromLink(uri);
    if (!uri.hasFragment) return;
    linkToken = token;
    error = token == null
        ? const AuthFailure('invalid_email_token').message
        : null;
    notice = null;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    service.http.onUnauthorized = null;
    super.dispose();
  }
}
