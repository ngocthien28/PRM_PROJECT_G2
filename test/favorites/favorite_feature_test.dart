import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/favorites/data/favorite_repository.dart';
import 'package:campushub/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:campushub/features/favorites/presentation/viewmodels/favorite_view_model.dart';
import 'package:campushub/local/dao/favorite_local_dao.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel _dummyEvent({
  String id = 'event-fav-1',
  String title = 'Flutter Coding Workshop',
  String category = 'technology',
}) =>
    EventModel(
      id: id,
      organizerId: 'org-1',
      title: title,
      description: 'Hands-on coding workshop for mobile development.',
      category: category,
      locationName: 'Room 301',
      startAt: DateTime.utc(2026, 11, 10, 9),
      endAt: DateTime.utc(2026, 11, 10, 11),
      capacity: 50,
      registeredCount: 15,
      checkedInCount: 0,
      status: EventStatus.published,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

class FakeFavoriteRepository implements FavoriteRepository {
  final Map<String, Set<String>> _favorites = {};
  final List<EventModel> allEvents;

  FakeFavoriteRepository({List<EventModel>? events})
      : allEvents = events ?? [_dummyEvent()];

  @override
  Future<void> toggleFavorite({
    required String userId,
    required String eventId,
    required bool isFavorite,
  }) async {
    final set = _favorites.putIfAbsent(userId, () => <String>{});
    if (isFavorite) {
      set.add(eventId);
    } else {
      set.remove(eventId);
    }
  }

  @override
  Future<bool> isFavorite({
    required String userId,
    required String eventId,
  }) async {
    return _favorites[userId]?.contains(eventId) ?? false;
  }

  @override
  Future<List<EventModel>> getFavoriteEvents(String userId) async {
    final ids = _favorites[userId] ?? {};
    return allEvents.where((e) => ids.contains(e.id)).toList();
  }

  @override
  Stream<List<String>> watchFavoriteIds(String userId) {
    return Stream.value((_favorites[userId] ?? {}).toList());
  }
}

void main() {
  const dummyIdentity = AuthIdentity(
    uid: 'user-1',
    email: 'student@campus.edu',
    displayName: 'Student',
  );

  group('FavoriteLocalDao (In-Memory / Web fallback)', () {
    late FavoriteLocalDao dao;
    const testUser = 'user-test-123';
    const testEventId = 'event-abc-999';

    setUp(() {
      dao = FavoriteLocalDao();
    });

    test('setFavorite and isFavorite work correctly', () async {
      expect(await dao.isFavorite(eventId: testEventId, userId: testUser), false);

      await dao.setFavorite(
        eventId: testEventId,
        userId: testUser,
        isFavorite: true,
      );
      expect(await dao.isFavorite(eventId: testEventId, userId: testUser), true);

      final ids = await dao.getFavoriteEventIds(testUser);
      expect(ids, contains(testEventId));

      await dao.setFavorite(
        eventId: testEventId,
        userId: testUser,
        isFavorite: false,
      );
      expect(await dao.isFavorite(eventId: testEventId, userId: testUser), false);
    });

    test('clearForUser removes records', () async {
      await dao.setFavorite(
        eventId: 'event-1',
        userId: 'user-to-clear',
        isFavorite: true,
      );
      expect(await dao.isFavorite(eventId: 'event-1', userId: 'user-to-clear'), true);

      await dao.clearForUser('user-to-clear');
      expect(await dao.isFavorite(eventId: 'event-1', userId: 'user-to-clear'), false);
    });
  });

  group('FavoritesScreen Widget Tests (UC-026)', () {
    testWidgets('shows empty state when no favorite events', (tester) async {
      final fakeRepo = FakeFavoriteRepository(events: []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith(
              (ref) => Stream.value(dummyIdentity),
            ),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sự Kiện Yêu Thích'), findsOneWidget);
      expect(find.text('Chưa có sự kiện yêu thích'), findsOneWidget);
      expect(find.text('Khám phá sự kiện ngay'), findsOneWidget);
    });

    testWidgets('shows event cards when user has favorites', (tester) async {
      final event1 = _dummyEvent(id: 'ev-1', title: 'Tech Talk AI');
      final event2 = _dummyEvent(id: 'ev-2', title: 'Music Festival');
      final fakeRepo = FakeFavoriteRepository(events: [event1, event2]);

      await fakeRepo.toggleFavorite(userId: 'user-1', eventId: 'ev-1', isFavorite: true);
      await fakeRepo.toggleFavorite(userId: 'user-1', eventId: 'ev-2', isFavorite: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith(
              (ref) => Stream.value(dummyIdentity),
            ),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sự Kiện Yêu Thích'), findsOneWidget);
      expect(find.text('Tech Talk AI'), findsOneWidget);
      expect(find.text('Music Festival'), findsOneWidget);
      expect(find.textContaining('Đã lưu 2 sự kiện'), findsOneWidget);
    });

    testWidgets('search query filters favorite events list', (tester) async {
      final event1 = _dummyEvent(id: 'ev-1', title: 'Tech Talk AI');
      final event2 = _dummyEvent(id: 'ev-2', title: 'Music Festival');
      final fakeRepo = FakeFavoriteRepository(events: [event1, event2]);

      await fakeRepo.toggleFavorite(userId: 'user-1', eventId: 'ev-1', isFavorite: true);
      await fakeRepo.toggleFavorite(userId: 'user-1', eventId: 'ev-2', isFavorite: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteRepositoryProvider.overrideWithValue(fakeRepo),
            authStateProvider.overrideWith(
              (ref) => Stream.value(dummyIdentity),
            ),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Tech');
      await tester.pumpAndSettle();

      expect(find.text('Tech Talk AI'), findsOneWidget);
      expect(find.text('Music Festival'), findsNothing);
    });
  });
}
