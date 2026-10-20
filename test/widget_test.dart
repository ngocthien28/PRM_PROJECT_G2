import 'package:campushub/features/profile/data/local_profile_cache.dart';
import 'package:campushub/app.dart';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/routing/app_router.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth/auth_fakes.dart';
import 'events/event_fakes.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/admin/presentation/viewmodels/admin_dashboard_view_model.dart';
import 'package:campushub/features/admin/data/admin_repository.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';

void main() {
  late FakeProfiles profiles;
  late FakeAuth auth;
  late ProviderContainer container;
  setUp(() {
    profiles = FakeProfiles();
    auth = FakeAuth(profiles);
    container = ProviderContainer(
      overrides: [
        firebaseInitializationProvider.overrideWith((ref) async {}),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        localProfileCacheProvider.overrideWithValue(FakeLocalProfileCache()),
        eventRepositoryProvider.overrideWithValue(FakeEvents([])),
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

  Future<void> fill(WidgetTester tester, int index, String text) =>
      tester.enterText(find.byType(TextFormField).at(index), text);
  testWidgets(
    'register logout login and protected Back all follow the session',
    (tester) async {
      await mount(tester);
      expect(find.text('Sign in'), findsWidgets);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await fill(tester, 0, 'Minh');
      await fill(tester, 1, 'uid@example.com');
      await fill(tester, 2, 'password');
      await fill(tester, 3, 'password');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Minh'), findsOneWidget);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/home',
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      expect(container.read(currentUserProvider).asData?.value, isNull);
      container.read(appRouterProvider).go('/home');
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Minh'), findsNothing);
      await fill(tester, 0, 'uid@example.com');
      await fill(tester, 1, 'password');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Minh'), findsOneWidget);
    },
  );
  testWidgets('login links to forgot password and back', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsWidgets);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
  testWidgets('restored missing profile can recover safely', (tester) async {
    auth.identity = testIdentity;
    await mount(tester);
    expect(find.text('Retry profile setup'), findsOneWidget);
    await tester.tap(find.text('Retry profile setup'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Minh'), findsOneWidget);
    expect(profiles.users['uid']?.role, UserRole.student);
  });
  testWidgets('disabled profile is gated and can sign out', (tester) async {
    auth.identity = testIdentity;
    profiles.users['uid'] = testUser(status: 'disabled');
    await mount(tester);
    expect(find.textContaining('This account is disabled'), findsOneWidget);
    expect(find.text('Retry profile setup'), findsNothing);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });
  testWidgets('profile load failure offers retry, never auto-creates', (
    tester,
  ) async {
    auth.identity = testIdentity;
    profiles.failure = const AppException('Cannot load profile.');
    await mount(tester);
    expect(find.text('Cannot load profile.'), findsOneWidget);
    expect(find.text('Retry profile setup'), findsNothing);
    profiles.failure = null;
    profiles.users['uid'] = testUser();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Minh'), findsOneWidget);
    expect(profiles.creates, 0);
  });
  testWidgets('live disabled status removes protected landing', (tester) async {
    auth.identity = testIdentity;
    profiles.users['uid'] = testUser();
    await mount(tester);
    profiles.update(testUser(status: 'disabled'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Minh'), findsNothing);
    expect(find.textContaining('This account is disabled'), findsOneWidget);
  });
  for (final role in [UserRole.organizer, UserRole.admin]) {
    testWidgets('restored ${role.name} session reaches its role route', (
      tester,
    ) async {
      auth.identity = testIdentity;
      profiles.users['uid'] = testUser(role: role);
      await mount(tester);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/${role.name}',
      );
    });
  }
  testWidgets('Firebase initialization failure is explicit and retryable', (
    tester,
  ) async {
    var attempts = 0;
    final bootstrap = ProviderContainer(
      overrides: [
        firebaseInitializationProvider.overrideWith((ref) async {
          attempts++;
          throw UnsupportedError('Missing Firebase configuration');
        }),
      ],
    );
    addTearDown(bootstrap.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: bootstrap,
        child: const CampusHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Firebase could not be initialized'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
