import 'dart:async';

import 'package:campushub/features/organizer_events/presentation/screens/manage_events_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_events_view_model.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/event_fakes.dart';

void main() {
  Widget screen(Future<List<EventModel>> Function() load) => ProviderScope(
    overrides: [
      organizerEventsProvider.overrideWith((ref) async {
        return load();
      }),
    ],
    child: const MaterialApp(home: ManageEventsScreen()),
  );

  testWidgets('renders a loading state', (tester) async {
    final pending = Completer<List<EventModel>>();
    await tester.pumpWidget(screen(() => pending.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const []);
  });

  testWidgets('renders an empty state with a create CTA', (tester) async {
    await tester.pumpWidget(screen(() async => <EventModel>[]));
    await tester.pumpAndSettle();

    expect(find.text('No managed events yet.'), findsOneWidget);
    expect(find.byKey(const Key('managedEventsCreateButton')), findsOneWidget);
    expect(find.text('Create Event'), findsWidgets);
  });

  testWidgets('renders event details and filters by status and title', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        () async => [
          testEvent(id: 'published', title: 'Flutter Workshop'),
          testEvent(
            id: 'draft',
            title: 'Music rehearsal',
            status: EventStatus.draft,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Flutter Workshop'), findsOneWidget);
    expect(find.text('Music rehearsal'), findsOneWidget);
    expect(find.text('20 / 100 registered'), findsNWidgets(2));
    expect(find.text('Published'), findsNWidgets(2));
    expect(find.text('Draft'), findsAtLeastNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Draft'));
    await tester.pump();
    expect(find.text('Flutter Workshop'), findsNothing);
    expect(find.text('Music rehearsal'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('managedEventsSearchField')),
      'flutter',
    );
    await tester.pump();
    expect(find.text('No events match these filters.'), findsOneWidget);
  });

  testWidgets('renders an error state with retry', (tester) async {
    await tester.pumpWidget(screen(() async => throw StateError('offline')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load your managed events.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
