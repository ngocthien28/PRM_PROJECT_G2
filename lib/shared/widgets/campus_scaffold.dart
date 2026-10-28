import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_theme.dart';

enum CampusSection { home, clubs, inbox, admin, moderation, events, myEvents }

String campusHome(String role) => role == 'admin'
    ? RouteNames.admin
    : role == 'organizer'
    ? RouteNames.organizer
    : RouteNames.home;

class CampusScaffold extends ConsumerWidget {
  const CampusScaffold({
    super.key,
    required this.title,
    required this.section,
    required this.body,
    this.role = 'student',
    this.userName = 'Campus member',
    this.actions = const [],
    this.onBack,
    this.onSignOut,
    this.signingOut = false,
    this.unreadCount = 0,
    this.signOutKey,
    this.sidebarWidth = 232,
    this.floatingActionButton,
    this.onBeforeNavigate,
  });
  final Key? signOutKey;
  final double sidebarWidth;
  final int unreadCount;
  final String title, role, userName;
  final CampusSection section;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onBack, onSignOut;
  final bool signingOut;
  final Widget? floatingActionButton;
  final Future<bool> Function()? onBeforeNavigate;

  List<(String, IconData, CampusSection, String)> get destinations => [
    (
      role == 'admin'
          ? 'Overview'
          : role == 'organizer'
          ? 'Workspace'
          : 'Discover',
      Icons.space_dashboard_outlined,
      role == 'admin' ? CampusSection.admin : CampusSection.home,
      role == 'admin'
          ? RouteNames.admin
          : role == 'organizer'
          ? RouteNames.organizer
          : RouteNames.home,
    ),
    if (role == 'admin')
      (
        'Manage Events',
        Icons.event_note_outlined,
        CampusSection.events,
        RouteNames.organizerManagedEvents,
      ),
    if (role == 'student')
      (
        'My Events',
        Icons.confirmation_number_outlined,
        CampusSection.myEvents,
        RouteNames.myEvents,
      ),
    ('Clubs', Icons.groups_outlined, CampusSection.clubs, RouteNames.clubs),
    (
      'Notifications',
      Icons.notifications_outlined,
      CampusSection.inbox,
      RouteNames.notifications,
    ),
    if (role == 'admin')
      (
        'Moderation',
        Icons.verified_user_outlined,
        CampusSection.moderation,
        RouteNames.moderation,
      ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signOutBusy =
        signingOut || ref.watch(authViewModelProvider).isLoading;
    final VoidCallback signOutAction =
        onSignOut ??
        () async {
          if (onBeforeNavigate != null && !await onBeforeNavigate!()) return;
          if (!context.mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Sign out?'),
              content: const Text('You can sign in again whenever you like.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          await ref.read(authViewModelProvider.notifier).signOut();
          if (!context.mounted) return;
          final result = ref.read(authViewModelProvider);
          if (result.hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not sign out. Please try again.'),
              ),
            );
          } else {
            GoRouter.maybeOf(context)?.go(RouteNames.login);
          }
        };
    final wide = MediaQuery.sizeOf(context).width >= 1120;
    final selected = destinations.indexWhere((d) => d.$3 == section);
    Future<void> navigate(int index) async {
      if (onBeforeNavigate != null && !await onBeforeNavigate!()) return;
      if (!context.mounted) return;
      final router = GoRouter.maybeOf(context);
      final target = destinations[index].$4;
      router?.go(target);
    }

    final header = LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final compact = availableWidth < 600;
        final veryCompact = availableWidth < 450;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 12,
            vertical: 12,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: CampusColors.line)),
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
              ],
              if (!wide && onBack == null) ...[
                const _BrandMark(size: 34),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: wide ? 19 : 17),
                ),
              ),
              if (veryCompact) ...actions.take(1) else ...actions,
              if (!wide)
                compact
                    ? IconButton(
                        key: signOutKey,
                        tooltip: 'Sign out',
                        onPressed: signOutBusy ? null : signOutAction,
                        icon: signOutBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout_rounded, size: 20),
                      )
                    : TextButton.icon(
                        key: signOutKey,
                        onPressed: signOutBusy ? null : signOutAction,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign out'),
                      ),
            ],
          ),
        );
      },
    );
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (wide)
              Container(
                width: sidebarWidth,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: CampusColors.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 28, 16, 30),
                      child: Row(
                        children: [
                          const _BrandMark(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'campushub',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontSize: 22,
                                        letterSpacing: -1,
                                      ),
                                ),
                                const Text(
                                  'YOUR CAMPUS. YOUR PEOPLE.',
                                  style: TextStyle(
                                    fontSize: 8,
                                    letterSpacing: 1.2,
                                    color: CampusColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 10,
                      ),
                      child: Text(
                        'WORKSPACE',
                        style: TextStyle(
                          fontSize: 10,
                          color: CampusColors.muted,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (var i = 0; i < destinations.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: Material(
                          color: i == selected
                              ? CampusColors.mint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(
                              destinations[i].$2,
                              size: 21,
                              color: i == selected
                                  ? CampusColors.teal
                                  : CampusColors.muted,
                            ),
                            title: Text(
                              destinations[i].$1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: i == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == selected
                                    ? CampusColors.teal
                                    : CampusColors.ink,
                              ),
                            ),
                            trailing:
                                destinations[i].$3 == CampusSection.inbox &&
                                    unreadCount > 0
                                ? Badge(label: Text('$unreadCount'))
                                : i == selected
                                ? Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: CampusColors.teal,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                            onTap: () => navigate(i),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (MediaQuery.sizeOf(context).height > 920)
                      Container(
                        margin: const EdgeInsets.all(18),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CampusColors.canvas,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              size: 24,
                              color: CampusColors.teal,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'More than a campus.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'A place to find your people\nand make things happen.',
                              style: TextStyle(
                                fontSize: 11,
                                color: CampusColors.muted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: CampusColors.mint,
                            child: Text(
                              userName.trim().isEmpty
                                  ? 'C'
                                  : userName
                                        .trim()
                                        .substring(0, 1)
                                        .toUpperCase(),
                              style: const TextStyle(
                                color: CampusColors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  role == 'admin'
                                      ? 'Administrator'
                                      : role == 'organizer'
                                      ? 'Organizer'
                                      : 'Student',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: CampusColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: signOutKey,
                            tooltip: 'Sign out',
                            onPressed: signOutBusy ? null : signOutAction,
                            icon: const Icon(Icons.logout_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  header,
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 66,
              labelBehavior: destinations.length > 4
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: navigate,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    tooltip: d.$1,
                    icon: Badge(
                      isLabelVisible:
                          d.$3 == CampusSection.inbox && unreadCount > 0,
                      label: Text('$unreadCount'),
                      child: Icon(d.$2, size: 22),
                    ),
                    label: d.$1 == 'Notifications'
                        ? 'Inbox'
                        : d.$1 == 'Manage Events'
                        ? 'Events'
                        : d.$1,
                  ),
              ],
            ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 38});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: CampusColors.teal,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(Icons.hub_outlined, size: size * .63, color: Colors.white),
  );
}

class CampusPage extends StatelessWidget {
  const CampusPage({super.key, required this.children, this.maxWidth = 1200});
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 18 : 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: const TextStyle(color: CampusColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class CampusEmptyState extends StatelessWidget {
  const CampusEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: CampusColors.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: const BoxDecoration(
            color: CampusColors.mint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: CampusColors.teal, size: 34),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            message,
            style: const TextStyle(color: CampusColors.muted, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 22), action!],
      ],
    ),
  );
}

class CampusArtwork extends StatelessWidget {
  const CampusArtwork({super.key, this.color = CampusColors.gold});
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CampusPainter(color),
    child: const SizedBox.expand(),
  );
}

class _CampusPainter extends CustomPainter {
  _CampusPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final scale = size.width / 340;
    canvas.save();
    canvas.scale(scale);
    final h = size.height / scale;
    final line = Paint()
      ..color = color.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(190, h * .48), 62 + i * 25, line);
    }
    final fill = Paint()..color = color;
    canvas.drawCircle(Offset(250, h * .2), 19, fill);
    final arch = Path()
      ..moveTo(100, h - 28)
      ..lineTo(100, h * .48)
      ..arcToPoint(Offset(240, h * .48), radius: const Radius.circular(70))
      ..lineTo(240, h - 28)
      ..close();
    fill.color = color.withValues(alpha: .16);
    canvas.drawPath(arch, fill);
    line.color = color.withValues(alpha: .65);
    line.strokeWidth = 2;
    canvas.drawPath(arch, line);
    for (var x = 120; x < 240; x += 25) {
      canvas.drawLine(
        Offset(x.toDouble(), h * .53),
        Offset(x.toDouble(), h - 28),
        line..color = color.withValues(alpha: .22),
      );
    }
    fill.color = const Color(0xFF8EB7A0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(54, h - 105, 58, 77),
        const Radius.circular(29),
      ),
      fill,
    );
    canvas.drawLine(
      Offset(83, h - 67),
      Offset(83, h - 9),
      Paint()
        ..color = color.withValues(alpha: .6)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(35, h - 27),
      Offset(294, h - 27),
      Paint()
        ..color = color.withValues(alpha: .4)
        ..strokeWidth = 1.5,
    );
    final star = Path()
      ..moveTo(51, h * .2)
      ..lineTo(55, h * .2 + 10)
      ..lineTo(65, h * .2 + 14)
      ..lineTo(55, h * .2 + 18)
      ..lineTo(51, h * .2 + 28)
      ..lineTo(47, h * .2 + 18)
      ..lineTo(37, h * .2 + 14)
      ..lineTo(47, h * .2 + 10)
      ..close();
    fill.color = color;
    canvas.drawPath(star, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CampusPainter oldDelegate) => color != oldDelegate.color;
}
