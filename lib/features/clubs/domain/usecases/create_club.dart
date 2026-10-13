import '../../../auth/data/models/app_user.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';

/// UC-069: creates an active club owned by the organizer or administrator.
class CreateClub {
  const CreateClub(this._repository);

  final ClubRepository _repository;

  Future<ClubModel> call({
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? logo,
  }) => _repository.createClub(
    name: name,
    description: description,
    actor: actor,
    logo: logo,
  );
}
