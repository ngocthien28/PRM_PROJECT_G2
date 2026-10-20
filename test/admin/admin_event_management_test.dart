import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/features/admin/data/admin_repository.dart';
import 'package:campushub/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:campushub/features/admin/presentation/viewmodels/admin_dashboard_view_model.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/events/presentation/screens/event_detail_screen.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/screens/manage_events_screen.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:campushub/shared/widgets/campus_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

class _FakeEventRepository extends FakeEvents {
  _FakeEventRepository(super.events);

  @override
  Future<List<EventModel>> getManagedEvents({required AppUser actor}) async {
    return events;
  }

  @override
  Future<EventModel> updateEvent({
    required String eventId,
    required EventFormInput input,
    required AppUser actor,
    DateTime? expectedUpdatedAt,
  }) async {
    final idx = events.indexWhere((e) => e.id == eventId);
    final current = events[idx];
    final updated = EventModel(
      id: current.id,
      organizerId: current.organizerId, // Ownership preserved!
      clubId: current.clubId,
      title: input.title,
      description: input.description,
      category: input.category,
      locationName: input.locationName,
      latitude: current.latitude,
      longitude: current.longitude,
      startAt: input.startAt,
      endAt: input.endAt,
      capacity: input.capacity,
      registeredCount: current.registeredCount, // Preserved!
      checkedInCount: current.checkedInCount, // Preserved!
      posterUrl: current.posterUrl,
      status: current.status,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    events[idx] = updated;
    return updated;
  }

  @override
  Future<EventModel> cancelEvent({
    required String eventId,
    required AppUser actor,
  }) async {
    final idx = events.indexWhere((e) => e.id == eventId);
    final current = events[idx];
    final cancelled = EventModel(
      id: current.id,
      organizerId: current.organizerId, // Ownership preserved!
      clubId: current.clubId,
      title: current.title,
      description: current.description,
      category: current.category,
      locationName: current.locationName,
      latitude: current.latitude,
      longitude: current.longitude,
      startAt: current.startAt,
      endAt: current.endAt,
      capacity: current.capacity,
      registeredCount: current.registeredCount, // Preserved!
      checkedInCount: current.checkedInCount, // Preserved!
      posterUrl: current.posterUrl,
      status: EventStatus.cancelled,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    events[idx] = cancelled;
    return cancelled;
  }
}

void main() {
  final adminUser = testUser(uid: 'admin-1', role: UserRole.admin);

  group('Admin Event Management UI and Permissions', () {
    testWidgets('Admin Dashboard has clear buttons to enter event management', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(adminUser)),
            adminStatsProvider.overrideWith(
              (ref) => const AdminStats(
                userCount: 10,
                clubCount: 3,
                eventCount: 7,
                activeMembershipCount: 15,
              ),
            ),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Quick action button exists
      expect(
        find.byKey(const Key('adminQuickActionManageEvents')),
        findsOneWidget,
      );
      expect(find.text('My Managed Events'), findsOneWidget);

      // 2. AppBar action button exists
      expect(find.byKey(const Key('adminManageEventsButton')), findsOneWidget);

      // 3. Feature banner button exists
      expect(find.text('Manage Events'), findsOneWidget);

      // 4. Events stat card exists
      expect(find.text('Events in the workspace'), findsOneWidget);
    });

    testWidgets('Admin sees organizer info and can filter by Cancelled', (
      tester,
    ) async {
      final organizerEvent = testEvent(
        id: 'org-event-1',
        organizerId: 'organizer-42',
        title: 'Original Tech Summit',
        status: EventStatus.published,
      );
      final cancelledEvent = testEvent(
        id: 'org-event-2',
        organizerId: 'organizer-99',
        title: 'Old Meetup',
        status: EventStatus.cancelled,
      );

      final repo = _FakeEventRepository([organizerEvent, cancelledEvent]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(adminUser)),
            eventRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: ManageEventsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Should display Organizer ID
      expect(find.text('Organizer: organizer-42'), findsOneWidget);
      expect(find.text('Original Tech Summit'), findsOneWidget);

      // Filter by Cancelled
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Original Tech Summit'), findsNothing);
      expect(find.text('Old Meetup'), findsOneWidget);
    });

    testWidgets(
      'Cancel event dialog: Keep event leaves event unchanged, Cancel marks cancelled',
      (tester) async {
        final organizerEvent = testEvent(
          id: 'org-event-1',
          organizerId: 'organizer-42',
          title: 'Test Event To Cancel',
          status: EventStatus.published,
        );

        final repo = _FakeEventRepository([organizerEvent]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith(
                (ref) => Stream.value(adminUser),
              ),
              eventRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: ManageEventsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Open popup menu
        await tester.tap(find.byTooltip('Manage event').first);
        await tester.pumpAndSettle();

        // Tap Cancel event menu option
        await tester.tap(find.text('Cancel event'));
        await tester.pumpAndSettle();

        // Dialog appears with Keep event and Cancel event
        expect(find.text('Cancel event?'), findsOneWidget);
        expect(find.text('Keep event'), findsOneWidget);

        // Tap Keep event first -> should NOT cancel
        await tester.tap(find.text('Keep event'));
        await tester.pumpAndSettle();

        expect(repo.events.first.status, EventStatus.published);

        // Open popup menu again
        await tester.tap(find.byTooltip('Manage event').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel event'));
        await tester.pumpAndSettle();

        // Tap Cancel event in dialog -> should cancel
        await tester.tap(find.widgetWithText(FilledButton, 'Cancel event'));
        await tester.pumpAndSettle();

        expect(repo.events.first.status, EventStatus.cancelled);
        expect(repo.events.first.organizerId, 'organizer-42'); // Preserved!
        expect(repo.events.first.registeredCount, 20); // Preserved!
      },
    );

    testWidgets(
      'EventDetailScreen shows cancellation banner and disables join button when cancelled',
      (tester) async {
        final cancelledEvent = testEvent(
          id: 'cancelled-event-1',
          title: 'Cancelled Festival',
          status: EventStatus.cancelled,
        );

        final repo = _FakeEventRepository([cancelledEvent]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (ref) => Stream.value(testIdentity),
              ),
              eventRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(
              home: EventDetailScreen(eventId: 'cancelled-event-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Banner should be visible
        expect(find.text('Sự kiện đã bị hủy'), findsWidgets);

        // Join button should have label 'Sự kiện đã bị hủy' and be disabled
        final buttonFinder = find.widgetWithText(
          FilledButton,
          'Sự kiện đã bị hủy',
        );
        expect(buttonFinder, findsOneWidget);
        final FilledButton button = tester.widget(buttonFinder);
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'Admin CampusScaffold has Manage Events destination in sidebar and navigates',
      (tester) async {
        const scaffold = CampusScaffold(
          title: 'Admin Dashboard',
          section: CampusSection.admin,
          role: 'admin',
          body: Text('Admin body'),
        );

        // Verify destinations list contains Manage Events
        expect(
          scaffold.destinations.any(
            (d) =>
                d.$1 == 'Manage Events' &&
                d.$4 == RouteNames.organizerManagedEvents,
          ),
          isTrue,
        );
      },
    );

    testWidgets('Admin dashboard quick actions have equal uniform heights', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(adminUser)),
            adminStatsProvider.overrideWith(
              (ref) => Future.value(
                const AdminStats(
                  userCount: 7,
                  clubCount: 3,
                  eventCount: 9,
                  activeMembershipCount: 3,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Find all 4 quick action cards by their unique subtitles
      expect(
        find.text('Review, edit, and cancel campus events'),
        findsOneWidget,
      );
      expect(find.text('Explore and manage communities'), findsOneWidget);
      expect(
        find.text('Keep up with updates and notifications'),
        findsOneWidget,
      );
      expect(find.text('Open the moderation workspace'), findsOneWidget);

      final card1 = tester.getSize(
        find.ancestor(
          of: find.text('Review, edit, and cancel campus events'),
          matching: find.byType(Card),
        ),
      );
      final card2 = tester.getSize(
        find.ancestor(
          of: find.text('Explore and manage communities'),
          matching: find.byType(Card),
        ),
      );
      final card3 = tester.getSize(
        find.ancestor(
          of: find.text('Keep up with updates and notifications'),
          matching: find.byType(Card),
        ),
      );
      final card4 = tester.getSize(
        find.ancestor(
          of: find.text('Open the moderation workspace'),
          matching: find.byType(Card),
        ),
      );

      expect(card3.height, equals(card1.height));
      expect(card3.height, equals(card2.height));
      expect(card3.height, equals(card4.height));
    });
  });
}
