import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'services/api_client.dart';
import 'auth/authenticated_host.dart';
import 'demo/local_demo_app.dart';
import 'design/transport_theme.dart';
import 'screens/bus/bus_screen.dart';
import 'screens/routes/route_screen.dart';
import 'screens/trips/trip_screen.dart';
import 'screens/driver/driver_screen.dart';
import 'screens/driver/driver_assignment_screen.dart';
import 'screens/driver/driver_dashboard.dart';

void main() => runApp(
  const bool.fromEnvironment('LOCAL_DEMO')
      ? const LocalDemoApp()
      : const AuthenticatedTransportHost(
          baseUrl: String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: kIsWeb
                ? 'http://127.0.0.1:3002/api'
                : 'http://10.0.2.2:3002/api',
          ),
        ),
);

/// The parent authentication module supplies a verified session after login.
/// On logout dispose this app/route tree, so privileged routes cannot remain open.
class TransportApp extends StatefulWidget {
  const TransportApp({
    super.key,
    this.session,
    this.client,
    this.onLogout,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000/api',
    ),
  });
  final TransportSession? session;
  final http.Client? client;
  final VoidCallback? onLogout;
  final String baseUrl;
  @override
  State<TransportApp> createState() => _TransportAppState();
}

class _TransportAppState extends State<TransportApp> {
  late final http.Client client = widget.client ?? http.Client();
  @override
  void dispose() {
    if (widget.client == null) client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(
      baseUrl: widget.baseUrl,
      session: widget.session,
      client: client,
    );
    return MaterialApp(
      key: ObjectKey(widget.session),
      title: 'BRACU Transport',
      theme: TransportTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('BRACU Transport'),
            actions: [
              if (widget.onLogout != null)
                TextButton(
                  onPressed: widget.onLogout,
                  child: const Text('Sign out'),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.session == null)
                  const Text(
                    'Sign in through the main application to access transport features.',
                  ),
                if (widget.session?.role == TransportRole.student)
                  const Text(
                    'Transport management is available to authorized transport staff.',
                  ),
                if (widget.session?.role == TransportRole.authority) ...[
                  _link(context, 'Buses', () => BusScreen(api: api)),
                  _link(context, 'Routes', () => RouteScreen(api: api)),
                  _link(context, 'Trips', () => TripScreen(api: api)),
                  _link(context, 'Drivers', () => DriverScreen(api: api)),
                  _link(
                    context,
                    'Driver Assignment',
                    () => DriverAssignmentScreen(api: api),
                  ),
                ],
                if (widget.session?.role == TransportRole.driver)
                  _link(
                    context,
                    'Driver Dashboard',
                    () => DriverDashboard(api: api),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _link(BuildContext context, String title, Widget Function() screen) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.tonal(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen()),
          ),
          child: Padding(padding: const EdgeInsets.all(12), child: Text(title)),
        ),
      );
}
