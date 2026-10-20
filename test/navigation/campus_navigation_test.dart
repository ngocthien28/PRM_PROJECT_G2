import 'package:campushub/shared/widgets/campus_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:campushub/features/clubs/presentation/screens/club_list_screen.dart';
import 'package:campushub/features/clubs/presentation/viewmodels/club_view_model.dart';
import 'package:campushub/features/notifications/presentation/screens/notification_screen.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import '../auth/auth_fakes.dart';

void main() {
  for (final role in ['student', 'admin']) {
    testWidgets('$role Back from clubs and inbox skips navigation history', (tester) async {
      final root = role == 'admin' ? '/admin' : '/home';
      final router = GoRouter(initialLocation: root, routes: [
        GoRoute(path: root, builder: (_, _) => const Scaffold(body: Text('Root page'))),
        GoRoute(path: '/clubs', builder: (_, _) => const ClubListScreen()),
        GoRoute(path: '/notifications', builder: (_, _) => const NotificationScreen()),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(testUser(role: role == 'admin' ? UserRole.admin : UserRole.student))),
        clubsProvider.overrideWith((ref) => Stream.value([])),
        notificationInboxProvider.overrideWith((ref) => Stream.value([])),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      for (final target in ['/clubs', '/notifications']) {
        router.push(target == '/clubs' ? '/notifications' : '/clubs');
        await tester.pumpAndSettle();
        router.push(target);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Root page'), findsOneWidget);
        expect(router.canPop(), isFalse);
      }
    });
    testWidgets('$role can return to root after opening clubs and inbox', (
      tester,
    ) async {
      final root = role == 'admin' ? '/admin' : '/home';
      final label = role == 'admin' ? 'Overview' : 'Discover';
      final router = GoRouter(
        initialLocation: root,
        routes: [
          for (final path in [root, '/clubs', '/notifications'])
            GoRoute(
              path: path,
              builder: (_, _) => CampusScaffold(
                title: path,
                role: role,
                section: path == '/clubs'
                    ? CampusSection.clubs
                    : path == '/notifications'
                    ? CampusSection.inbox
                    : role == 'admin'
                    ? CampusSection.admin
                    : CampusSection.home,
                body: Text('page:$path'),
              ),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      router.push('/clubs');
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.text('page:$root'), findsOneWidget);
      await tester.tap(find.text('Clubs').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inbox').last);
      await tester.pumpAndSettle();
      expect(find.text('page:/notifications'), findsOneWidget);
      expect(
        router.canPop(),
        isFalse,
        reason: 'Top-level destinations must not accumulate history',
      );
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
    });
  }
}
