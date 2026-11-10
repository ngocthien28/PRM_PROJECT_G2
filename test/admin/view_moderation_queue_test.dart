import 'package:campushub/features/admin/data/models/moderation_case.dart';
import 'package:campushub/features/admin/data/moderation_repository.dart';
import 'package:campushub/features/admin/domain/usecases/view_moderation_queue.dart';
import 'package:campushub/features/admin/presentation/viewmodels/moderation_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeModerationRepo implements ModerationRepository {
  _FakeModerationRepo(this._cases);
  final List<ModerationCase> _cases;

  @override
  Stream<List<ModerationCase>> watchCases() => Stream.value(_cases);

  @override
  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String title,
    required String description,
    required String reporterId,
    required String reporterName,
  }) async => 'new-case-id';

  @override
  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  }) async {}
}

ModerationCase _createCase({
  required String id,
  required String title,
  ModerationStatus status = ModerationStatus.pending,
}) {
  return ModerationCase(
    id: id,
    targetType: 'club',
    targetId: 'club-1',
    title: title,
    description: 'Inappropriate content report',
    reporterName: 'Student User',
    status: status,
    createdAt: DateTime.now().toUtc(),
  );
}

void main() {
  group('UC-077: View Moderation Queue', () {
    test('streams moderation cases from repository queue', () async {
      final fakeCases = [
        _createCase(id: 'c1', title: 'Case 1'),
        _createCase(id: 'c2', title: 'Case 2', status: ModerationStatus.resolved),
      ];
      final repo = _FakeModerationRepo(fakeCases);
      final useCase = ViewModerationQueue(repo);

      final result = await useCase.call().first;
      expect(result.length, equals(2));
      expect(result[0].id, equals('c1'));
      expect(result[0].title, equals('Case 1'));
      expect(result[0].status, equals(ModerationStatus.pending));
      expect(result[1].id, equals('c2'));
      expect(result[1].status, equals(ModerationStatus.resolved));
    });

    test('viewModerationQueueProvider integrates cleanly with Riverpod', () async {
      final fakeCases = [_createCase(id: 'c-admin', title: 'Admin Case')];
      final repo = _FakeModerationRepo(fakeCases);
      final container = ProviderContainer(
        overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(moderationCasesProvider, (_, _) {});
      addTearDown(subscription.close);

      final queueUseCase = container.read(viewModerationQueueProvider);
      final cases = await queueUseCase().first;
      expect(cases.single.id, equals('c-admin'));

      final asyncCases = await container.read(moderationCasesProvider.future);
      expect(asyncCases.single.title, equals('Admin Case'));
    });
  });
}
