import 'package:campushub/features/admin/data/models/moderation_case.dart';
import 'package:campushub/features/admin/data/moderation_repository.dart';
import 'package:campushub/features/admin/presentation/screens/moderation_screen.dart';
import 'package:campushub/features/admin/presentation/viewmodels/moderation_view_model.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';

void main() {
  testWidgets('admin can review a pending case in a desktop-sized window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeModerationRepository([_pendingCase()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (_) => Stream.value(testUser(uid: 'admin-1', role: UserRole.admin)),
          ),
          notificationInboxProvider.overrideWith((_) => Stream.value([])),
          moderationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review with context and confidence.'), findsOneWidget);
    expect(find.text('Club information needs review'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-case-case-1')));
    await tester.pumpAndSettle();

    expect(find.text('Review moderation case'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('moderation-note')),
      'Reviewed the club information and contacted its owner.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-moderation-decision')));
    await tester.pumpAndSettle();

    expect(repository.lastCaseId, 'case-1');
    expect(repository.lastActorId, 'admin-1');
    expect(repository.lastAction, ModerationAction.resolve);
    expect(find.text('Resolve issue saved.'), findsOneWidget);
  });

  testWidgets('case card remains usable in a narrow Windows window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (_) => Stream.value(testUser(uid: 'admin-1', role: UserRole.admin)),
          ),
          notificationInboxProvider.overrideWith((_) => Stream.value([])),
          moderationRepositoryProvider.overrideWithValue(
            _FakeModerationRepository([_pendingCase()]),
          ),
        ],
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-case-case-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ModerationCase _pendingCase() => ModerationCase(
  id: 'case-1',
  targetType: 'club',
  targetId: 'club-1',
  title: 'Club information needs review',
  description: 'The submitted club description may violate campus policy.',
  reporterName: 'Student Reporter',
  status: ModerationStatus.pending,
  createdAt: DateTime.utc(2026, 10, 28),
);

class _FakeModerationRepository implements ModerationRepository {
  _FakeModerationRepository(this.items);
  final List<ModerationCase> items;
  String? lastCaseId;
  String? lastActorId;
  ModerationAction? lastAction;

  @override
  Stream<List<ModerationCase>> watchCases() => Stream.value(items);

  @override
  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  }) async {
    lastCaseId = caseId;
    lastActorId = actorId;
    lastAction = action;
  }
}
