import 'package:campushub/app.dart';
import 'package:campushub/core/routing/app_router.dart';
import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/admin/presentation/viewmodels/admin_dashboard_view_model.dart';
import 'package:campushub/features/admin/data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';

import '../auth/auth_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late ProviderContainer container;
  late FakeFirebaseFirestore db;
  late EventRepositoryImpl repository;

  setUp(() {
    profiles = FakeProfiles();
    auth = FakeAuth(profiles);
    db = FakeFirebaseFirestore();
    repository = EventRepositoryImpl(firestore: db);
    container = ProviderContainer(
      overrides: [
        firebaseInitializationProvider.overrideWith((ref) async {}),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        eventRepositoryProvider.overrideWithValue(repository),
        notificationInboxProvider.overrideWith((ref) => Stream.value([])),
        adminStatsProvider.overrideWith(
          (ref) async => const AdminStats(
            userCount: 1,
            clubCount: 0,
            eventCount: 0,
            activeMembershipCount: 0,
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.dispose();
    await profiles.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CampusHubApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String currentPath() =>
      container.read(appRouterProvider).routeInformationProvider.value.uri.path;

  void restoreActiveUser(UserRole role) {
    auth.identity = testIdentity;
    profiles.users[testIdentity.uid] = testUser(role: role);
  }

  testWidgets('organizer navigates from organizer page to Create Event', (
    tester,
  ) async {
    restoreActiveUser(UserRole.organizer);
    await mount(tester);

    expect(currentPath(), RouteNames.organizer);
    await tester.tap(find.byKey(const Key('createEventAction')));
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.organizerCreateEvent);
    expect(find.text('Create Event'), findsNWidgets(3));
    expect(find.byKey(const Key('titleField')), findsOneWidget);
  });

  testWidgets('organizer navigates to My Managed Events', (tester) async {
    restoreActiveUser(UserRole.organizer);
    await mount(tester);

    await tester.tap(find.text('View all managed events'));
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.organizerManagedEvents);
    expect(find.text('My Managed Events'), findsOneWidget);
  });

  testWidgets(
    'create persists through the real repository and refreshes managed events',
    (tester) async {
      restoreActiveUser(UserRole.organizer);
      await mount(tester);
      // Prime the empty list before create so the test also checks invalidation.
      await tester.tap(find.text('View all managed events'));
      await tester.pumpAndSettle();
      expect(find.text('No managed events yet.'), findsOneWidget);
      container.read(appRouterProvider).go(RouteNames.organizerCreateEvent);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('titleField')),
        'UC037 integration event',
      );
      await tester.enterText(
        find.byKey(const Key('descriptionField')),
        'A real repository create flow backed by fake Firestore.',
      );
      await tester.tap(find.byKey(const Key('categoryField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('locationField')),
        ' Hall A ',
      );
      await tester.enterText(find.byKey(const Key('capacityField')), '80');
      final button = find.byKey(const Key('submitEventFormButton'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(currentPath(), RouteNames.organizerManagedEvents);
      expect(find.text('UC037 integration event'), findsOneWidget);
      expect(find.text('Event created successfully.'), findsOneWidget);
      final documents = await db.collection('events').get();
      expect(documents.docs, hasLength(1));
      final event = (await repository.getUpcomingEvents()).single;
      expect(event.id, documents.docs.single.id);
      expect(event.organizerId, testIdentity.uid);
      expect(event.locationName, 'Hall A');
      expect(event.posterUrl, isNull);
      // A fresh repository reads persisted data rather than widget/provider RAM.
      expect(
        (await EventRepositoryImpl(firestore: db).getEventById(event.id)).title,
        event.title,
      );
    },
  );

  testWidgets('admin can access Create Event by direct URL', (tester) async {
    restoreActiveUser(UserRole.admin);
    await mount(tester);

    container.read(appRouterProvider).go(RouteNames.organizerCreateEvent);
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.organizerCreateEvent);
    expect(find.byKey(const Key('titleField')), findsOneWidget);
  });

  testWidgets('organizer can sign out from the dashboard', (tester) async {
    restoreActiveUser(UserRole.organizer);
    await mount(tester);

    await tester.tap(find.byKey(const Key('organizerSignOutButton')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.login);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('student cannot access Create Event by direct URL', (
    tester,
  ) async {
    restoreActiveUser(UserRole.student);
    await mount(tester);

    container.read(appRouterProvider).go(RouteNames.organizerCreateEvent);
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.home);
    expect(find.text('Create Event'), findsNothing);
  });

  testWidgets('unauthenticated user cannot access Create Event by direct URL', (
    tester,
  ) async {
    await mount(tester);

    container.read(appRouterProvider).go(RouteNames.organizerCreateEvent);
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.login);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets(
    'create route injects persistence without a fake success message',
    (tester) async {
      restoreActiveUser(UserRole.organizer);
      await mount(tester);
      container.read(appRouterProvider).go(RouteNames.organizerCreateEvent);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('eventSavingUnavailableMessage')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('submitEventFormButton')),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Event saved'), findsNothing);
    },
  );
}
