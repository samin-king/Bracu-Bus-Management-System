// Isolated visual verification entry point. Never used by lib/main.dart.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bracu_transport/main.dart';
import 'package:bracu_transport/services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final params = Uri.base.queryParameters;
  final mode = params['state'] ?? 'normal';
  final live = params['live'] == 'true';
  final driverRole = params['role'] == 'driver';
  const bus = {
    'id': 1,
    'bus_number': 'BRACU-01',
    'registration_number': 'DEMO-001',
    'capacity': 37,
    'status': 'ACTIVE',
  };
  const route = {
    'id': 1,
    'route_name': 'Mirpur to BRACU',
    'origin': 'Mirpur',
    'destination': 'BRACU',
    'stops': ['Mirpur', 'Farmgate', 'BRACU'],
  };
  const driver = {
    'id': 1,
    'name': 'Demo Driver',
    'license_number': 'DEMO-DL-001',
    'status': 'ACTIVE',
  };
  var status = 'SCHEDULED';
  Map<String, dynamic> trip() => {
    'id': 1,
    'bus_id': 1,
    'route_id': 1,
    'driver_id': 1,
    'driver': driver,
    'bus': bus,
    'route': route,
    'travel_date': '2026-11-16',
    'departure_time': '06:30:00',
    'status': status,
  };
  final client = live
      ? http.Client()
      : MockClient((request) async {
          if (mode == 'loading') await Completer<void>().future;
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (mode == 'error') {
            return http.Response(
              jsonEncode({'error': 'Demo: server unavailable'}),
              503,
            );
          }
          final path = request.url.path.replaceFirst('/api/', '');
          dynamic data;
          if (path.endsWith('/start') || path.endsWith('/stop')) {
            status = path.endsWith('/start') ? 'ACTIVE' : 'COMPLETED';
            data = trip();
          } else if (path.endsWith('/driver')) {
            final id = (jsonDecode(request.body) as Map)['driver_id'];
            data = {
              ...trip(),
              'driver_id': id,
              'driver': id == null ? null : driver,
            };
          } else if (path == 'drivers/me') {
            data = driver;
          } else if (path == 'drivers/me/trips') {
            data = mode == 'empty' ? [] : [trip()];
          } else {
            final record = switch (path.split('/').first) {
              'buses' => bus,
              'routes' => route,
              'drivers' => driver,
              _ => trip(),
            };
            data = request.method != 'GET'
                ? {...record, ...jsonDecode(request.body) as Map}
                : path.contains('/')
                ? record
                : mode == 'empty'
                ? []
                : [record];
          }
          return http.Response(
            jsonEncode(data),
            request.method == 'POST' &&
                    !path.endsWith('/start') &&
                    !path.endsWith('/stop')
                ? 201
                : 200,
          );
        });
  runApp(
    TransportApp(
      session: params['signedout'] == 'true'
          ? null
          : TransportSession(
              role: driverRole ? TransportRole.driver : TransportRole.authority,
              headers: () async => {},
            ),
      client: client,
      baseUrl: '${Uri.base.origin}/api',
    ),
  );
}
