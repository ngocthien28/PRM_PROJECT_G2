import '../../data/models/moderation_case.dart';
import '../../data/moderation_repository.dart';

/// UC-077: Admin Management - View Moderation Queue.
/// Stream/listen to the real-time queue of moderation cases, allowing
/// administrators to review pending reports, check details and statuses.
class ViewModerationQueue {
  const ViewModerationQueue(this._repository);

  final ModerationRepository _repository;

  Stream<List<ModerationCase>> call() => _repository.watchCases();
}
