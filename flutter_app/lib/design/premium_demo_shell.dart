import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'transport_theme.dart';
import 'campus_illustration.dart';

class PremiumDemoShell extends StatelessWidget {
  const PremiumDemoShell({
    super.key,
    required this.role,
    required this.modules,
    required this.selected,
    required this.viewState,
    required this.navigationKey,
    required this.content,
    required this.login,
    required this.logout,
    required this.openModule,
    required this.changeViewState,
  });
  final TransportRole? role;
  final List<String> modules;
  final String selected, viewState;
  final Object navigationKey;
  final WidgetBuilder content;
  final ValueChanged<TransportRole> login;
  final VoidCallback logout;
  final ValueChanged<String> openModule, changeViewState;
  String get roleName =>
      role == null ? '' : role!.name[0].toUpperCase() + role!.name.substring(1);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final desktop = bounds.maxWidth >= 1000;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          toolbarHeight: 76,
          title: BrandMark(compact: bounds.maxWidth < 400),
          titleSpacing: desktop ? 28 : 16,
          actions: [
            if (role == null && bounds.maxWidth > 700)
              const Padding(
                padding: EdgeInsets.only(right: 32),
                child: Text(
                  'A better way to move through campus.',
                  style: TextStyle(fontSize: 12, color: TransportColors.muted),
                ),
              ),
            if (role != null) ...[
              if (bounds.maxWidth > 600)
                TextButton(
                  onPressed: () => openModule(
                    role == TransportRole.student
                        ? 'Student Profile'
                        : role == TransportRole.driver
                        ? 'Driver Profile'
                        : 'Dashboard',
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xffedf2ff),
                        child: Icon(
                          role == TransportRole.student
                              ? Icons.school_outlined
                              : role == TransportRole.driver
                              ? Icons.badge_outlined
                              : Icons.admin_panel_settings_outlined,
                          size: 17,
                          color: TransportColors.blue,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Demo $roleName',
                        style: const TextStyle(
                          color: TransportColors.navy,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: logout,
                icon: const Icon(Icons.logout_rounded, size: 17),
                label: const Text('Logout'),
              ),
              const SizedBox(width: 12),
            ],
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: TransportColors.border),
          ),
        ),
        body: Column(
          children: [
            _demoBanner(context),
            Expanded(
              child: role == null
                  ? PremiumLogin(login: login)
                  : Row(
                      children: [
                        if (desktop) _sidebar(),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              desktop ? 28 : 12,
                              desktop ? 18 : 10,
                              desktop ? 28 : 12,
                              0,
                            ),
                            child: Column(
                              children: [
                                if (desktop)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.home_outlined,
                                          size: 15,
                                          color: TransportColors.muted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$roleName workspace',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: TransportColors.muted,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 9,
                                          ),
                                          child: Icon(
                                            Icons.chevron_right_rounded,
                                            size: 15,
                                            color: TransportColors.muted,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            selected,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.circle,
                                          size: 5,
                                          color: Color(0xff228965),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Local workspace',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: TransportColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey(selected),
                                      initialValue: selected,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Module',
                                        prefixIcon: Icon(
                                          Icons.grid_view_rounded,
                                          size: 18,
                                        ),
                                      ),
                                      items: modules
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m,
                                              child: Text(m),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (m) => openModule(m!),
                                    ),
                                  ),
                                Expanded(
                                  child: Semantics(
                                    container: true,
                                    explicitChildNodes: true,
                                    child: Navigator(
                                      key: ValueKey(navigationKey),
                                      onGenerateRoute: (_) => PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => content(context),
                                        transitionDuration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) => FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _demoBanner(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Color(0xfffff9e9),
      border: Border(bottom: BorderSide(color: Color(0xffefe5c9))),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    child: LayoutBuilder(
      builder: (context, bounds) => Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.science_outlined,
                size: 17,
                color: Color(0xff987b30),
              ),
              const SizedBox(width: 8),
              Text(
                'DEMO MODE${role == null ? '' : ' · Demo $roleName'}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff876b28),
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
          const Text(
            'Synthetic data · Local writes only · Not Google authenticated',
            style: TextStyle(fontSize: 10, color: Color(0xff8a805f)),
          ),
          if (role != null)
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                key: ValueKey(viewState),
                initialValue: viewState,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Demo UI state',
                  isDense: true,
                  fillColor: Color(0xfffffcf4),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: TransportColors.navy,
                ),
                items: ['Normal', 'Loading', 'Empty', 'Error']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (s) => changeViewState(s!),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _sidebar() => Container(
    width: 244,
    color: TransportColors.navy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 27, 16, 8),
          child: Text(
            '$roleName workspace',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 16, 24),
          child: Text(
            'Your campus. Your journey.',
            style: TextStyle(fontSize: 10, color: Color(0xff9daec5)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 16, 10),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.7,
              color: Color(0xff728ba9),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final name in modules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: BoxDecoration(
                      color: selected == name
                          ? const Color(0xff284875)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        dense: true,
                        minLeadingWidth: 20,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 3,
                        ),
                        leading: Icon(
                          moduleIcon(name),
                          size: 19,
                          color: selected == name
                              ? Colors.white
                              : const Color(0xff91a7c3),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected == name
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected == name
                                ? Colors.white
                                : const Color(0xffb7c5d8),
                          ),
                        ),
                        trailing: selected == name
                            ? Container(
                                width: 4,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: TransportColors.gold,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              )
                            : null,
                        onTap: () => openModule(name),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: TransportColors.gold,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A safe space to explore',
                      style: TextStyle(
                        color: Color(0xffd8e3f1),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Local data resets on refresh.',
                      style: TextStyle(color: Color(0xff8fa5c1), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PremiumLogin extends StatelessWidget {
  const PremiumLogin({super.key, required this.login});
  final ValueChanged<TransportRole> login;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 1000;
      final card = Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: EdgeInsets.all(wide ? 32 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: TransportColors.border),
          boxShadow: [
            BoxShadow(
              color: TransportColors.navy.withValues(alpha: .055),
              blurRadius: 45,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xffedf2ff),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'EXPLORE YOUR WORKSPACE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: TransportColors.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Local Demo Login',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'One connected platform. Choose your role to discover a better campus commute.',
              style: TextStyle(
                color: TransportColors.muted,
                fontSize: 12,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 26),
            for (final role in [
              TransportRole.student,
              TransportRole.driver,
              TransportRole.authority,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RoleOption(role: role, onTap: () => login(role)),
              ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 18),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: TransportColors.muted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No Google login required. All records are synthetic and changes stay in this browser tab.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.7,
                      color: TransportColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      final hero = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SizedBox(
                width: 24,
                child: Divider(color: TransportColors.gold, thickness: 2),
              ),
              SizedBox(width: 10),
              Text(
                'BUILT FOR THE BRACU COMMUNITY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: TransportColors.muted,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Text(
            'Your campus.\nYour journey.\nBeautifully connected.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: wide ? 43 : 32,
              fontWeight: FontWeight.w700,
              color: TransportColors.navy,
              height: 1.19,
              letterSpacing: -1.6,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'From your first stop to your next class.\nA simpler, more thoughtful way to move with BRACU.',
            style: TextStyle(
              color: TransportColors.muted,
              fontSize: 12,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 18),
          const CampusIllustration(),
          const Wrap(
            spacing: 21,
            runSpacing: 10,
            children: [
              _TrustItem(Icons.route_outlined, 'Connected routes'),
              _TrustItem(Icons.event_seat_outlined, 'Easier bookings'),
              _TrustItem(Icons.groups_outlined, 'One community'),
            ],
          ),
        ],
      );
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1220),
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 36 : 20,
                vertical: wide ? 42 : 28,
              ),
              child: Column(
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: hero),
                        const SizedBox(width: 72),
                        card,
                      ],
                    )
                  else ...[
                    card,
                    const SizedBox(height: 36),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: hero,
                    ),
                  ],
                  const SizedBox(height: 40),
                  const Text(
                    'BRACU TRANSPORT  /  UNIVERSITY MOBILITY, REIMAGINED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      color: TransportColors.muted,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: TransportColors.blue),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: TransportColors.muted,
        ),
      ),
    ],
  );
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.role, required this.onTap});
  final TransportRole role;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final name = 'Demo ${role.name[0].toUpperCase()}${role.name.substring(1)}';
    return Semantics(
      button: true,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: HoverCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xffedf2ff),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  switch (role) {
                    TransportRole.student => Icons.school_outlined,
                    TransportRole.driver => Icons.directions_bus_outlined,
                    _ => Icons.admin_panel_settings_outlined,
                  },
                  color: TransportColors.blue,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      switch (role) {
                        TransportRole.student =>
                          'Book, travel and stay informed',
                        TransportRole.driver =>
                          'Your trips. Your route. Your day.',
                        _ => 'Keep campus moving, effortlessly',
                      },
                      style: const TextStyle(
                        fontSize: 9,
                        color: TransportColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: TransportColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
