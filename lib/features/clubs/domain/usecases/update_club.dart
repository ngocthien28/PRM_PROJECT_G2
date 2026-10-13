import '../../../auth/data/models/app_user.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';

/// UC-070: updates a club after repository-level ownership checks.
class UpdateClub {
  const UpdateClub(this._repository);

  final ClubRepository _repository;

  Future<ClubModel> call({
    required String clubId,
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? newLogo,
  }) => _repository.updateClub(
    clubId: clubId,
    name: name,
    description: description,
    actor: actor,
    newLogo: newLogo,
  );
}
