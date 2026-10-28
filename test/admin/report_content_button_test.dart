import 'package:campushub/features/admin/data/models/moderation_case.dart';
import 'package:campushub/features/admin/data/moderation_repository.dart';
import 'package:campushub/features/admin/presentation/viewmodels/moderation_view_model.dart';
import 'package:campushub/features/admin/presentation/widgets/report_content_button.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';

void main() {
  testWidgets('UC-092 signed-in user can submit a clear content report', (
    tester,
  ) async {
    final repository = _RecordingModerationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (_) => Stream.value(testUser(uid: 'student-1')),
          ),
          moderationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ReportContentButton(
              targetType: 'club',
              targetId: 'club-1',
              targetLabel: 'Code Club',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report-club-club-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('submit-content-report')));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 10 characters.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-reason')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety concern').last);
    await tester.enterText(
      find.byKey(const ValueKey('report-description')),
      'The published meeting location may be unsafe after closing time.',
    );
    await tester.pump();
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('submit-content-report')),
    );
    expect(submit.onPressed, isNotNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('submit-content-report')),
    );
    await tester.tap(find.byKey(const ValueKey('submit-content-report')));
    await tester.pumpAndSettle();

    expect(repository.targetType, 'club');
    expect(repository.targetId, 'club-1');
    expect(repository.title, 'Safety concern: Code Club');
    expect(repository.reporterId, 'student-1');
    expect(
      find.text('Report sent. An administrator will review it.'),
      findsOneWidget,
    );
  });
}

class _RecordingModerationRepository implements ModerationRepository {
  String? targetType;
  String? targetId;
  String? title;
  String? reporterId;

  @override
  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String title,
    required String description,
    required String reporterId,
    required String reporterName,
  }) async {
    this.targetType = targetType;
    this.targetId = targetId;
    this.title = title;
    this.reporterId = reporterId;
    return 'case-created';
  }

  @override
  Stream<List<ModerationCase>> watchCases() => const Stream.empty();

  @override
  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  }) async {}
}
