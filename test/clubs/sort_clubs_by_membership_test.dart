import 'package:campushub/features/clubs/data/models/club_model.dart';
import 'package:campushub/features/clubs/domain/usecases/sort_clubs_by_membership.dart';
import 'package:campushub/features/clubs/presentation/viewmodels/club_view_model.dart';
import 'package:campushub/shared/enums/club_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ClubModel _createClub({
  required String id,
  required String name,
  required int memberCount,
}) {
  final now = DateTime.now().toUtc();
  return ClubModel(
    id: id,
    ownerId: 'owner-test',
    name: name,
    description: 'Description for $name',
    memberCount: memberCount,
    status: ClubStatus.active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('UC-089: Sort Clubs by Membership', () {
    final clubs = [
      _createClub(id: 'c-small', name: 'Board Games Club', memberCount: 15),
      _createClub(id: 'c-large', name: 'Google Developer Club', memberCount: 250),
      _createClub(id: 'c-medium', name: 'Acoustic Guitar Club', memberCount: 80),
    ];

    test('sorts clubs descending by member count by default', () {
      const useCase = SortClubsByMembership();

      final sorted = useCase(clubs);
      expect(sorted.map((c) => c.memberCount).toList(), equals([250, 80, 15]));
      expect(sorted.first.id, equals('c-large'));
      expect(sorted.last.id, equals('c-small'));
    });

    test('sorts clubs ascending by member count when descending is false', () {
      const useCase = SortClubsByMembership();

      final sorted = useCase(clubs, descending: false);
      expect(sorted.map((c) => c.memberCount).toList(), equals([15, 80, 250]));
      expect(sorted.first.id, equals('c-small'));
      expect(sorted.last.id, equals('c-large'));
    });

    test('does not mutate original collection', () {
      const useCase = SortClubsByMembership();

      final copy = List<ClubModel>.from(clubs);
      useCase(clubs);
      expect(clubs.map((c) => c.id).toList(), equals(copy.map((c) => c.id).toList()));
    });

    test('handles empty and single-element lists without error', () {
      const useCase = SortClubsByMembership();

      expect(useCase([]), isEmpty);

      final single = [_createClub(id: 'single', name: 'Solo Club', memberCount: 5)];
      final sortedSingle = useCase(single);
      expect(sortedSingle.length, equals(1));
      expect(sortedSingle.first.id, equals('single'));
    });

    test('sortClubsByMembershipProvider integrates with Riverpod container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sortUseCase = container.read(sortClubsByMembershipProvider);
      final sorted = sortUseCase(clubs);
      expect(sorted.first.name, equals('Google Developer Club'));
    });
  });
}
