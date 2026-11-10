import '../../data/models/club_model.dart';

/// UC-089: Club Management - Sort Clubs by Membership.
/// Sorts a collection of clubs by member count in descending order
/// so students can discover the most active and popular communities.
class SortClubsByMembership {
  const SortClubsByMembership();

  List<ClubModel> call(List<ClubModel> clubs, {bool descending = true}) {
    final result = List<ClubModel>.from(clubs);
    result.sort(
      (a, b) => descending
          ? b.memberCount.compareTo(a.memberCount)
          : a.memberCount.compareTo(b.memberCount),
    );
    return result;
  }
}
