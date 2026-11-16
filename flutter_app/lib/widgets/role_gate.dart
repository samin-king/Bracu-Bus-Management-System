import 'package:flutter/material.dart';

import '../services/api_client.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({
    super.key,
    required this.api,
    required this.role,
    required this.builder,
  });
  final ApiClient api;
  final TransportRole role;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => api.session?.role == role
      ? builder(context)
      : const Scaffold(
          body: SafeArea(
            child: Center(
              child: Text('Access denied. Sign in with an authorized account.'),
            ),
          ),
        );
}
