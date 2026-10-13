import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';

/// UC-067: returns the live directory of active clubs.
class ViewClubList {
  const ViewClubList(this._repository);

  final ClubRepository _repository;

  Stream<List<ClubModel>> call() => _repository.watchClubs();
}
