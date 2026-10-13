import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../data/models/club_membership.dart';
import '../../data/models/club_model.dart';
import '../../domain/usecases/view_club_list.dart';

typedef ViewClubListAction = Stream<List<ClubModel>> Function();

final viewClubListActionProvider = Provider<ViewClubListAction>((ref) {
  final useCase = ViewClubList(ref.watch(firestoreProvider));
  return useCase.call;
});

final clubsProvider = StreamProvider.autoDispose<List<ClubModel>>(
  (ref) => ref.watch(viewClubListActionProvider)(),
);
final clubProvider = StreamProvider.autoDispose.family<ClubModel?, String>(
  (ref, id) => ref.watch(clubRepositoryProvider).watchClub(id),
);
final clubMembershipProvider = StreamProvider.autoDispose
    .family<ClubMembership?, ({String clubId, String userId})>(
      (ref, key) => ref
          .watch(clubRepositoryProvider)
          .watchMembership(key.clubId, key.userId),
    );
