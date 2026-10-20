import '../../../auth/data/models/app_user.dart';
import '../../data/club_repository.dart';

/// UC-072: joins an active student to an active club transactionally.
class JoinClub {
  const JoinClub(this._repository);

  final ClubRepository _repository;

  Future<void> call({required String clubId, required AppUser actor}) =>
      _repository.joinClub(clubId: clubId, actor: actor);
}
