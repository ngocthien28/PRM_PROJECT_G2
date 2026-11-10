import 'package:campushub/features/admin/data/models/moderation_case.dart';
import 'package:campushub/features/admin/data/moderation_repository.dart';
import 'package:campushub/features/admin/domain/usecases/resolve_moderation_case.dart';
import 'package:campushub/features/admin/presentation/viewmodels/moderation_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingModerationRepo implements ModerationRepository {
  String? resolvedCaseId;
  ModerationAction? resolvedAction;
  String? resolvedNote;
  String? resolvedActorId;

  @override
  Stream<List<ModerationCase>> watchCases() => const Stream.empty();

  @override
  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String title,
    required String description,
    required String reporterId,
    required String reporterName,
  }) async => 'id';

  @override
  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  }) async {
    resolvedCaseId = caseId;
    resolvedAction = action;
    resolvedNote = note;
    resolvedActorId = actorId;
  }
}

void main() {
  group('UC-084: Resolve Moderation Case', () {
    test('resolves moderation case and updates action and note', () async {
      final repo = _RecordingModerationRepo();
      final useCase = ResolveModerationCase(repo);

      await useCase.call(
        caseId: 'case-999',
        action: ModerationAction.resolve,
        note: 'Issue was investigated and resolved.',
        actorId: 'admin-42',
      );

      expect(repo.resolvedCaseId, equals('case-999'));
      expect(repo.resolvedAction, equals(ModerationAction.resolve));
      expect(repo.resolvedNote, equals('Issue was investigated and resolved.'));
      expect(repo.resolvedActorId, equals('admin-42'));
    });

    test('dismisses moderation case with policy explanation note', () async {
      final repo = _RecordingModerationRepo();
      final useCase = ResolveModerationCase(repo);

      await useCase.call(
        caseId: '  case-888  ',
        action: ModerationAction.dismiss,
        note: '  No violation of community standards found.  ',
        actorId: '  admin-77  ',
      );

      expect(repo.resolvedCaseId, equals('case-888'));
      expect(repo.resolvedAction, equals(ModerationAction.dismiss));
      expect(repo.resolvedNote, equals('No violation of community standards found.'));
      expect(repo.resolvedActorId, equals('admin-77'));
    });

    test('throws ArgumentError when caseId or actorId is empty', () async {
      final repo = _RecordingModerationRepo();
      final useCase = ResolveModerationCase(repo);

      expect(
        () => useCase.call(
          caseId: '   ',
          action: ModerationAction.resolve,
          note: 'Some note',
          actorId: 'admin-1',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => useCase.call(
          caseId: 'case-1',
          action: ModerationAction.resolve,
          note: 'Some note',
          actorId: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('resolveModerationCaseActionProvider integrates with Riverpod', () async {
      final repo = _RecordingModerationRepo();
      final container = ProviderContainer(
        overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final action = container.read(resolveModerationCaseActionProvider);
      await action(
        caseId: 'case-provider',
        action: ModerationAction.resolve,
        note: 'Provider test',
        actorId: 'admin-provider',
      );

      expect(repo.resolvedCaseId, equals('case-provider'));
      expect(repo.resolvedActorId, equals('admin-provider'));
    });
  });
}
