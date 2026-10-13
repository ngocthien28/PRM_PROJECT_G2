import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../data/models/club_membership.dart';
import '../../data/models/club_model.dart';
import '../../domain/usecases/view_club_details.dart';
import '../../domain/usecases/view_club_list.dart';

final clubsProvider = StreamProvider.autoDispose<List<ClubModel>>(
  (ref) => ViewClubList(ref.watch(clubRepositoryProvider))(),
);
final clubProvider = StreamProvider.autoDispose.family<ClubModel?, String>(
  (ref, id) => ViewClubDetails(ref.watch(clubRepositoryProvider))(id),
);
final clubMembershipProvider = StreamProvider.autoDispose
    .family<ClubMembership?, ({String clubId, String userId})>(
      (ref, key) => ref
          .watch(clubRepositoryProvider)
          .watchMembership(key.clubId, key.userId),
    );
