import 'package:campushub/features/clubs/data/models/club_model.dart';
import 'package:campushub/features/clubs/domain/usecases/search_clubs.dart';
import 'package:campushub/features/clubs/presentation/viewmodels/club_view_model.dart';
import 'package:campushub/shared/enums/club_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ClubModel _sampleClub({
  required String id,
  required String name,
  required String description,
  int memberCount = 10,
}) {
  final now = DateTime.now().toUtc();
  return ClubModel(
    id: id,
    ownerId: 'owner-1',
    name: name,
    description: description,
    memberCount: memberCount,
    status: ClubStatus.active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('UC-088: Search Clubs', () {
    final clubs = [
      _sampleClub(
        id: 'c1',
        name: 'Google Developer Student Club',
        description: 'Tech workshops and hackathons',
      ),
      _sampleClub(
        id: 'c2',
        name: 'Photography Club',
        description: 'Visual arts and campus photo walks',
      ),
      _sampleClub(
        id: 'c3',
        name: 'Music & Acoustic Band',
        description: 'Live performances and jamming sessions',
      ),
    ];

    test('returns all clubs when query is empty or whitespace', () {
      const useCase = SearchClubs();

      expect(useCase(clubs: clubs, query: '').length, equals(3));
      expect(useCase(clubs: clubs, query: '   ').length, equals(3));
    });

    test('matches club name case-insensitively', () {
      const useCase = SearchClubs();

      final results = useCase(clubs: clubs, query: 'google');
      expect(results.length, equals(1));
      expect(results.first.id, equals('c1'));

      final upperResults = useCase(clubs: clubs, query: 'PHOTOGRAPHY');
      expect(upperResults.length, equals(1));
      expect(upperResults.first.id, equals('c2'));
    });

    test('matches club description case-insensitively', () {
      const useCase = SearchClubs();

      final results = useCase(clubs: clubs, query: 'hackathon');
      expect(results.length, equals(1));
      expect(results.first.name, contains('Google Developer'));

      final acousticResults = useCase(clubs: clubs, query: 'jamming');
      expect(acousticResults.length, equals(1));
      expect(acousticResults.first.name, contains('Music'));
    });

    test('returns empty list when no club matches the keyword', () {
      const useCase = SearchClubs();

      final results = useCase(clubs: clubs, query: 'non-existent-topic-xyz');
      expect(results, isEmpty);
    });

    test('searchClubsProvider integrates with Riverpod container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final searchUseCase = container.read(searchClubsProvider);
      final results = searchUseCase(clubs: clubs, query: 'Visual arts');
      expect(results.length, equals(1));
      expect(results.first.id, equals('c2'));
    });
  });
}
