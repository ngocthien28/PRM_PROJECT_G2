import 'package:campushub/app.dart';
import 'package:campushub/core/routing/app_router.dart';
import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late ProviderContainer container;

  setUp(() {
    profiles = FakeProfiles();
    auth = FakeAuth(profiles);
    container = ProviderContainer(
      overrides: [
        firebaseInitializationProvider.overrideWith((ref) async {}),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        eventRepositoryProvider.overrideWithValue(FakeEvents([])),
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

  String currentPath() => container
      .read(appRouterProvider)
      .routeInformationProvider
      .value
      .uri
      .path;

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
    expect(find.text('Create Event'), findsNWidgets(2));
    expect(find.byKey(const Key('titleField')), findsOneWidget);
  });

  testWidgets('admin can access Create Event by direct URL', (tester) async {
    restoreActiveUser(UserRole.admin);
    await mount(tester);

    container.read(appRouterProvider).go(RouteNames.organizerCreateEvent);
    await tester.pumpAndSettle();

    expect(currentPath(), RouteNames.organizerCreateEvent);
    expect(find.byKey(const Key('titleField')), findsOneWidget);
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

  testWidgets('create route injects persistence without a fake success message', (
    tester,
  ) async {
    restoreActiveUser(UserRole.organizer);
    await mount(tester);
    container.read(appRouterProvider).go(RouteNames.organizerCreateEvent);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('eventSavingUnavailableMessage')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('submitEventFormButton')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Event saved'), findsNothing);
  });
}
