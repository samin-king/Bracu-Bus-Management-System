import 'package:flutter/material.dart';

abstract final class TransportColors {
  static const navy = Color(0xff102747);
  static const blue = Color(0xff315de4);
  static const gold = Color(0xffd9b65c);
  static const background = Color(0xfff4f7fc);
  static const border = Color(0xffe4eaf2);
  static const muted = Color(0xff738198);
}

abstract final class TransportTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: TransportColors.blue,
      primary: TransportColors.blue,
      secondary: TransportColors.navy,
      surface: Colors.white,
      onSurface: TransportColors.navy,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: TransportColors.background,
      dividerColor: TransportColors.border,
      textTheme:
          const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              height: 1.15,
            ),
            headlineMedium: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
            ),
            titleLarge: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -.3,
            ),
            titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(fontSize: 15, height: 1.6),
            bodyMedium: TextStyle(fontSize: 13, height: 1.6),
            bodySmall: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: TransportColors.muted,
            ),
            labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ).apply(
            bodyColor: TransportColors.navy,
            displayColor: TransportColors.navy,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TransportColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: TransportColors.navy,
          letterSpacing: -.7,
        ),
        iconTheme: IconThemeData(color: TransportColors.muted),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: TransportColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(fontSize: 13, color: TransportColors.muted),
        prefixIconColor: TransportColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TransportColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TransportColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TransportColors.blue, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(40, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 44),
          side: const BorderSide(color: TransportColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: TransportColors.blue,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: TransportColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xfff8faff)),
        headingTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: TransportColors.muted,
        ),
        dataTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: TransportColors.navy,
        ),
        dataRowMinHeight: 76,
        dataRowMaxHeight: 86,
        headingRowHeight: 48,
        dividerThickness: .7,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TransportColors.blue,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.compact = false});
  final bool light, compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: light
              ? Colors.white.withValues(alpha: .10)
              : TransportColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.directions_bus_filled_rounded,
          color: Colors.white,
          size: 23,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BRACU Transport',
              style: TextStyle(
                fontFamily: 'Inter',
                color: light ? Colors.white : TransportColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
            Text(
              'UNIVERSITY MOBILITY',
              style: TextStyle(
                fontFamily: 'Inter',
                color: light ? const Color(0xffa8b8ce) : TransportColors.muted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ACTIVE' ||
      'CONFIRMED' ||
      'PUBLISHED' ||
      'RESOLVED' => const Color(0xff167454),
      'COMPLETED' => TransportColors.blue,
      'INACTIVE' || 'CANCELLED' => const Color(0xff69778e),
      'MAINTENANCE' || 'OPEN' || 'IN_REVIEW' => const Color(0xff9c7020),
      _ => TransportColors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }
}

IconData moduleIcon(String name) => switch (name) {
  'Dashboard' => Icons.space_dashboard_outlined,
  'Student Profile' || 'Driver Profile' => Icons.person_outline_rounded,
  'Bus Booking' => Icons.confirmation_number_outlined,
  'Booking History' => Icons.history_rounded,
  'Bus Management' => Icons.directions_bus_outlined,
  'Route Management' => Icons.alt_route_rounded,
  'Trip Management' || 'Trip Schedule' => Icons.calendar_month_outlined,
  'Driver Management' => Icons.badge_outlined,
  'Driver Assignment' => Icons.assignment_ind_outlined,
  'Assigned Trips' => Icons.route_outlined,
  'Passenger List' => Icons.groups_outlined,
  'Complaints' || 'Complaints Management' => Icons.chat_bubble_outline_rounded,
  'Feedback' => Icons.rate_review_outlined,
  _ => Icons.notifications_none_rounded,
};

class HoverCard extends StatefulWidget {
  const HoverCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.translationValues(0, hover ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hover ? const Color(0xffc2d0f8) : TransportColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: TransportColors.navy.withValues(alpha: hover ? .07 : .025),
            blurRadius: hover ? 22 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: widget.child,
        ),
      ),
    ),
  );
}

class PolishedState extends StatelessWidget {
  const PolishedState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xffeaf0ff),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: TransportColors.blue, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: TransportColors.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}
