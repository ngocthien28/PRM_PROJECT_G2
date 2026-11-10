import '../../data/moderation_repository.dart';

/// UC-092: Submit Content Report.
/// Validates content report inputs and submits report to moderation repository
/// for administrative review.
class SubmitContentReport {
  const SubmitContentReport(this._repository);

  final ModerationRepository _repository;

  Future<String> call({
    required String targetType,
    required String targetId,
    required String title,
    required String description,
    required String reporterId,
    required String reporterName,
  }) async {
    final trimmedDesc = description.trim();
    if (trimmedDesc.length < 10) {
      throw ArgumentError('Report description must be at least 10 characters long.');
    }
    final trimmedTitle = title.trim();
    final formattedTitle = trimmedTitle.length <= 120
        ? trimmedTitle
        : '${trimmedTitle.substring(0, 117)}...';

    return _repository.submitReport(
      targetType: targetType.trim(),
      targetId: targetId.trim(),
      title: formattedTitle,
      description: trimmedDesc,
      reporterId: reporterId.trim(),
      reporterName: reporterName.trim(),
    );
  }
}
