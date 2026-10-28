import 'package:campushub/features/admin/data/models/moderation_case.dart';
import 'package:campushub/features/admin/data/moderation_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
