// Author: ThaiQHCE181542 - Quách Hoàng Thái
// UC-086: Local Data & Responsive - View Recently Viewed Events & Clear All Favorites

import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/data/event_read_repository.dart';
import 'package:campushub/features/events/data/event_repository.dart';
import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/favorites/data/favorite_repository.dart';
import 'package:campushub/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:campushub/features/favorites/presentation/viewmodels/favorite_view_model.dart';
import 'package:campushub/local/dao/recent_view_dao.dart';
import 'package:campushub/local/local_tables.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel _dummyEvent({
  required String id,
  required String title,
  String category = 'technology',
}) =>
    EventModel(
      id: id,
      organizerId: 'org-test',
      title: title,
      description: 'Test description for $title',
      category: category,
      locationName: 'Hall A',
      startAt: DateTime.utc(2026, 11, 20, 10),
      endAt: DateTime.utc(2026, 11, 20, 12),
      capacity: 100,
      registeredCount: 20,
      checkedInCount: 0,
      status: EventStatus.published,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

class _FakeReadRepo implements EventReadRepository {
  _FakeReadRepo(this.events);
  final List<EventModel> events;

  @override
  Future<List<EventModel>> getUpcomingEvents({
    EventFilter? filter,
    bool forceRefresh = false,
  }) async =>
      events;

  @override
  Future<EventModel> getEventById(String eventId, {AppUser? actor}) async =>
      events.firstWhere((e) => e.id == eventId);

  @override
  Future<List<EventModel>> searchEvents(EventFilter filter) async => events;

  @override
  Future<List<EventModel>> getEventsByIds(List<String> eventIds) async =>
      events.where((e) => eventIds.contains(e.id)).toList();

  @override
  Future<List<EventModel>> getRelatedEvents({
    required String eventId,
    required String category,
    int limit = 4,
  }) async =>
      events
          .where((e) => e.id != eventId && e.category == category)
          .take(limit)
          .toList();
}

class _FakeFavoriteRepository implements FavoriteRepository {
  final Map<String, Set<String>> _favorites = {};
  final List<EventModel> allEvents;

  _FakeFavoriteRepository({List<EventModel>? events})
      : allEvents = events ?? [];

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
  Future<void> removeFavorite({
    required String userId,
    required String eventId,
  }) async {
    _favorites[userId]?.remove(eventId);
  }

  @override
  Future<void> clearAllFavorites(String userId) async {
    _favorites[userId]?.clear();
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
    uid: 'student-thai-1',
    email: 'thaiqhce181542@fpt.edu.vn',
    displayName: 'Quách Hoàng Thái',
  );

  group('UC-086: RecentViewRecord Data Serialization', () {
    test('toMap and fromMap retain field values correctly', () {
      final now = DateTime.utc(2026, 11, 9, 12, 0);
      final record = RecentViewRecord(
        eventId: 'event-101',
        userId: 'student-thai-1',
        viewedAt: now,
      );

      final map = record.toMap();
      expect(map[LocalTables.colEventId], 'event-101');
      expect(map[LocalTables.colUserId], 'student-thai-1');
      expect(map[LocalTables.colViewedAt], now.millisecondsSinceEpoch);

      final fromMap = RecentViewRecord.fromMap(map);
      expect(fromMap.eventId, 'event-101');
      expect(fromMap.userId, 'student-thai-1');
      expect(
        fromMap.viewedAt.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });
  });

  group('UC-086: RecentViewDao Storage & Ordering Tests', () {
    late RecentViewDao dao;
    const testUser = 'user-thai-rec-1';
    const otherUser = 'user-other-rec-2';

    setUp(() async {
      dao = RecentViewDao();
      await dao.clearForUser(testUser);
      await dao.clearForUser(otherUser);
    });

    test('new user starts with empty recently viewed list', () async {
      final ids = await dao.getRecentlyViewedEventIds(userId: testUser);
      expect(ids, isEmpty);
    });

    test('recordView maintains order from most recent to oldest', () async {
      await dao.recordView(eventId: 'ev-alpha', userId: testUser);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await dao.recordView(eventId: 'ev-beta', userId: testUser);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await dao.recordView(eventId: 'ev-gamma', userId: testUser);

      final ids = await dao.getRecentlyViewedEventIds(userId: testUser);
      expect(ids, equals(['ev-gamma', 'ev-beta', 'ev-alpha']));
    });

    test('re-viewing an event moves it to the top of the list', () async {
      await dao.recordView(eventId: 'ev-1', userId: testUser);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await dao.recordView(eventId: 'ev-2', userId: testUser);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      // View ev-1 again
      await dao.recordView(eventId: 'ev-1', userId: testUser);

      final ids = await dao.getRecentlyViewedEventIds(userId: testUser);
      expect(ids, equals(['ev-1', 'ev-2']));
    });

    test('getRecentlyViewedEventIds respects limit parameter', () async {
      for (var i = 1; i <= 8; i++) {
        await dao.recordView(eventId: 'ev-$i', userId: testUser);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final idsLimit3 =
          await dao.getRecentlyViewedEventIds(userId: testUser, limit: 3);
      expect(idsLimit3.length, 3);
      expect(idsLimit3, equals(['ev-8', 'ev-7', 'ev-6']));
    });

    test('clearForUser clears target user without affecting other users', () async {
      await dao.recordView(eventId: 'ev-thai', userId: testUser);
      await dao.recordView(eventId: 'ev-other', userId: otherUser);

      await dao.clearForUser(testUser);

      expect(await dao.getRecentlyViewedEventIds(userId: testUser), isEmpty);
      expect(
        await dao.getRecentlyViewedEventIds(userId: otherUser),
        equals(['ev-other']),
      );
    });
  });

  group('UC-086: FavoritesScreen UI & View Recently Viewed Integration', () {
    final eventA = _dummyEvent(id: 'ev-a', title: 'AI & Data Workshop');
    final eventB = _dummyEvent(id: 'ev-b', title: 'Mobile Dev Seminar');
    late RecentViewDao recentDao;
    late _FakeFavoriteRepository favRepo;
    late _FakeReadRepo readRepo;

    setUp(() async {
      recentDao = RecentViewDao();
      await recentDao.clearForUser('student-thai-1');
      favRepo = _FakeFavoriteRepository(events: [eventA, eventB]);
      readRepo = _FakeReadRepo([eventA, eventB]);
    });

    testWidgets('Recently Viewed tab shows empty placeholder when no views',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentViewDaoProvider.overrideWithValue(recentDao),
            favoriteRepositoryProvider.overrideWithValue(favRepo),
            eventReadRepositoryProvider.overrideWithValue(readRepo),
            authStateProvider.overrideWith((ref) => Stream.value(dummyIdentity)),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Tab 2 ("Đã xem gần đây")
      await tester.tap(find.text('Đã xem gần đây'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có sự kiện đã xem gần đây'), findsOneWidget);
    });

    testWidgets(
        'Recently Viewed tab displays events and clear history button works',
        (tester) async {
      // Record views
      await recentDao.recordView(eventId: 'ev-a', userId: 'student-thai-1');
      await tester.pump(const Duration(milliseconds: 15));
      await recentDao.recordView(eventId: 'ev-b', userId: 'student-thai-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentViewDaoProvider.overrideWithValue(recentDao),
            favoriteRepositoryProvider.overrideWithValue(favRepo),
            eventReadRepositoryProvider.overrideWithValue(readRepo),
            authStateProvider.overrideWith((ref) => Stream.value(dummyIdentity)),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Tab 2
      await tester.tap(find.text('Đã xem gần đây'));
      await tester.pumpAndSettle();

      // Verify header and events rendered
      expect(find.text('Đã xem 2 sự kiện gần đây'), findsOneWidget);
      expect(find.text('Mobile Dev Seminar'), findsOneWidget);
      expect(find.text('AI & Data Workshop'), findsOneWidget);
      expect(find.byKey(const Key('clear-recent-views-btn')), findsOneWidget);

      // Tap "Xóa lịch sử"
      await tester.tap(find.byKey(const Key('clear-recent-views-btn')));
      await tester.pumpAndSettle();

      // Dialog shown
      expect(find.text('Xóa lịch sử xem?'), findsOneWidget);
      expect(
        find.text('Bạn có chắc chắn muốn xóa toàn bộ danh sách các sự kiện đã xem gần đây không?'),
        findsOneWidget,
      );

      // Confirm dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa lịch sử'));
      await tester.pumpAndSettle();

      // Verify list cleared and empty placeholder shown
      expect(find.text('Chưa có sự kiện đã xem gần đây'), findsOneWidget);
      expect(
        await recentDao.getRecentlyViewedEventIds(userId: 'student-thai-1'),
        isEmpty,
      );
    });

    testWidgets('Clear All Favorites dialog removes all favorites (UC-086)',
        (tester) async {
      await favRepo.toggleFavorite(
        userId: 'student-thai-1',
        eventId: 'ev-a',
        isFavorite: true,
      );
      await favRepo.toggleFavorite(
        userId: 'student-thai-1',
        eventId: 'ev-b',
        isFavorite: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recentViewDaoProvider.overrideWithValue(recentDao),
            favoriteRepositoryProvider.overrideWithValue(favRepo),
            eventReadRepositoryProvider.overrideWithValue(readRepo),
            authStateProvider.overrideWith((ref) => Stream.value(dummyIdentity)),
          ],
          child: const MaterialApp(
            home: FavoritesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã lưu 2 sự kiện'), findsOneWidget);
      expect(find.byKey(const Key('clear-all-favorites')), findsOneWidget);

      // Tap Clear All Favorites
      await tester.tap(find.byKey(const Key('clear-all-favorites')));
      await tester.pumpAndSettle();

      // Dialog shown
      expect(find.text('Xóa tất cả yêu thích?'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa tất cả'));
      await tester.pumpAndSettle();

      // Verify favorites empty
      expect(await favRepo.getFavoriteEvents('student-thai-1'), isEmpty);
      expect(find.text('Chưa có sự kiện yêu thích'), findsOneWidget);
    });
  });
}
