import 'package:campushub/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:campushub/features/admin/data/admin_repository.dart';
import 'package:campushub/features/admin/presentation/viewmodels/admin_dashboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import '../auth/auth_fakes.dart';

void main() {
  testWidgets('admin dashboard exposes Club and Notification navigation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/admin',
      routes: [
        GoRoute(
          path: '/admin',
          builder: (_, _) => ProviderScope(
            overrides: [
              adminStatsProvider.overrideWith(_adminStats),
              currentUserProvider.overrideWith(
                (ref) => Stream.value(testUser(role: UserRole.admin)),
              ),
              notificationInboxProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: const AdminDashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/clubs',
          builder: (_, _) => const Scaffold(body: Text('Club destination')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) =>
              const Scaffold(body: Text('Notification destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clubs'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);

    await tester.tap(find.byTooltip('Clubs'));
    await tester.pumpAndSettle();
    expect(find.text('Club destination'), findsOneWidget);
    expect(router.canPop(), isFalse);
    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Admin Dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notification destination'), findsOneWidget);
    expect(router.canPop(), isFalse);
    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Admin Dashboard'), findsOneWidget);
  });
}

Future<AdminStats> _adminStats(Ref ref) async => const AdminStats(
  userCount: 2,
  clubCount: 1,
  eventCount: 3,
  activeMembershipCount: 1,
);
