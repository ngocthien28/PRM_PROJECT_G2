import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../data/models/club_membership.dart';
import '../../data/models/club_model.dart';
import '../../domain/usecases/view_club_details.dart';
import '../../domain/usecases/view_club_list.dart';
import '../../domain/usecases/search_clubs.dart';

typedef ViewClubListAction = Stream<List<ClubModel>> Function();

final viewClubListActionProvider = Provider<ViewClubListAction>((ref) {
  final useCase = ViewClubList(ref.watch(firestoreProvider));
  return useCase.call;
});

final clubsProvider = StreamProvider.autoDispose<List<ClubModel>>(
  (ref) => ref.watch(viewClubListActionProvider)(),
);

typedef ViewClubDetailsAction = Stream<ClubModel?> Function(String clubId);

final viewClubDetailsActionProvider = Provider<ViewClubDetailsAction>((ref) {
  final useCase = ViewClubDetails(ref.watch(firestoreProvider));
  return useCase.call;
});

final clubProvider = StreamProvider.autoDispose.family<ClubModel?, String>(
  (ref, id) => ref.watch(viewClubDetailsActionProvider)(id),
);
final clubMembershipProvider = StreamProvider.autoDispose
    .family<ClubMembership?, ({String clubId, String userId})>(
      (ref, key) => ref
          .watch(clubRepositoryProvider)
          .watchMembership(key.clubId, key.userId),
    );

final searchClubsProvider = Provider<SearchClubs>(
  (ref) => const SearchClubs(),
);
