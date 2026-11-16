import 'dart:async';
import 'package:flutter/material.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/driver/driver_dashboard.dart';
import 'screens/transport_home.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_message.dart';

class TransportApp extends StatefulWidget {
  const TransportApp({required this.auth, this.ownsAuth = false, super.key});
  final AuthProvider auth;
  final bool ownsAuth;
  @override
  State<TransportApp> createState() => _TransportAppState();
}

class _TransportAppState extends State<TransportApp>
    with WidgetsBindingObserver {
  late final AppRouter _router;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _router = AppRouter(widget.auth);
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.auth.refresh());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (widget.auth.authenticated) unawaited(widget.auth.refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.auth.refresh());
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'BRACU Smart Transport',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    routerDelegate: _router,
    routeInformationParser: const AppRouteParser(),
  );
  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    if (widget.ownsAuth) {
      widget.auth.dispose();
      widget.auth.service.http.close();
    }
    super.dispose();
  }
}

class AppRouter extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  AppRouter(this.auth) {
    api = ApiClient(
      client: auth.service.http,
      session: () => auth.authenticated ? auth.session : null,
    );
    auth.addListener(notifyListeners);
  }
  final AuthProvider auth;
  late final ApiClient api;
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Uri get currentConfiguration => Uri(
    path: switch (auth.status) {
      AuthStatus.checking => '/checking',
      AuthStatus.unavailable => '/unavailable',
      AuthStatus.signedOut => '/login',
      AuthStatus.signedIn => '/${auth.session!.role.name}',
    },
  );
  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    auth.receiveEmailLink(configuration);
    // Requested paths never establish authentication or select another role.
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final Widget page;
    switch (auth.status) {
      case AuthStatus.checking:
        page = const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking authentication...'),
              ],
            ),
          ),
        );
      case AuthStatus.unavailable:
        page = Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AuthMessage(
                      auth.error ?? 'Authentication unavailable.',
                      isError: true,
                    ),
                    FilledButton(
                      onPressed: auth.refresh,
                      child: const Text('Retry authentication check'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case AuthStatus.signedOut:
        page = LoginScreen(auth: auth);
      case AuthStatus.signedIn:
        final user = auth.session!;
        final Widget content;
        if (user.role.allows(TransportRole.authority)) {
          content = TransportHome(api: api);
        } else if (user.role == TransportRole.driver) {
          content = DriverDashboard(api: api);
        } else {
          // Authentication handoff only. Student business features are out of scope.
          content = const Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'You are signed in. Student transport features will be integrated next.',
                  ),
                ),
              ),
            ),
          );
        }
        page = Material(
          child: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${user.role.label}: ${user.name}'),
                        ),
                        TextButton.icon(
                          key: const Key('logout'),
                          onPressed: auth.busy ? null : auth.logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (auth.error != null) AuthMessage(auth.error!, isError: true),
              Expanded(child: content),
            ],
          ),
        );
    }
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          // Stable during periodic checks; changes on logout, role/account change.
          key: ValueKey(
            '${currentConfiguration.path}:${auth.session?.id ?? ''}',
          ),
          name: currentConfiguration.path,
          child: page,
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }

  @override
  void dispose() {
    auth.removeListener(notifyListeners);
    super.dispose();
  }
}

class AppRouteParser extends RouteInformationParser<Uri> {
  const AppRouteParser();
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) async =>
      routeInformation.uri;
  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}
