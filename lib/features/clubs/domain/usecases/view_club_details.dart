import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';

/// UC-068: watches one club so its details stay current.
class ViewClubDetails {
  const ViewClubDetails(this._repository);

  final ClubRepository _repository;

  Stream<ClubModel?> call(String clubId) => _repository.watchClub(clubId);
}
