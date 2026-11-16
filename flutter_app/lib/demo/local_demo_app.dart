import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../models/bus.dart';
import '../models/route.dart';
import '../models/trip.dart';
import '../models/driver.dart';
import '../services/api_client.dart';
import '../services/bus_service.dart';
import '../services/route_service.dart';
import '../services/trip_service.dart';
import '../services/driver_service.dart';
import '../screens/management_screen.dart';
import '../screens/driver/driver_assignment_screen.dart';
import '../screens/driver/driver_dashboard.dart';
import 'demo_store.dart';
import 'student_demo_screens.dart';
import '../design/transport_theme.dart';
import '../design/premium_demo_shell.dart';

/// Only reachable when explicitly built with --dart-define=LOCAL_DEMO=true.
class LocalDemoApp extends StatefulWidget {
  const LocalDemoApp({super.key});
  @override
  State<LocalDemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<LocalDemoApp> {
  final store = DemoStore();
  TransportRole? role;
  ApiClient? api;
  String selected = 'Dashboard';
  int navigationVersion = 0;
  void openModule(String name) => setState(() {
    selected = name;
    navigationVersion++;
  });
  SemanticsHandle? semantics;
  @override
  void initState() {
    super.initState();
    semantics = SemanticsBinding.instance.ensureSemantics();
  }

  @override
  void dispose() {
    api?.client.close();
    store.dispose();
    semantics?.dispose();
    super.dispose();
  }

  List<String> get modules => switch (role) {
    TransportRole.student => [
      'Dashboard',
      'Student Profile',
      'Bus Booking',
      'Booking History',
      'Complaints',
      'Feedback',
      'Notifications',
    ],
    TransportRole.driver => [
      'Dashboard',
      'Driver Profile',
      'Assigned Trips',
      'Trip Schedule',
      'Passenger List',
      'Notifications',
    ],
    TransportRole.authority => [
      'Dashboard',
      'Bus Management',
      'Route Management',
      'Trip Management',
      'Driver Management',
      'Driver Assignment',
      'Complaints Management',
      'Notifications Management',
    ],
    null => [],
  };
  void login(TransportRole value) => setState(() {
    api?.client.close();
    role = value;
    api = store.api(value);
    selected = 'Dashboard';
    store.setViewState('Normal');
  });
  void logout() => setState(() {
    store.setViewState('Normal');
    role = null;
    selected = 'Dashboard';
    api?.client.close();
    api = null;
  });

  Widget module() {
    final currentApi = api!;
    return switch (selected) {
      'Dashboard' => DemoDashboard(store: store, role: role!, open: openModule),
      'Bus Management' => ManagementScreen<Bus>(
        service: BusService(currentApi),
        title: 'Buses',
        kind: 'bus',
        enableTools: true,
      ),
      'Route Management' => ManagementScreen<BusRoute>(
        service: RouteService(currentApi),
        title: 'Routes',
        kind: 'route',
        enableTools: true,
      ),
      'Trip Management' => ManagementScreen<Trip>(
        service: TripService(currentApi),
        title: 'Trips',
        kind: 'trip',
        enableTools: true,
      ),
      'Driver Management' => ManagementScreen<Driver>(
        service: DriverService(currentApi),
        title: 'Drivers',
        kind: 'driver',
        enableTools: true,
      ),
      'Driver Assignment' => DriverAssignmentScreen(api: currentApi),
      'Assigned Trips' => DriverDashboard(
        api: currentApi,
        passengerBuilder: (_) => DemoPassengers(store: store),
      ),
      'Driver Profile' => DemoDriverProfile(store: store),
      'Trip Schedule' => DemoSchedule(store: store),
      'Passenger List' => DemoPassengers(store: store),
      'Student Profile' => DemoStudentProfile(store: store),
      'Bus Booking' => DemoBooking(store: store),
      'Booking History' => DemoBookingHistory(store: store),
      'Complaints' || 'Complaints Management' => DemoCollection(
        store: store,
        resource: 'complaints',
        authority: role == TransportRole.authority,
      ),
      'Feedback' => DemoCollection(store: store, resource: 'feedback'),
      'Notifications' || 'Notifications Management' => DemoCollection(
        store: store,
        resource: 'notifications',
        authority: role == TransportRole.authority,
        audience: role!.name.toUpperCase(),
      ),
      _ => const SizedBox(),
    };
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BRACU Transport ? Local Demo',
    theme: TransportTheme.light,
    home: PremiumDemoShell(
      role: role, modules: modules, selected: selected, viewState: store.viewState,
      navigationKey: '${role?.name}-$selected-${store.viewState}-$navigationVersion',
      content: (_) => module(), login: login, logout: logout, openModule: openModule,
      changeViewState: (state) => setState(() => store.setViewState(state)),
    ),
  );
}
