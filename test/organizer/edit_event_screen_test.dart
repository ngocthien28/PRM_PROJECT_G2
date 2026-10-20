import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/routing/route_names.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/events/presentation/widgets/event_poster.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/screens/organizer_create_event_screen.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

class _EditEvents extends FakeEvents {
  _EditEvents(super.events);
  final loads = <String, Completer<EventModel>>{};
  Object? loadFailure;
  Object? updateFailure;
  Future<void>? updateGate;
  int updateCalls = 0;

  @override
  Future<EventModel> getEventById(String id, {AppUser? actor}) async {
    if (loads[id] != null) return loads[id]!.future;
    if (loadFailure != null) throw loadFailure!;
    return super.getEventById(id, actor: actor);
  }

  @override
  Future<EventModel> updateEvent({
    required String eventId,
    required EventFormInput input,
    required AppUser actor,
    DateTime? expectedUpdatedAt,
  }) async {
    updateCalls++;
    if (updateGate != null) await updateGate;
    if (updateFailure != null) throw updateFailure!;
    return super.updateEvent(
      eventId: eventId,
      input: input,
      actor: actor,
      expectedUpdatedAt: expectedUpdatedAt,
    );
  }
}

void main() {
  late _EditEvents events;
  late GoRouter router;
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  setUp(() {
    events = _EditEvents([
      testEvent(),
      testEvent(id: 'event-2', title: 'Second event'),
    ]);
    router = GoRouter(
      initialLocation: '/edit/event-1',
      routes: [
        GoRoute(
          path: '/edit/:id',
          builder: (_, state) =>
              OrganizerEditEventScreen(eventId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: RouteNames.organizerManagedEvents,
          builder: (_, _) =>
              const Scaffold(body: Text('Managed events destination')),
        ),
      ],
    );
  });
  tearDown(() => router.dispose());
  Future<void> mount(WidgetTester tester, {Stream<AppUser?>? users}) =>
      tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => users ?? Stream.value(owner),
            ),
            eventRepositoryProvider.overrideWithValue(events),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
  Future<void> save(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('submitEventFormButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('load failure shows Retry; retry loads the prefilled form', (
    tester,
  ) async {
    events.loadFailure = const AppException(
      'Cannot connect. Please retry.',
      code: 'unavailable',
    );
    await mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Cannot connect. Please retry.'), findsOneWidget);
    expect(find.byKey(const Key('titleField')), findsNothing);
    events.loadFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter Workshop'), findsOneWidget);
    expect(find.text('Hall A'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('late event A response cannot replace event B form', (
    tester,
  ) async {
    final pending = Completer<EventModel>();
    events.loads['event-1'] = pending;
    await mount(tester);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    router.go('/edit/event-2');
    await tester.pumpAndSettle();
    expect(find.text('Second event'), findsOneWidget);
    pending.complete(testEvent());
    await tester.pumpAndSettle();
    expect(find.text('Second event'), findsOneWidget);
    expect(find.text('Flutter Workshop'), findsNothing);
  });

  testWidgets('pending update disables Save and sends only one update', (
    tester,
  ) async {
    final pending = Completer<void>();
    events.updateGate = pending.future;
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('titleField')), 'Edited once');
    await save(tester);
    expect(find.text('Saving...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submitEventFormButton')))
          .onPressed,
      isNull,
    );
    await save(tester);
    expect(events.updateCalls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Managed events destination'), findsOneWidget);
    expect(find.text('Event updated successfully.'), findsOneWidget);
    expect(events.events.first.title, 'Edited once');
  });

  testWidgets('update error retains edited text; retry succeeds', (
    tester,
  ) async {
    events.updateFailure = const AppException(
      'Permission denied.',
      code: 'permission-denied',
    );
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('titleField')), 'Keep my edit');
    await save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Permission denied.'), findsOneWidget);
    expect(find.text('Keep my edit'), findsOneWidget);
    expect(find.text('Reload latest event'), findsOneWidget);
    expect(find.text('Managed events destination'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submitEventFormButton')))
          .onPressed,
      isNotNull,
    );
    events.updateFailure = null;
    await save(tester);
    await tester.pumpAndSettle();
    expect(events.updateCalls, 2);
    expect(find.text('Managed events destination'), findsOneWidget);
  });

  testWidgets('invalid edited title never reaches update', (tester) async {
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('titleField')), ' ');
    await save(tester);
    await tester.pumpAndSettle();
    expect(find.text('Title is required.'), findsOneWidget);
    expect(events.updateCalls, 0);
  });

  testWidgets('cancelled event is blocked before rendering an editable form', (
    tester,
  ) async {
    events.events = [testEvent(status: EventStatus.cancelled)];
    await mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Cancelled events cannot be updated.'), findsOneWidget);
    expect(find.byKey(const Key('titleField')), findsNothing);
  });

  testWidgets(
    'phone edit form preserves poster metadata and displays local dates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      events.events = [
        testEvent(posterUrl: 'https://example.invalid/poster.png'),
      ];
      await mount(tester);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EventPoster>(find.byType(EventPoster)).url,
        events.events.single.posterUrl,
      );
      final local = events.events.single.startAt.toLocal();
      expect(find.text(events.events.single.description), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(
        find.textContaining(
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
        ),
        findsWidgets,
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching user removes the previous owners editable form', (
    tester,
  ) async {
    final changes = StreamController<AppUser?>();
    addTearDown(changes.close);
    Stream<AppUser?> users() async* {
      yield owner;
      yield* changes.stream;
    }

    await mount(tester, users: users());
    await tester.pumpAndSettle();
    expect(find.text('Flutter Workshop'), findsOneWidget);
    changes.add(testUser(uid: 'other', role: UserRole.organizer));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('titleField')), findsNothing);
    expect(find.byKey(const Key('editEventLoadError')), findsOneWidget);
  });
}
