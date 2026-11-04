import 'package:flutter/material.dart';

import '../../models/booking.dart';
import '../../state/booking_state.dart';
import '../../widgets/booking_summary.dart';
import '../../widgets/seat_map.dart';

class StudentBookingScreen extends StatefulWidget {
  const StudentBookingScreen({
    super.key,
    required this.state,
    this.ticketBuilder,
  });
  final BookingState state;
  final ConfirmedTicketBuilder? ticketBuilder;
  @override
  State<StudentBookingScreen> createState() => _StudentBookingScreenState();
}

class _StudentBookingScreenState extends State<StudentBookingScreen>
    with WidgetsBindingObserver {
  int tab = 0;
  BookingState get state => widget.state;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) state.load();
  }

  Future<void> openDetails(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailsScreen(
          state: state,
          id: booking.id,
          ticketBuilder: widget.ticketBuilder,
        ),
      ),
    );
    await state.load();
    if (mounted) setState(() => tab = 2);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('BRACU Student Transport'),
            actions: [
              IconButton(
                onPressed: state.busy ? null : state.load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: state.busy
                ? null
                : (value) {
                    setState(() => tab = value);
                    if (value == 2) state.load();
                  },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_bus),
                label: 'Book Bus',
              ),
              NavigationDestination(
                  icon: Icon(Icons.history), label: 'History'),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: state.load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.loading) const LinearProgressIndicator(),
                if (state.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (state.uncertain)
                  const Text(
                    'Booking outcome is unknown. Check history before making another booking. Reopen this module only after verifying the outcome.',
                  ),
                if (tab == 0) ...[
                  Text(
                    'Plan your journey',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'All travel times use Asia/Dhaka. Booking eligibility and windows are controlled by the server.',
                  ),
                  FilledButton(
                    onPressed: () => setState(() => tab = 1),
                    child: const Text('Book Bus'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => tab = 2),
                    child: const Text('Booking History'),
                  ),
                ],
                if (tab == 1) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(state.date),
                    onPressed: state.busy
                        ? null
                        : () async {
                            final today = DateTime.parse(dhakaDate());
                            final chosen = await showDatePicker(
                              context: context,
                              initialDate: DateTime.parse(state.date),
                              firstDate: today,
                              lastDate: today.add(const Duration(days: 365)),
                            );
                            if (chosen != null)
                              await state.changeDate(
                                chosen.toIso8601String().substring(0, 10),
                              );
                          },
                  ),
                  if (!state.loading && state.trips.isEmpty)
                    const Text('No trips available for this date.'),
                  for (final trip in state.trips)
                    Card(
                      child: ListTile(
                        selected: state.availability?.trip.id == trip.id,
                        title: Text('${trip.bus} · ${trip.route}'),
                        subtitle: Text(
                          '${trip.time} · ${trip.json['bookingOpen'] == true ? 'Booking open' : 'Booking closed'}\nWindow: ${trip.json['opensAt']} – ${trip.json['closesAt']}',
                        ),
                        onTap: state.busy ? null : () => state.selectTrip(trip),
                      ),
                    ),
                  if (state.availability != null) ...[
                    SeatMap(state: state),
                    FilledButton(
                      onPressed: !state.busy && state.hasSelection
                          ? () async {
                              final result =
                                  await Navigator.of(context).push<Booking>(
                                MaterialPageRoute(
                                  builder: (_) => BookingReviewScreen(
                                    state: state,
                                    ticketBuilder: widget.ticketBuilder,
                                  ),
                                ),
                              );
                              if (result != null && mounted)
                                await openDetails(result);
                            }
                          : null,
                      child: const Text('Confirm Booking'),
                    ),
                  ],
                ],
                if (tab == 2) ...[
                  Text(
                    'Booking History',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  for (final section in ['Upcoming', 'Past', 'Cancelled']) ...[
                    Text(section,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (!state.history.any((b) => b.section == section))
                      const Text('No bookings.'),
                    for (final b in state.history.where(
                      (b) => b.section == section,
                    ))
                      Card(
                        child: ListTile(
                          title: Text('${b.trip.route} · #${b.id}'),
                          subtitle: Text(
                            '${b.date} ${b.trip.time} · ${b.place} · ${b.status}',
                          ),
                          onTap: () => openDetails(b),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
}

class BookingReviewScreen extends StatelessWidget {
  const BookingReviewScreen({
    super.key,
    required this.state,
    this.ticketBuilder,
  });
  final BookingState state;
  final ConfirmedTicketBuilder? ticketBuilder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final data = state.availability!;
          if (state.confirmed != null) {
            return PopScope(
              canPop: !state.busy,
              child: Scaffold(
                appBar: AppBar(title: const Text('Booking confirmed')),
                body: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    BookingSummary(
                      booking: state.confirmed!,
                      ticketBuilder: ticketBuilder,
                    ),
                    if (state.busy)
                      const Text('Refreshing availability and history…'),
                  ],
                ),
              ),
            );
          }
          return PopScope(
            canPop: !state.busy,
            child: Scaffold(
              appBar: AppBar(title: const Text('Review booking')),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    data.trip.route,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Trip: ${data.trip.id}\nBus: ${data.trip.bus}\nDeparture: ${state.date} ${data.trip.time} (Asia/Dhaka)\n${state.standing ? 'Standing' : 'Seat ${state.seat}'}',
                  ),
                  const Text(
                    'Fare: unavailable from current server response. No fare is submitted by this app.',
                  ),
                  const Text(
                    'Selection does not reserve capacity. Availability is confirmed by the server.',
                  ),
                  if (!data.open)
                    const Text('Booking is closed for this trip.'),
                  if (state.error != null)
                    Semantics(liveRegion: true, child: Text(state.error!)),
                  FilledButton(
                    onPressed: state.canSubmit
                        ? () async {
                            final booking = await state.submit();
                            if (booking != null && context.mounted)
                              Navigator.of(context).pop(booking);
                          }
                        : null,
                    child: Text(state.busy ? 'Booking…' : 'Confirm & Book'),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.state,
    required this.id,
    this.ticketBuilder,
  });
  final BookingState state;
  final String id;
  final ConfirmedTicketBuilder? ticketBuilder;
  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen>
    with WidgetsBindingObserver {
  Booking? booking;
  bool loading = true;
  int version = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    final current = ++version;
    setState(() {
      loading = true;
      booking = null;
    });
    final value = await widget.state.details(widget.id);
    if (mounted && version == current)
      setState(() {
        booking = value;
        loading = false;
      });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Booking details'),
            actions: [
              IconButton(
                onPressed: widget.state.busy ? null : reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (loading) const LinearProgressIndicator(),
              if (widget.state.error != null) Text(widget.state.error!),
              if (!loading && booking == null)
                TextButton(onPressed: reload, child: const Text('Retry')),
              if (booking != null) ...[
                if (booking!.status == 'confirmed')
                  const Text(
                    'Booking confirmed',
                    semanticsLabel: 'Booking confirmed successfully',
                  ),
                BookingSummary(
                  booking: widget.state.history
                          .where(
                            (b) => b.id == widget.id && b.status == 'cancelled',
                          )
                          .firstOrNull ??
                      booking!,
                  ticketBuilder: widget.ticketBuilder,
                ),
                if (booking!.section == 'Upcoming' &&
                    booking!.status == 'confirmed')
                  OutlinedButton(
                    onPressed: widget.state.busy
                        ? null
                        : () async {
                            final cancel = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel this booking?'),
                                content:
                                    const Text('Your seat will be released.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Keep booking'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Cancel booking'),
                                  ),
                                ],
                              ),
                            );
                            if (cancel == true) {
                              final result =
                                  await widget.state.cancel(widget.id);
                              if (mounted && result != null)
                                setState(() => booking = result);
                            }
                          },
                    child: Text(
                      widget.state.busy ? 'Cancelling…' : 'Cancel booking',
                    ),
                  ),
                TextButton(
                  onPressed:
                      widget.state.busy ? null : () => Navigator.pop(context),
                  child: const Text('Back to Booking History'),
                ),
              ],
            ],
          ),
        ),
      );
}
