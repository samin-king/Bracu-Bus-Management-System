typedef Json = Map<String, dynamic>;

class Trip {
  Trip(this.json);
  final Json json;
  String get id => json['id'].toString();
  String get route => json['route'] as String;
  String get bus => json['bus'] as String;
  String get time => json['departureTime'] as String;
}

class Availability {
  Availability(this.json);
  final Json json;
  Trip get trip => Trip(json['trip'] as Json);
  bool get open => json['bookingOpen'] == true;
  bool get genderKnown => json['genderKnown'] == true;
  int get standing => json['standingAvailable'] as int;
  List<Json> get seats => (json['seats'] as List).cast<Json>();
  bool selectable(int seat) =>
      seats.any((s) => s['number'] == seat && s['selectable'] == true);
}

class Booking {
  Booking(this.json);
  final Json json;
  String get id => json['id'].toString();
  Trip get trip =>
      Trip({...json['trip_snapshot'] as Json, 'id': json['trip_id']});
  String get date => json['travel_date'] as String;
  String get place =>
      json['standing'] == true ? 'Standing' : 'Seat ${json['seat_number']}';
  String get status => json['status'] as String;
  String get section => json['section'] as String;
  // The current API has no fare or QR fields. Never derive a QR from an ID.
  String get fare =>
      json['fare'] == null ? 'Unavailable from server' : 'BDT ${json['fare']}';
}

String dhakaDate([DateTime? now]) => (now ?? DateTime.now())
    .toUtc()
    .add(const Duration(hours: 6))
    .toIso8601String()
    .substring(0, 10);
