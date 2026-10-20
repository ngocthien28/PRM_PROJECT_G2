import 'dart:async';
import 'package:campushub/app.dart';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/routing/app_router.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/events/presentation/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_fakes.dart';
import 'event_fakes.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';

void main() {
  late FakeProfiles profiles;
  late FakeAuth auth;
  late FakeEvents events;
  late ProviderContainer container;

  setUp(() {
    profiles = FakeProfiles()..users['uid'] = testUser();
    auth = FakeAuth(profiles)..identity = testIdentity;
    events = FakeEvents([
      testEvent(),
      testEvent(
        id: 'music',
        title: 'Campus Concert',
        category: 'music',
        registeredCount: 100,
      ),
    ]);
    container = ProviderContainer(
      overrides: [
        firebaseInitializationProvider.overrideWith((ref) async {}),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        eventRepositoryProvider.overrideWithValue(events),
        notificationInboxProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await auth.dispose();
    await profiles.dispose();
  });
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1000, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CampusHubApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> browse(WidgetTester tester) async {
    await tester.tap(find.text('Browse events'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'home to list to details and back; search does not refetch on typing',
    (tester) async {
      await mount(tester);
      expect(find.text('Welcome, Minh'), findsOneWidget);
      await browse(tester);
      final reads = events.reads;
      await tester.enterText(
        find.byKey(const Key('event-search')),
        ' FLUTTER ',
      );
      await tester.pumpAndSettle();
      // The search field uses a 400 ms debouncer; advance past it.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Campus Concert'), findsNothing);
      expect(find.text('Flutter Workshop'), findsOneWidget);
      expect(events.reads, reads);
      await tester.tap(find.text('Flutter Workshop'));
      await tester.pumpAndSettle();
      expect(find.text('About this event'), findsOneWidget);
      expect(find.text('80 places available'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(' FLUTTER '), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Campus Concert'), findsOneWidget);
    },
  );

  testWidgets(
    'category shortcut filters server query and bottom sheet applies availability',
    (tester) async {
      await mount(tester);
      await tester.tap(find.widgetWithText(ActionChip, 'Music'));
      await tester.pumpAndSettle();
      expect(events.categories.last, 'music');
      expect(find.text('Campus Concert'), findsOneWidget);
      expect(find.text('Flutter Workshop'), findsNothing);
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('No matching events'), findsOneWidget);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.byType(EventCard), findsNWidgets(2));
    },
  );

  testWidgets('loading, error and retry recover without a new login', (
    tester,
  ) async {
    final pending = Completer<void>();
    events.pending = pending.future;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CampusHubApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    events.failure = const AppException('Cannot load events.');
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cannot load events.'), findsOneWidget);
    events.failure = null;
    events.pending = null;
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(EventCard), findsNWidgets(2));
  });

  testWidgets(
    'empty home and missing detail are explicit; logout protects deep links',
    (tester) async {
      events.events = [];
      await mount(tester);
      expect(find.text('No upcoming events yet'), findsOneWidget);
      container.read(appRouterProvider).push('/events/missing');
      await tester.pumpAndSettle();
      expect(find.text('This event is unavailable.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/events/event-1');
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('About this event'), findsNothing);
    },
  );

  testWidgets(
    'phone is one column; landscape/tablet is two; large text does not overflow',
    (tester) async {
      await mount(tester, size: const Size(390, 844));
      await browse(tester);
      expect(find.byKey(const ValueKey('event-grid-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(900, 500));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-grid-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
