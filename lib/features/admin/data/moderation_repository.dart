import 'models/moderation_case.dart';

abstract interface class ModerationRepository {
  Stream<List<ModerationCase>> watchCases();

  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  });
}
