import 'package:campushub/core/routing/app_router.dart';
import 'package:campushub/core/routing/route_guards.dart';
import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/screens/manage_events_screen.dart';
import 'package:campushub/features/organizer_events/presentation/screens/organizer_create_event_screen.dart';
import 'package:campushub/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart';
import 'package:campushub/features/organizer_events/presentation/screens/participant_list_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_events_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';
import '../registration/registration_fakes.dart';

void main() {
  group('UC-033 Organizer Screen Structure Tests', () {
    testWidgets('all 5 organizer screens render without placeholders', (
      tester,
    ) async {
      final event = testEvent(
        id: 'event-struct-1',
        organizerId: 'org-1',
        title: 'Structure Event',
      );
      final fakeEvents = FakeEvents([event]);
      final fakeRegistrations = FakeRegistrationRepository([
        testRegistration(id: 'reg-1', eventId: 'event-struct-1'),
      ]);

      Widget buildWithOverrides(Widget child) => ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) =>
                Stream.value(testUser(uid: 'org-1', role: UserRole.organizer)),
          ),
          eventRepositoryProvider.overrideWithValue(fakeEvents),
          registrationRepositoryProvider.overrideWithValue(fakeRegistrations),
          organizerEventsProvider.overrideWith((ref) async => [event]),
          organizerEditEventProvider(
            'event-struct-1',
          ).overrideWith((ref) async => event),
          participantSummaryProvider('event-struct-1').overrideWith(
            (ref) async => ParticipantSummaryState(
              event: event,
              participants: fakeRegistrations.registrations,
            ),
          ),
        ],
        child: MaterialApp(home: child),
      );

      // 1. Organizer Dashboard Screen
      await tester.pumpWidget(
        buildWithOverrides(
          OrganizerDashboardScreen(
            onCreateEvent: () {},
            onManageEvents: () {},
            onEditEvent: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CampusHub Organizer'), findsOneWidget);
      expect(find.text('Create Event'), findsOneWidget);
      expect(find.text('TODO'), findsNothing);

      // 2. My Managed Events Screen
      await tester.pumpWidget(buildWithOverrides(const ManageEventsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('My Managed Events'), findsOneWidget);
      expect(find.text('TODO'), findsNothing);

      // 3. Create Event Screen
      await tester.pumpWidget(
        buildWithOverrides(const OrganizerCreateEventScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create Event'), findsWidgets);
      expect(find.text('TODO'), findsNothing);

      // 4. Edit Event Screen
      await tester.pumpWidget(
        buildWithOverrides(
          const OrganizerEditEventScreen(eventId: 'event-struct-1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit Event'), findsWidgets);
      expect(find.text('Structure Event'), findsOneWidget);
      expect(find.text('TODO'), findsNothing);

      // 5. Participant Summary Screen
      await tester.pumpWidget(
        buildWithOverrides(
          const ParticipantListScreen(eventId: 'event-struct-1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Event Participants'), findsOneWidget);
      expect(find.text('Participant Statistics'), findsOneWidget);
      expect(find.text('TODO'), findsNothing);
    });

    testWidgets('router navigates between organizer screens', (tester) async {
      final event = testEvent(
        id: 'e1',
        organizerId: 'org-1',
        title: 'Nav Event',
        capacity: 50,
        registeredCount: 10,
        checkedInCount: 5,
      );
      final fakeEvents = FakeEvents([event]);
      final fakeRegistrations = FakeRegistrationRepository([
        testRegistration(id: 'r1', eventId: 'e1', userId: 'student-1'),
      ]);

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthIdentity(
                uid: 'org-1',
                email: 'org-1@example.com',
                displayName: 'Organizer',
              ),
            ),
          ),
          currentUserProvider.overrideWith(
            (ref) =>
                Stream.value(testUser(uid: 'org-1', role: UserRole.organizer)),
          ),
          eventRepositoryProvider.overrideWithValue(fakeEvents),
          registrationRepositoryProvider.overrideWithValue(fakeRegistrations),
          organizerEventsProvider.overrideWith((ref) async => [event]),
          organizerEditEventProvider('e1').overrideWith((ref) async => event),
          participantSummaryProvider('e1').overrideWith(
            (ref) async => ParticipantSummaryState(
              event: event,
              participants: fakeRegistrations.registrations,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Organizer Dashboard
      router.go(RouteNames.organizer);
      await tester.pumpAndSettle();
      expect(find.text('CampusHub Organizer'), findsOneWidget);

      // Dashboard -> Managed Events
      await tester.tap(find.text('View all managed events'));
      await tester.pumpAndSettle();
      expect(find.text('My Managed Events'), findsOneWidget);

      // Managed Events -> Participants via popup menu
      await tester.tap(find.byTooltip('Manage event').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View participants'));
      await tester.pumpAndSettle();
      expect(find.text('Event Participants'), findsOneWidget);
      expect(find.text('Participant Statistics'), findsOneWidget);
      expect(find.text('User: student-1'), findsOneWidget);

      // Direct navigation to Edit Event
      router.go(RouteNames.organizerEditEvent('e1'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Event'), findsWidgets);

      // Direct navigation to Participants
      router.go(RouteNames.organizerEventParticipants('e1'));
      await tester.pumpAndSettle();
      expect(find.text('Event Participants'), findsOneWidget);
    });

    test('route guard rules protect organizer participants path', () {
      final participantsPath = RouteNames.organizerEventParticipants('e1');

      // Unauthenticated -> redirects to /login
      expect(
        sessionRedirect(
          path: participantsPath,
          auth: const AsyncData(null),
          profile: const AsyncData(null),
        ),
        RouteNames.login,
      );

      // Student -> redirects to /home
      expect(
        sessionRedirect(
          path: participantsPath,
          auth: AsyncData(const AuthIdentity(uid: 's1', email: 's@test.com')),
          profile: AsyncData(testUser(uid: 's1', role: UserRole.student)),
        ),
        RouteNames.home,
      );

      // Active Organizer -> null (allowed)
      expect(
        sessionRedirect(
          path: participantsPath,
          auth: AsyncData(const AuthIdentity(uid: 'o1', email: 'o@test.com')),
          profile: AsyncData(testUser(uid: 'o1', role: UserRole.organizer)),
        ),
        isNull,
      );

      // Active Admin -> null (allowed)
      expect(
        sessionRedirect(
          path: participantsPath,
          auth: AsyncData(const AuthIdentity(uid: 'a1', email: 'a@test.com')),
          profile: AsyncData(testUser(uid: 'a1', role: UserRole.admin)),
        ),
        isNull,
      );
    });
  });
}
