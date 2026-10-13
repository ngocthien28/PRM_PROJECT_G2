import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/clubs/data/club_repository.dart';
import 'package:campushub/features/clubs/data/models/club_membership.dart';
import 'package:campushub/features/clubs/data/models/club_model.dart';
import 'package:campushub/features/clubs/presentation/viewmodels/club_view_model.dart';
import 'package:campushub/shared/enums/club_status.dart';
import 'package:campushub/shared/enums/membership_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClubRepository implements ClubRepository {
  FakeClubRepository(this.club, this.membership);

  final ClubModel club;
  final ClubMembership membership;

  @override
  Stream<List<ClubModel>> watchClubs() => Stream.value([club]);

  @override
  Stream<ClubModel?> watchClub(String clubId) =>
      Stream.value(clubId == club.id ? club : null);

  @override
  Stream<ClubMembership?> watchMembership(String clubId, String userId) =>
      Stream.value(
        clubId == membership.clubId && userId == membership.userId
            ? membership
            : null,
      );

  @override
  Future<ClubModel> cancelClub({
    required String clubId,
    required AppUser actor,
  }) => throw UnsupportedError('Not used by this provider test.');

  @override
  Future<ClubModel> createClub({
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? logo,
  }) => throw UnsupportedError('Not used by this provider test.');

  @override
  Future<void> joinClub({required String clubId, required AppUser actor}) =>
      throw UnsupportedError('Not used by this provider test.');

  @override
  Future<void> leaveClub({required String clubId, required AppUser actor}) =>
      throw UnsupportedError('Not used by this provider test.');

  @override
  Future<ClubModel> updateClub({
    required String clubId,
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? newLogo,
  }) => throw UnsupportedError('Not used by this provider test.');
}

void main() {
  final now = DateTime.utc(2026, 10, 13);
  final club = ClubModel(
    id: 'club-1',
    ownerId: 'organizer-1',
    name: 'F-Code',
    description: 'A sufficiently long Club description.',
    memberCount: 1,
    status: ClubStatus.active,
    createdAt: now,
    updatedAt: now,
  );
  final membership = ClubMembership(
    id: ClubMembership.documentId('club-1', 'student-1'),
    clubId: 'club-1',
    userId: 'student-1',
    role: MembershipRole.member,
    status: MembershipStatus.active,
    joinedAt: now,
    updatedAt: now,
  );

  test('Club providers expose list, detail, and membership streams', () async {
    final repository = FakeClubRepository(club, membership);
    final container = ProviderContainer(
      overrides: [
        clubRepositoryProvider.overrideWithValue(repository),
        viewClubListActionProvider.overrideWithValue(repository.watchClubs),
        viewClubDetailsActionProvider.overrideWithValue(repository.watchClub),
      ],
    );
    addTearDown(container.dispose);
    final subscriptions = [
      container.listen(clubsProvider, (_, _) {}),
      container.listen(clubProvider('club-1'), (_, _) {}),
      container.listen(
        clubMembershipProvider((clubId: 'club-1', userId: 'student-1')),
        (_, _) {},
      ),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });

    expect(await container.read(clubsProvider.future), [club]);
    expect(await container.read(clubProvider('club-1').future), club);
    expect(
      await container.read(
        clubMembershipProvider((clubId: 'club-1', userId: 'student-1')).future,
      ),
      membership,
    );
  });
}
