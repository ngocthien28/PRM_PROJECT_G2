import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/data/event_read_repository.dart';
import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/events/presentation/screens/event_detail_screen.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_detail_view_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/registration/presentation/viewmodels/registration_view_model.dart';
import 'package:campushub/local/dao/recent_view_dao.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';

EventModel _testEvent({
  required String id,
  required String title,
  required String category,
}) => EventModel(
  id: id,
  organizerId: 'org-1',
  title: title,
  description: 'Detailed description for $title',
  category: category,
  locationName: 'Campus Center Room 101',
  startAt: DateTime.utc(2026, 11, 20, 10),
  endAt: DateTime.utc(2026, 11, 20, 12),
  capacity: 50,
  registeredCount: 10,
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
  }) async => events;

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
  }) async => events
      .where((e) => e.id != eventId && e.category == category)
      .take(limit)
      .toList();
}

void main() {
  const dummyIdentity = AuthIdentity(
    uid: 'student-42',
    email: 'student42@campus.edu',
    displayName: 'Thien Student',
  );

  final mainEvent = _testEvent(
    id: 'ev-main',
    title: 'Flutter Deep Dive',
    category: 'technology',
  );
  final relatedEvent1 = _testEvent(
    id: 'ev-rel-1',
    title: 'Dart 3 Patterns',
    category: 'technology',
  );
  final relatedEvent2 = _testEvent(
    id: 'ev-rel-2',
    title: 'Cloud Functions with Firebase',
    category: 'technology',
  );
  final unrelatedEvent = _testEvent(
    id: 'ev-music',
    title: 'Acoustic Guitar Night',
    category: 'music',
  );

  final allEvents = [mainEvent, relatedEvent1, relatedEvent2, unrelatedEvent];

  testWidgets(
    'EventDetailScreen renders related events sharing the same category (UC-085)',
    (tester) async {
      final fakeReadRepo = _FakeReadRepo(allEvents);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventReadRepositoryProvider.overrideWithValue(fakeReadRepo),
            eventDetailProvider('ev-main').overrideWith((_) async => mainEvent),
            eventRegistrationStatusProvider(
              'ev-main',
            ).overrideWith((_) async => null),
            authStateProvider.overrideWith((_) => Stream.value(dummyIdentity)),
          ],
          child: const MaterialApp(home: EventDetailScreen(eventId: 'ev-main')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Flutter Deep Dive'), findsOneWidget);
      expect(find.text('About this event'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('report-event-ev-main')),
        findsOneWidget,
      );

      // Verify Related Events section is rendered
      expect(find.text('Sự kiện liên quan'), findsOneWidget);
      expect(find.text('Dart 3 Patterns'), findsOneWidget);
      expect(find.text('Cloud Functions with Firebase'), findsOneWidget);
      expect(find.text('Acoustic Guitar Night'), findsNothing);
    },
  );

  testWidgets(
    'EventDetailScreen records view in RecentViewDao when student opens detail (UC-086)',
    (tester) async {
      final fakeReadRepo = _FakeReadRepo(allEvents);
      final recentDao = RecentViewDao();
      await recentDao.clearForUser('student-42');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventReadRepositoryProvider.overrideWithValue(fakeReadRepo),
            recentViewDaoProvider.overrideWithValue(recentDao),
            eventDetailProvider('ev-main').overrideWith((_) async => mainEvent),
            eventRegistrationStatusProvider(
              'ev-main',
            ).overrideWith((_) async => null),
            authStateProvider.overrideWith((_) => Stream.value(dummyIdentity)),
            currentUserProvider.overrideWith(
              (_) => Stream.value(testUser(uid: 'student-42')),
            ),
          ],
          child: const MaterialApp(home: EventDetailScreen(eventId: 'ev-main')),
        ),
      );

      await tester.pumpAndSettle();

      // Check view was recorded
      final viewedIds = await recentDao.getRecentlyViewedEventIds(
        userId: 'student-42',
      );
      expect(viewedIds, contains('ev-main'));
    },
  );
}
