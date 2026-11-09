import 'package:campushub/features/organizer_events/data/models/event_draft.dart';
import 'package:campushub/features/organizer_events/presentation/screens/event_form_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_draft_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'draft_fakes.dart';

void main() {
  late FakeDraftRepository repository;
  setUp(() {
    final now = DateTime.now().toUtc();
    repository = FakeDraftRepository()
      ..value = EventDraft(
        id: 'stable-request',
        organizerId: 'A',
        fields: {
          'title': 'Restored workshop',
          'description': 'A complete description for the campus workshop.',
          'category': 'technology',
          'locationName': 'Hall A',
          'capacity': '40',
          'startAt': now.add(const Duration(days: 1)).toIso8601String(),
          'endAt': now.add(const Duration(days: 1, hours: 2)).toIso8601String(),
          'posterSelected': false,
        },
        createdAt: now,
        updatedAt: now,
      );
  });
  Widget form({Future<void> Function(dynamic)? save}) => ProviderScope(
    overrides: [eventDraftRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: EventFormScreen(
        draftOrganizerId: 'A',
        onSubmit: save ?? (_) async {},
      ),
    ),
  );
  Future<void> submit(WidgetTester tester) async {
    final button = find.byKey(const Key('submitEventFormButton'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('local draft restores and retains the selected server status', (
    tester,
  ) async {
    final old = repository.value!;
    repository.value = EventDraft(
      id: old.id,
      organizerId: old.organizerId,
      fields: {...old.fields, 'status': 'draft'},
      createdAt: old.createdAt,
      updatedAt: old.updatedAt,
    );
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('eventStatusField'));
    expect(
      tester.widget<DropdownButtonFormField<EventStatus>>(field).initialValue,
      EventStatus.draft,
    );
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Published').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    expect(repository.value!.fields['status'], 'published');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButtonFormField<EventStatus>>(field).initialValue,
      EventStatus.published,
    );
  });

  testWidgets(
    'restore prefills fields and does not submit; raw invalid capacity is retained',
    (tester) async {
      var calls = 0;
      repository.value = EventDraft(
        id: repository.value!.id,
        organizerId: 'A',
        fields: {...repository.value!.fields, 'capacity': '4.5'},
        createdAt: repository.value!.createdAt,
        updatedAt: repository.value!.updatedAt,
      );
      await tester.pumpWidget(
        form(
          save: (_) async {
            calls++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restored workshop'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(calls, 0);
      await submit(tester);
      expect(calls, 0);
      expect(repository.value, isNotNull);
    },
  );
  testWidgets(
    'create success deletes the draft and preserves stable request ID',
    (tester) async {
      String? request;
      await tester.pumpWidget(
        form(
          save: (input) async {
            request = input.createRequestId as String?;
          },
        ),
      );
      await tester.pumpAndSettle();
      await submit(tester);
      expect(request, 'stable-request');
      expect(repository.value, isNull);
    },
  );
  testWidgets('upload or remote failure retains the form and draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      form(save: (_) async => throw StateError('upload failed')),
    );
    await tester.pumpAndSettle();
    await submit(tester);
    expect(repository.value, isNotNull);
    expect(find.text('Restored workshop'), findsOneWidget);
    expect(find.byKey(const Key('submissionErrorMessage')), findsOneWidget);
  });
  testWidgets('discard requires confirmation and resets the form', (
    tester,
  ) async {
    await tester.pumpWidget(form());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard Draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(repository.value, isNotNull);
    await tester.tap(find.text('Discard Draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(repository.value, isNull);
    expect(find.text('Restored workshop'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'leaving before debounce flushes and reopening restores the latest text',
    (tester) async {
      await tester.pumpWidget(form());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('titleField')),
        'Edited before leaving',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(form());
      await tester.pumpAndSettle();
      expect(find.text('Edited before leaving'), findsOneWidget);
    },
  );
  testWidgets(
    'poster from an earlier session requests reselection and blocks submit',
    (tester) async {
      final old = repository.value!;
      repository.value = EventDraft(
        id: old.id,
        organizerId: 'A',
        fields: {...old.fields, 'posterSelected': true},
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
      );
      var calls = 0;
      await tester.pumpWidget(
        form(
          save: (_) async {
            calls++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draftPosterWarning')), findsOneWidget);
      await submit(tester);
      expect(calls, 0);
      expect(repository.value, isNotNull);
    },
  );
}
