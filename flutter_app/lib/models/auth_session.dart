enum TransportRole {
  authority,
  admin,
  driver,
  student;

  bool allows(TransportRole required) =>
      this == required || (this == admin && required == authority);

  String get label => switch (this) {
    authority => 'Authority',
    admin => 'Admin',
    driver => 'Driver',
    student => 'Student',
  };
}

/// Public server identity only. Cookies, roles or identities are never invented
/// from a local picker, and this object is not persisted as proof of login.
class AuthSession {
  const AuthSession({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.driverId,
  });

  factory AuthSession.fromJson(dynamic value) {
    if (value is! Map) throw const FormatException('Invalid identity');
    final id = value['id'], name = value['name'], email = value['email'];
    if ((id is! int && id is! String) ||
        '$id'.isEmpty ||
        name is! String ||
        name.isEmpty ||
        email is! String ||
        email.isEmpty) {
      throw const FormatException('Invalid identity');
    }
    final role = TransportRole.values
        .where((r) => r.name == value['role'])
        .firstOrNull;
    if (role == null) throw const FormatException('Unsupported role');
    final driverId = value['driver_id'];
    return AuthSession(
      id: '$id',
      name: name,
      email: email,
      role: role,
      driverId: driverId == null ? null : int.tryParse('$driverId'),
    );
  }

  final String id, name, email;
  final TransportRole role;
  final int? driverId;
}
