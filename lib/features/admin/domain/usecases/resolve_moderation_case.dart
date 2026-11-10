import '../../data/models/moderation_case.dart';
import '../../data/moderation_repository.dart';

/// UC-084: Admin Management - Resolve Moderation Case.
/// Handles resolving or dismissing reported content/cases by an administrator,
/// updating case status, recording action notes, and attributing the resolver.
class ResolveModerationCase {
  const ResolveModerationCase(this._repository);

  final ModerationRepository _repository;

  Future<void> call({
    required String caseId,
    required ModerationAction action,
    required String note,
    required String actorId,
  }) async {
    final trimmedCaseId = caseId.trim();
    final trimmedActorId = actorId.trim();
    final trimmedNote = note.trim();

    if (trimmedCaseId.isEmpty) {
      throw ArgumentError.value(caseId, 'caseId', 'Case ID cannot be empty.');
    }
    if (trimmedActorId.isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'Actor ID cannot be empty.');
    }

    await _repository.resolveCase(
      caseId: trimmedCaseId,
      action: action,
      note: trimmedNote,
      actorId: trimmedActorId,
    );
  }
}
