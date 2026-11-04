import 'package:flutter/material.dart';

import '../state/booking_state.dart';

class SeatMap extends StatelessWidget {
  const SeatMap({super.key, required this.state});
  final BookingState state;
  @override
  Widget build(BuildContext context) {
    final data = state.availability!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.trip.bus} · ${data.trip.route}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Departure ${data.trip.time} · Asia/Dhaka'),
        Text(
          data.open
              ? 'Booking open'
              : 'Booking closed. You may review your selection.',
        ),
        if (!data.genderKnown)
          const Text(
            'Profile gender unverified. Reserved seats and standing are unavailable.',
          ),
        const Text('Available · Reserved · Booked · Selected'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            for (final seat in data.seats)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Semantics(
                  selected: state.seat == seat['number'],
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: state.seat == seat['number']
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    onPressed: !state.busy && seat['selectable'] == true
                        ? () => state.selectSeat(seat['number'] as int)
                        : null,
                    child: Text(
                      '${seat['number']}\n${state.seat == seat['number'] ? 'Selected' : seat['state']}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (data.standing > 0)
          ChoiceChip(
            label: Text('Standing · ${data.standing} available'),
            selected: state.standing,
            onSelected: state.busy ? null : (_) => state.selectStanding(),
          ),
      ],
    );
  }
}
