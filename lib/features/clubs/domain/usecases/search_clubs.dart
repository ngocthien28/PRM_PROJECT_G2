import '../../data/models/club_model.dart';

/// UC-088: Club Management - Search Clubs.
/// Filters the active club collection based on user search keywords,
/// matching against club name and description case-insensitively.
class SearchClubs {
  const SearchClubs();

  List<ClubModel> call({
    required List<ClubModel> clubs,
    required String query,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return clubs;
    }
    return clubs
        .where(
          (c) =>
              c.name.toLowerCase().contains(normalized) ||
              c.description.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }
}
