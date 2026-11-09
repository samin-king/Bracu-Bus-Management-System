import 'package:flutter/widgets.dart';
import '../services/member4_api.dart';

/// A host-provided session boundary; this widget does not authenticate anyone.
class Member4Session extends InheritedWidget {
  const Member4Session({super.key, required this.api, required this.role,
    required this.authenticated, required this.sessionKey, required super.child});
  final Member4Api api;
  final String? role;
  final bool authenticated;
  /// Stable for one signed-in account. Change on sign-out or account switch,
  /// even when the host reuses the same HTTP client/API instance.
  final Object sessionKey;
  static Member4Session of(BuildContext context) {
    final session = context.dependOnInheritedWidgetOfExactType<Member4Session>();
    if (session == null) {
      throw FlutterError('Wrap the host Navigator with Member4Session.');
    }
    return session;
  }
  bool get student => authenticated && role == 'student';
  bool get management => authenticated && ['authority', 'admin'].contains(role);
  @override
  bool updateShouldNotify(Member4Session oldWidget) => api != oldWidget.api ||
      role != oldWidget.role || authenticated != oldWidget.authenticated ||
      sessionKey != oldWidget.sessionKey;
}
