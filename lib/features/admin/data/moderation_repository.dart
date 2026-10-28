import 'models/moderation_case.dart';

abstract interface class ModerationRepository {
  Stream<List<ModerationCase>> watchCases();

  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String title,
    required String description,
    required String reporterId,
    required String reporterName,
  });

  Future<void> resolveCase({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  });
}
