import '../../../auth/data/models/app_user.dart';
import '../../data/club_repository.dart';

/// UC-083: leaves a club without deleting the membership history.
class LeaveClub {
  const LeaveClub(this._repository);

  final ClubRepository _repository;

  Future<void> call({required String clubId, required AppUser actor}) =>
      _repository.leaveClub(clubId: clubId, actor: actor);
}
