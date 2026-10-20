import 'dart:async';
import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/features/notifications/data/notification_repository_impl.dart';
import 'package:campushub/features/notifications/presentation/screens/notification_screen.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/shared/widgets/role_navigation_actions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import '../auth/auth_fakes.dart';

void main() {
  testWidgets('tap persists read and badge decreases through live inbox', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('notifications').doc('n1').set({
      'userId': 'u1',
      'title': 'Club joined',
      'body': 'You joined Sport.',
      'type': 'club_membership',
      'isRead': false,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
    });
    final repository = NotificationRepositoryImpl(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repository),
          currentUserProvider.overrideWith((ref) => Stream.value(testUser())),
          notificationInboxProvider.overrideWith(
            (ref) => repository.watchInbox('u1'),
          ),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              Material(child: RoleNavigationActions()),
              Expanded(child: NotificationScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 unread'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notification-n1')));
    await tester.pumpAndSettle();
    expect(
      (await db.collection('notifications').doc('n1').get()).data()?['isRead'],
      true,
    );
    expect(find.text('0 unread'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread only'));
    await tester.pumpAndSettle();
    expect(find.text('You are all caught up'), findsOneWidget);
  });

  testWidgets('loading, error retry and empty states are explicit', (
    tester,
  ) async {
    final controller = StreamController<List<AppNotification>>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxProvider.overrideWith((ref) => controller.stream),
          currentUserProvider.overrideWith((ref) => Stream.value(testUser())),
        ],
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.addError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    controller.add([]);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
  });
}
