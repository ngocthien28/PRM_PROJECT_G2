import 'package:campushub/features/admin/data/models/moderation_case.dart';
import 'package:campushub/features/admin/data/moderation_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active user report creates a pending moderation case', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = ModerationRepositoryImpl(firestore);

    final id = await repository.submitReport(
      targetType: 'club',
      targetId: 'club-1',
      title: 'Inaccurate information: Code Club',
      description: 'The meeting location shown on this page is out of date.',
      reporterId: 'student-1',
      reporterName: 'Student Reporter',
    );

    final data = (await firestore.collection('moderation_cases').doc(id).get())
        .data()!;
    expect(data['targetType'], 'club');
    expect(data['targetId'], 'club-1');
    expect(data['reporterId'], 'student-1');
    expect(data['status'], 'pending');
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
  });

  test('report rejects unsupported targets and vague descriptions', () async {
    final repository = ModerationRepositoryImpl(FakeFirebaseFirestore());

    expect(
      () => repository.submitReport(
        targetType: 'document',
        targetId: 'doc-1',
        title: 'Other concern: Document',
        description: 'This description is long enough.',
        reporterId: 'student-1',
        reporterName: 'Student Reporter',
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.submitReport(
        targetType: 'event',
        targetId: 'event-1',
        title: 'Other concern: Event',
        description: 'Too short',
        reporterId: 'student-1',
        reporterName: 'Student Reporter',
      ),
      throwsArgumentError,
    );
  });

  test(
    'queue is ordered newest first and decisions keep an audit record',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('moderation_cases')
          .doc('older')
          .set(_caseData(DateTime.utc(2026, 10, 20)));
      await firestore
          .collection('moderation_cases')
          .doc('newer')
          .set(_caseData(DateTime.utc(2026, 10, 28)));
      final repository = ModerationRepositoryImpl(firestore);

      final queue = await repository.watchCases().first;
      expect(queue.map((item) => item.id), ['newer', 'older']);

      await repository.resolveCase(
        caseId: 'newer',
        action: ModerationAction.resolve,
        note: 'Reviewed the report and contacted the organizer.',
        actorId: 'admin-1',
      );
      final data =
          (await firestore.collection('moderation_cases').doc('newer').get())
              .data()!;
      expect(data['status'], 'resolved');
      expect(data['resolutionAction'], 'resolve');
      expect(data['resolvedBy'], 'admin-1');
      expect(data['resolvedAt'], isA<Timestamp>());
    },
  );

  test('a reviewed case cannot be resolved twice', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('moderation_cases').doc('case-1').set({
      ..._caseData(DateTime.utc(2026, 10, 28)),
      'status': 'dismissed',
    });
    final repository = ModerationRepositoryImpl(firestore);

    expect(
      () => repository.resolveCase(
        caseId: 'case-1',
        action: ModerationAction.resolve,
        note: 'Trying to change the final decision.',
        actorId: 'admin-1',
      ),
      throwsStateError,
    );
  });
}

Map<String, Object> _caseData(DateTime createdAt) => {
  'targetType': 'club',
  'targetId': 'club-1',
  'title': 'Club information needs review',
  'description': 'The submitted club description may violate campus policy.',
  'reporterId': 'student-1',
  'reporterName': 'Student Reporter',
  'status': 'pending',
  'createdAt': Timestamp.fromDate(createdAt),
  'updatedAt': Timestamp.fromDate(createdAt),
};
