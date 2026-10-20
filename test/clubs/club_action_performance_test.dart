import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/clubs/data/models/club_membership.dart';
import 'package:campushub/features/clubs/data/models/club_model.dart';
import 'package:campushub/features/clubs/presentation/screens/club_detail_screen.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/shared/enums/club_status.dart';
import 'package:campushub/shared/enums/membership_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_fakes.dart';
import 'club_view_model_test.dart' show FakeClubRepository;

class ActionRepository extends FakeClubRepository {
  ActionRepository(super.club, super.membership);
  int detailSubscriptions = 0, membershipSubscriptions = 0;
  @override
  Stream<ClubModel?> watchClub(String id) {
    detailSubscriptions++;
    return super.watchClub(id);
  }

  @override
  Stream<ClubMembership?> watchMembership(String id, String uid) {
    membershipSubscriptions++;
    return super.watchMembership(id, uid);
  }

  @override
  Future<void> leaveClub({
    required String clubId,
    required AppUser actor,
  }) async {}
}

void main() {
  testWidgets(
    'membership action preserves live subscriptions instead of reloading',
    (tester) async {
      final now = DateTime.utc(2026);
      final repo = ActionRepository(
        ClubModel(
          id: 'c',
          ownerId: 'owner',
          name: 'Code club',
          description: 'A place to learn together.',
          memberCount: 1,
          status: ClubStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
        ClubMembership(
          id: 'c_uid',
          clubId: 'c',
          userId: 'uid',
          role: MembershipRole.member,
          status: MembershipStatus.active,
          joinedAt: now,
          updatedAt: now,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clubRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWith((ref) => Stream.value(testUser())),
            notificationInboxProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: ClubDetailScreen(clubId: 'c')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Leave Club'));
      await tester.tap(find.text('Leave Club'));
      await tester.pumpAndSettle();
      expect(repo.detailSubscriptions, 1);
      expect(repo.membershipSubscriptions, 1);
      expect(find.text('About this club'), findsOneWidget);
    },
  );
}
