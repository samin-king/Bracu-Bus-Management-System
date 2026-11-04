import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import '../services/student_api.dart';

class BookingState extends ChangeNotifier {
  BookingState(this.api);
  final StudentApi api;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String date = dhakaDate();
  List<Trip> trips = [];
  List<Booking> history = [];
  Availability? availability;
  Booking? confirmed;
  int? seat;
  bool standing = false, busy = false, loading = false;
  bool uncertain = false;
  String? error;
  int _generation = 0;
  bool get hasSelection => seat != null || standing;
  bool get canSubmit =>
      hasSelection &&
      availability?.open == true &&
      !busy &&
      !uncertain &&
      confirmed == null;

  Future<void> load() async {
    if (busy) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final selectedTrip = availability?.trip.id;
      final results = await Future.wait<Object>([
        api.trips(date),
        api.bookings(),
        if (selectedTrip != null) api.seats(selectedTrip, date),
      ]);
      if (generation != _generation) return;
      trips = results[0] as List<Trip>;
      history = results[1] as List<Booking>;
      if (results.length > 2) {
        availability = results[2] as Availability;
        if (standing
            ? availability!.standing <= 0
            : seat != null && !availability!.selectable(seat!))
          clearSelection();
      }
      if (confirmed != null) {
        confirmed = history.where((b) => b.id == confirmed!.id).firstOrNull;
      }
    } catch (e) {
      if (generation == _generation) error = e.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> changeDate(String value) async {
    if (busy) return;
    date = value;
    availability = null;
    clearSelection();
    confirmed = null;
    await load();
  }

  void clearSelection() {
    seat = null;
    standing = false;
  }

  Future<void> selectTrip(Trip trip) async {
    if (busy) return;
    final generation = ++_generation;
    clearSelection();
    availability = null;
    confirmed = null;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.seats(trip.id, date);
      if (generation == _generation) availability = result;
    } catch (e) {
      if (generation == _generation) error = e.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void selectSeat(int number) {
    if (busy || availability?.selectable(number) != true) return;
    seat = number;
    standing = false;
    notifyListeners();
  }

  void selectStanding() {
    if (busy || (availability?.standing ?? 0) <= 0) return;
    seat = null;
    standing = true;
    notifyListeners();
  }

  Future<void> _refreshAvailability() async {
    final current = availability;
    if (current != null) availability = await api.seats(current.trip.id, date);
  }

  Future<Booking?> submit() async {
    if (!canSubmit) return null;
    busy = true;
    error = null;
    notifyListeners();
    Booking? result;
    try {
      // Recheck server availability/window, without implementing local rules.
      await _refreshAvailability();
      if (!availability!.open) throw ApiFailure('booking_window_closed');
      if (standing
          ? availability!.standing <= 0
          : !availability!.selectable(seat!))
        throw ApiFailure('booking_conflict');
      result = await api.book({
        'tripId': availability!.trip.id,
        'travelDate': date,
        'seatNumber': seat,
        'standing': standing,
      });
      confirmed = result;
      clearSelection();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      // No automatic retry for an uncertain POST outcome.
      if (e is ApiFailure && e.code == 'network') uncertain = true;
    }
    try {
      await _refreshAvailability();
      history = await api.bookings();
    } catch (e) {
      error = '${error == null ? '' : '${error!}\n'}Refresh failed: $e';
    }
    busy = false;
    notifyListeners();
    return result;
  }

  Future<Booking?> details(String id) async {
    try {
      return await api.booking(id);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Booking?> cancel(String id) async {
    if (busy) return null;
    busy = true;
    error = null;
    notifyListeners();
    Booking? result;
    try {
      result = await api.cancel(id);
      history = history.map((b) => b.id == id ? result! : b).toList();
      if (confirmed?.id == id) confirmed = result;
      notifyListeners(); // Remove ticket immediately, even if refresh fails.
      await _refreshAvailability();
      history = await api.bookings();
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
    return result;
  }
}
