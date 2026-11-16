import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../state/booking_state.dart';

class TripStopsSelection extends StatelessWidget {
  const TripStopsSelection({super.key, required this.state});
  final BookingState state;
  @override
  Widget build(BuildContext context) {
    final trip = state.availability!.trip;
    if (!trip.requiresStops) return const SizedBox.shrink();
    final pickups =
        trip.stops.where((s) => s['pickupAllowed'] == true).toList();
    final pickup =
        pickups.where((s) => s['id'] == state.pickupStopId).firstOrNull;
    final drops = trip.stops
        .where((s) =>
            s['dropoffAllowed'] == true &&
            pickup != null &&
            (s['sequence'] as int) > (pickup['sequence'] as int))
        .toList();
    Widget selector(String label, String? value, List<Json> options,
            ValueChanged<String?> choose) =>
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InputDecorator(
                decoration: InputDecoration(
                    labelText: label, border: const OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                        isExpanded: true,
                        value:
                            options.any((s) => s['id'] == value) ? value : null,
                        hint: Text(label),
                        items: [
                          for (final s in options)
                            DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text(
                                    '${s['name']}${s['pickupTime'] == null ? '' : ' · ${s['pickupTime']}'}',
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: state.busy ? null : choose))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${trip.direction} · ${trip.json['variantCode']}'),
      selector(
          'Pickup stoppage', state.pickupStopId, pickups, state.choosePickup),
      if (trip.dropoffSupported)
        selector('Drop-off stoppage', state.dropoffStopId, drops,
            state.chooseDropoff)
      else
        const Text(
            'Official outbound drop-off stops are unspecified. No drop-off selection is supported.'),
      if (pickup != null)
        Text('Scheduled pickup: ${pickup['pickupTime']} (Asia/Dhaka)'),
    ]);
  }
}
