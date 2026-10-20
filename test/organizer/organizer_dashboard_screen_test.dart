import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/core/theme/app_theme.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_dashboard_view_model.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

void main() {
  final now = DateTime.utc(2030, 5, 1, 10);
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late FakeEvents repository;
  setUp(
    () => repository = FakeEvents([
      testEvent(
        id: 'future',
        title: 'My upcoming workshop',
        startAt: now.add(const Duration(days: 1)),
        registeredCount: 12,
        checkedInCount: 3,
      ),
      testEvent(
        id: 'cancelled',
        title: 'Cancelled conference',
        status: EventStatus.cancelled,
        startAt: now.add(const Duration(days: 2)),
        registeredCount: 4,
        checkedInCount: 1,
      ),
    ]),
  );

  Widget app({
    VoidCallback? create,
    VoidCallback? manage,
    void Function(String)? edit,
    void Function(String)? participants,
    GoRouter? router,
    Stream<AppUser?>? users,
  }) {
    final dashboard = OrganizerDashboardScreen(
      onCreateEvent: create ?? () {},
      onManageEvents: manage ?? () {},
      onEditEvent: (event) => edit?.call(event.id),
      onViewParticipants: participants == null
          ? null
          : (event) => participants(event.id),
    );
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWith((ref) => users ?? Stream.value(owner)),
        eventRepositoryProvider.overrideWithValue(repository),
        organizerDashboardClockProvider.overrideWithValue(() => now),
        unreadNotificationCountProvider.overrideWithValue(0),
      ],
      child: router == null
          ? MaterialApp(theme: AppTheme.light, home: dashboard)
          : MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  String kpi(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('dashboardKpiValue-$id'))).data!;

  testWidgets(
    'renders real six KPIs, upcoming event metadata and navigation CTAs',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Organizer Dashboard'), findsOneWidget);
      expect(kpi(tester, 'totalEvents'), '2');
      expect(kpi(tester, 'upcoming'), '1');
      expect(kpi(tester, 'published'), '1');
      expect(kpi(tester, 'cancelled'), '1');
      expect(kpi(tester, 'registrations'), '16');
      expect(kpi(tester, 'checkedIn'), '4');
      expect(find.text('My upcoming workshop'), findsOneWidget);
      expect(find.text('Hall A'), findsOneWidget);
      expect(find.text('12 / 100 registered'), findsOneWidget);
      expect(find.text('3 checked in'), findsOneWidget);
      expect(find.text('Cancelled conference'), findsNothing);
      expect(repository.dashboardReads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initial loading never presents fabricated zero KPI values', (
    tester,
  ) async {
    final pending = Completer<void>();
    repository.pending = pending.future;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byKey(const Key('dashboardLoading')), findsOneWidget);
    expect(find.byKey(const Key('dashboardKpi-totalEvents')), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(kpi(tester, 'totalEvents'), '2');
  });

  testWidgets(
    'empty dashboard displays real zero totals and working create/manage actions',
    (tester) async {
      repository.events = [];
      var creates = 0, manages = 0;
      await tester.pumpWidget(
        app(create: () => creates++, manage: () => manages++),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboardEmpty')), findsOneWidget);
      expect(kpi(tester, 'totalEvents'), '0');
      await tester.tap(find.byKey(const Key('createEventAction')));
      await tester.tap(find.byKey(const Key('manageEventsAction')));
      expect(creates, 1);
      expect(manages, 1);
    },
  );

  testWidgets(
    'history without future events shows No upcoming instead of No events',
    (tester) async {
      repository.events = [
        testEvent(
          status: EventStatus.cancelled,
          startAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(kpi(tester, 'totalEvents'), '1');
      expect(kpi(tester, 'cancelled'), '1');
      expect(find.byKey(const Key('dashboardNoUpcoming')), findsOneWidget);
      expect(find.byKey(const Key('dashboardEmpty')), findsNothing);
      expect(find.text('Recent & ongoing events'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('dashboardEventActions-event-1')),
      );
      await tester.tap(find.byKey(const Key('dashboardEventActions-event-1')));
      await tester.pumpAndSettle();
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Cancel Event'), findsNothing);
    },
  );

  testWidgets('error shows its recovery message and retry reloads data', (
    tester,
  ) async {
    repository.failure = const AppException(
      'You do not have permission to access this data.',
      code: 'permission-denied',
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboardError')), findsOneWidget);
    expect(
      find.text('You do not have permission to access this data.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboardKpi-totalEvents')), findsNothing);
    expect(find.byKey(const Key('dashboardEmpty')), findsNothing);
    repository.failure = null;
    await tester.ensureVisible(find.byKey(const Key('dashboardRetryButton')));
    await tester.tap(find.byKey(const Key('dashboardRetryButton')));
    await tester.pumpAndSettle();
    expect(kpi(tester, 'totalEvents'), '2');
    expect(repository.dashboardReads, 2);
  });

  testWidgets(
    'refresh hides stale metrics while loading then reads new counters',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      repository.events = [testEvent(registeredCount: 80, checkedInCount: 39)];
      final pending = Completer<void>();
      repository.pending = pending.future;
      await tester.tap(find.byKey(const Key('dashboardRefreshButton')));
      await tester.pump();
      expect(find.byKey(const Key('dashboardLoading')), findsOneWidget);
      expect(find.byKey(const Key('dashboardKpi-totalEvents')), findsNothing);
      pending.complete();
      await tester.pumpAndSettle();
      expect(kpi(tester, 'registrations'), '80');
      expect(kpi(tester, 'checkedIn'), '39');
      expect(repository.dashboardReads, 2);
    },
  );

  testWidgets('pull to refresh reloads the dashboard', (tester) async {
    repository.events = [];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    repository.events = [testEvent()];
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(repository.dashboardReads, 2);
    expect(kpi(tester, 'totalEvents'), '1');
  });

  testWidgets(
    'Edit and Participants callbacks receive the selected event once',
    (tester) async {
      final edits = <String>[], participants = <String>[];
      await tester.pumpWidget(
        app(edit: edits.add, participants: participants.add),
      );
      await tester.pumpAndSettle();
      final menu = find.byKey(const Key('dashboardEventActions-future'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(edits, ['future']);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Participants'));
      await tester.pumpAndSettle();
      expect(participants, ['future']);
    },
  );

  testWidgets(
    'detail and fallback participant navigation use existing event routes',
    (tester) async {
      final router = GoRouter(
        initialLocation: RouteNames.organizer,
        routes: [
          GoRoute(
            path: RouteNames.organizer,
            builder: (_, _) => OrganizerDashboardScreen(
              onCreateEvent: () {},
              onManageEvents: () {},
              onEditEvent: (_) {},
            ),
          ),
          GoRoute(
            path: '/organizer/events/:eventId',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Detail:${state.pathParameters['eventId']}'),
            ),
          ),
          GoRoute(
            path: '/organizer/events/:eventId/participants',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Participants:${state.pathParameters['eventId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(app(router: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('dashboardDetails-future')),
      );
      await tester.tap(find.byKey(const Key('dashboardDetails-future')));
      await tester.pumpAndSettle();
      expect(find.text('Detail:future'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(repository.dashboardReads, 2);
      await tester.ensureVisible(
        find.byKey(const Key('dashboardEventActions-future')),
      );
      await tester.tap(find.byKey(const Key('dashboardEventActions-future')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Participants'));
      await tester.pumpAndSettle();
      expect(find.text('Participants:future'), findsOneWidget);
    },
  );

  testWidgets('account switch and logout remove previous organizer metrics', (
    tester,
  ) async {
    final users = StreamController<AppUser?>.broadcast();
    addTearDown(users.close);
    await tester.pumpWidget(app(users: users.stream));
    users.add(owner);
    await tester.pumpAndSettle();
    expect(kpi(tester, 'registrations'), '16');

    final pending = Completer<void>();
    repository.pending = pending.future;
    repository.events = [
      testEvent(
        id: 'b-only',
        organizerId: 'organizer-b',
        registeredCount: 7,
        checkedInCount: 2,
      ),
    ];
    users.add(testUser(uid: 'organizer-b', role: UserRole.organizer));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('dashboardKpi-registrations')), findsNothing);
    expect(find.text('My upcoming workshop'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(kpi(tester, 'registrations'), '7');
    expect(kpi(tester, 'checkedIn'), '2');

    users.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboardError')), findsOneWidget);
    expect(find.byKey(const Key('dashboardKpi-registrations')), findsNothing);
  });

  testWidgets(
    'event cards use three columns on desktop and wrap on smaller windows',
    (tester) async {
      repository.events = List.generate(
        5,
        (index) => testEvent(
          id: 'grid-$index',
          title: 'Dashboard workshop $index',
          startAt: now.add(Duration(days: index + 1)),
        ),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final (width, columns) in [(1440.0, 3), (1000.0, 2), (430.0, 1)]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final first = tester.getRect(
          find.byKey(const Key('dashboardEvent-grid-0')),
        );
        for (var index = 1; index < columns; index++) {
          final next = tester.getRect(
            find.byKey(Key('dashboardEvent-grid-$index')),
          );
          expect(next.top, closeTo(first.top, 0.1));
          expect(next.left, greaterThan(first.left));
          expect(next.width, closeTo(first.width, 0.1));
        }
        final nextRow = tester.getRect(
          find.byKey(Key('dashboardEvent-grid-$columns')),
        );
        expect(nextRow.top, greaterThan(first.bottom));
        expect(nextRow.left, closeTo(first.left, 0.1));
        expect(
          tester.takeException(),
          isNull,
          reason: '$columns columns at $width',
        );
      }
    },
  );

  testWidgets(
    'phone, landscape and tablet layouts support large counters and text',
    (tester) async {
      repository.events = [
        testEvent(
          registeredCount: 12345678901,
          checkedInCount: 12345678900,
          capacity: 20000000000,
        ),
      ];
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final size in [
        const Size(360, 800),
        const Size(430, 900),
        const Size(844, 390),
        const Size(800, 1024),
        const Size(1200, 900),
      ]) {
        for (final scale in [1.0, 2.0]) {
          // Remove the previous route before resizing: this test exercises
          // Dashboard layout, not the destination left by a navigation test.
          await tester.pumpWidget(const SizedBox.shrink());
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.view.physicalSize = size;
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('dashboardKpi-checkedIn')),
            findsOneWidget,
          );
          expect(kpi(tester, 'registrations'), '12345678901');
          expect(
            tester.takeException(),
            isNull,
            reason: '$size / text scale $scale',
          );
        }
      }
    },
  );
}
