import 'package:campushub/features/profile/data/local_profile_cache.dart';
import 'package:campushub/app.dart';
import 'package:campushub/core/routing/app_router.dart';
import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/admin/presentation/viewmodels/admin_dashboard_view_model.dart';
import 'package:campushub/features/admin/data/admin_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_detail_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_poster_view_model.dart';
import 'poster_fixtures.dart';
import 'draft_fakes.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_draft_provider.dart';

class _RoutePosterPicker extends EventPosterPicker {
  @override
  Future<EventPosterSelection?> pick() async => posterSelection();
}

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
        eventDraftRepositoryProvider.overrideWithValue(FakeDraftRepository()),
        firebaseInitializationProvider.overrideWith((ref) async {}),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        localProfileCacheProvider.overrideWithValue(FakeLocalProfileCache()),
        eventRepositoryProvider.overrideWithValue(repository),
        eventPosterPickerProvider.overrideWithValue(_RoutePosterPicker()),
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

  Future<void> seedEditEvent({
    String id = 'edit-1',
    String title = 'Current Firestore title',
    String owner = 'uid',
  }) => db
      .collection('events')
      .doc(id)
      .set(testEvent(id: id, organizerId: owner, title: title).toMap());

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

  testWidgets('poster selection is isolated when switching event forms', (
    tester,
  ) async {
    restoreActiveUser(UserRole.organizer);
    await seedEditEvent();
    await seedEditEvent(id: 'edit-2', title: 'Second event');
    await mount(tester);
    final router = container.read(appRouterProvider);
    router.go(RouteNames.organizerEditEvent('edit-1'));
    await tester.pumpAndSettle();
    final select = find.byKey(const Key('selectPosterButton'));
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('posterPreview')), findsOneWidget);
    router.go(RouteNames.organizerEditEvent('edit-2'));
    await tester.pumpAndSettle();
    expect(find.text('Second event'), findsOneWidget);
    expect(find.byKey(const Key('posterPreview')), findsNothing);
    router.go(RouteNames.organizerCreateEvent);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('posterPreview')), findsNothing);
  });

  testWidgets('organizer navigates to My Managed Events', (tester) async {
    restoreActiveUser(UserRole.organizer);
    await mount(tester);

    await tester.tap(find.text('View all managed events'));
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.organizerManagedEvents);
    expect(find.text('My Managed Events'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(currentPath(), RouteNames.organizer);
  });

  testWidgets('dashboard event opens detail and Back returns to dashboard', (
    tester,
  ) async {
    restoreActiveUser(UserRole.organizer);
    await seedEditEvent();
    await mount(tester);
    await tester.ensureVisible(find.text('Current Firestore title'));
    await tester.tap(find.text('Current Firestore title'));
    await tester.pumpAndSettle();
    expect(container.read(appRouterProvider).canPop(), isTrue);
    expect(find.text('Event details'), findsOneWidget);
    expect(find.text('Current Firestore title'), findsOneWidget);
    expect(find.text('Tham gia sự kiện'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(currentPath(), RouteNames.organizer);
  });

  testWidgets(
    'managed card opens detail; direct detail has a safe Back fallback',
    (tester) async {
      restoreActiveUser(UserRole.organizer);
      await seedEditEvent();
      await mount(tester);
      final router = container.read(appRouterProvider);
      router.go(RouteNames.organizerManagedEvents);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current Firestore title'));
      await tester.pumpAndSettle();
      expect(find.text('Event details'), findsOneWidget);
      expect(router.canPop(), isTrue);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(currentPath(), RouteNames.organizerManagedEvents);
      router.go(RouteNames.organizerEventDetail('edit-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(currentPath(), RouteNames.organizerManagedEvents);
    },
  );

  for (final status in [
    EventStatus.draft,
    EventStatus.cancelled,
    EventStatus.finished,
  ]) {
    testWidgets('owner can open ${status.name} managed detail', (tester) async {
      restoreActiveUser(UserRole.organizer);
      await seedEditEvent();
      await db.collection('events').doc('edit-1').update({
        'status': status.name,
      });
      await mount(tester);
      container.read(appRouterProvider).go(RouteNames.organizerManagedEvents);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current Firestore title'));
      await tester.pumpAndSettle();
      expect(find.text('Event details'), findsOneWidget);
      expect(find.text('Current Firestore title'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('My Managed Events'), findsOneWidget);
    });
  }

  testWidgets('managed detail rejects another organizer event', (tester) async {
    restoreActiveUser(UserRole.organizer);
    await seedEditEvent();
    await db.collection('events').doc('edit-1').update({
      'organizerId': 'someone-else',
    });
    await mount(tester);
    container
        .read(appRouterProvider)
        .go(RouteNames.organizerEventDetail('edit-1'));
    await tester.pumpAndSettle();
    expect(find.text('Current Firestore title'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
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
      await tester.ensureVisible(find.byKey(const Key('categoryField')));
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

  testWidgets(
    'edit loads by ID without extra, ignores stale extra and re-enters',
    (tester) async {
      restoreActiveUser(UserRole.organizer);
      await seedEditEvent();
      await mount(tester);
      final router = container.read(appRouterProvider);
      router.go(RouteNames.organizerEditEvent('edit-1'));
      await tester.pumpAndSettle();
      expect(find.text('Current Firestore title'), findsOneWidget);
      expect(find.text('Hall A'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      router.go(RouteNames.organizer);
      await tester.pumpAndSettle();
      router.go(
        RouteNames.organizerEditEvent('edit-1'),
        extra: testEvent(id: 'wrong', title: 'Stale extra'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Current Firestore title'), findsOneWidget);
      expect(find.text('Stale extra'), findsNothing);
      expect(find.text('Save Changes'), findsOneWidget);
    },
  );

  testWidgets(
    'edit saves via transaction, refreshes managed list and Student detail provider',
    (tester) async {
      restoreActiveUser(UserRole.organizer);
      await seedEditEvent();
      await mount(tester);
      final detail = container.listen(eventDetailProvider('edit-1'), (_, _) {});
      addTearDown(detail.close);
      expect(
        (await container.read(eventDetailProvider('edit-1').future)).title,
        'Current Firestore title',
      );
      container.read(appRouterProvider).go(RouteNames.organizerManagedEvents);
      await tester.pumpAndSettle();
      container
          .read(appRouterProvider)
          .go(RouteNames.organizerEditEvent('edit-1'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('titleField')),
        'Edited through UI',
      );
      final submit = find.byKey(const Key('submitEventFormButton'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(currentPath(), RouteNames.organizerManagedEvents);
      expect(find.text('Edited through UI'), findsOneWidget);
      expect(find.text('Event updated successfully.'), findsOneWidget);
      expect(
        (await container.read(eventDetailProvider('edit-1').future)).title,
        'Edited through UI',
      );
      expect((await db.collection('events').get()).docs, hasLength(1));
    },
  );

  testWidgets(
    'switching edit ID resets fields and does not retain unsaved data',
    (tester) async {
      restoreActiveUser(UserRole.organizer);
      await seedEditEvent();
      await seedEditEvent(id: 'edit-2', title: 'Second event');
      await mount(tester);
      container
          .read(appRouterProvider)
          .go(RouteNames.organizerEditEvent('edit-1'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('titleField')),
        'Unsaved first',
      );
      profiles.update(testUser(role: UserRole.organizer));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved first'), findsOneWidget);
      container
          .read(appRouterProvider)
          .go(RouteNames.organizerEditEvent('edit-2'));
      await tester.pumpAndSettle();
      expect(find.text('Second event'), findsOneWidget);
      expect(find.text('Unsaved first'), findsNothing);
    },
  );

  testWidgets(
    'conflict keeps edits until the user confirms reloading latest data',
    (tester) async {
      restoreActiveUser(UserRole.organizer);
      await seedEditEvent();
      await mount(tester);
      container
          .read(appRouterProvider)
          .go(RouteNames.organizerEditEvent('edit-1'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('titleField')),
        'My unsaved edit',
      );
      await db.collection('events').doc('edit-1').update({
        'title': 'Newer server title',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2031)),
      });
      final button = find.byKey(const Key('submitEventFormButton'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('My unsaved edit'), findsOneWidget);
      expect(
        find.text(
          'This event changed while you were editing. Reload the latest event before saving again.',
        ),
        findsOneWidget,
      );
      expect(currentPath(), RouteNames.organizerEditEvent('edit-1'));
      final reload = find.text('Reload latest event');
      await tester.ensureVisible(reload);
      await tester.pumpAndSettle();
      await tester.tap(reload);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('My unsaved edit'), findsOneWidget);
      await tester.ensureVisible(reload);
      await tester.pumpAndSettle();
      await tester.tap(reload);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(find.text('Newer server title'), findsOneWidget);
      expect(find.text('My unsaved edit'), findsNothing);
    },
  );

  testWidgets('missing and invalid edit IDs show error with Retry', (
    tester,
  ) async {
    restoreActiveUser(UserRole.organizer);
    await mount(tester);
    for (final id in ['missing', 'bad/path']) {
      container.read(appRouterProvider).go(RouteNames.organizerEditEvent(id));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('editEventLoadError')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const Key('titleField')), findsNothing);
    }
  });

  testWidgets('non-owner cannot open edit; admin can load it', (tester) async {
    restoreActiveUser(UserRole.organizer);
    await seedEditEvent(owner: 'other-organizer');
    await mount(tester);
    container
        .read(appRouterProvider)
        .go(RouteNames.organizerEditEvent('edit-1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editEventLoadError')), findsOneWidget);
    expect(find.byKey(const Key('titleField')), findsNothing);
    profiles.update(testUser(role: UserRole.admin));
    await tester.pumpAndSettle();
    expect(find.text('Current Firestore title'), findsOneWidget);
  });

  testWidgets('Student edit deep link redirects away from organizer routes', (
    tester,
  ) async {
    restoreActiveUser(UserRole.student);
    await mount(tester);
    container
        .read(appRouterProvider)
        .go(RouteNames.organizerEditEvent('edit-1'));
    await tester.pumpAndSettle();
    expect(currentPath(), RouteNames.home);
    expect(find.byKey(const Key('titleField')), findsNothing);
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
