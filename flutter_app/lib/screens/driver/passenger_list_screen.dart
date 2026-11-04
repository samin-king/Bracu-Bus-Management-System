import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../widgets/role_gate.dart';

/// There is no passenger/booking endpoint in the mounted transport backend.
class PassengerListScreen extends StatelessWidget {
  const PassengerListScreen({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => RoleGate(
        api: api,
        role: TransportRole.driver,
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Passenger List')),
          body: const SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Text(
                'Passenger information is unavailable. The existing backend does not expose a passenger or booking endpoint.',
              ),
            ),
          ),
        ),
      );
}
