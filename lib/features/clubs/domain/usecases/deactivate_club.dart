import '../../../auth/data/models/app_user.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';

/// UC-071: deactivates a club while preserving its membership history.
class DeactivateClub {
  const DeactivateClub(this._repository);

  final ClubRepository _repository;

  Future<ClubModel> call({required String clubId, required AppUser actor}) =>
      _repository.cancelClub(clubId: clubId, actor: actor);
}
