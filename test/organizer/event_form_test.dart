import 'dart:async';

import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/screens/event_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/shared/enums/event_status.dart';

void main() {
  EventFormInput input({
    String title = 'Flutter Workshop',
    String description =
        'Learn Flutter fundamentals in this hands-on workshop.',
    DateTime? start,
    DateTime? end,
  }) => EventFormInput(
    title: title,
    description: description,
    category: 'technology',
    locationName: 'Hall A',
    startAt: start ?? DateTime(2030, 1, 1, 9),
    endAt: end ?? DateTime(2030, 1, 1, 11),
    capacity: 100,
  );
  Widget form({EventFormInput? initial, EventFormSubmitCallback? submit}) =>
      ProviderScope(
        child: MaterialApp(
          home: EventFormScreen(
            initialValue: initial,
            onSubmit: submit ?? (_) async {},
          ),
        ),
      );
  Future<void> fill(WidgetTester t) async {
    await t.enterText(find.byKey(const Key('titleField')), 'Flutter Workshop');
    await t.enterText(
      find.byKey(const Key('descriptionField')),
      'Learn Flutter fundamentals in this hands-on workshop.',
    );
    await t.ensureVisible(find.byKey(const Key('categoryField')));
    await t.tap(find.byKey(const Key('categoryField')));
    await t.pumpAndSettle();
    await t.tap(find.text('Technology').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('locationField')), 'Hall A');
    await t.enterText(find.byKey(const Key('capacityField')), '100');
  }

  Future<void> tapSubmit(WidgetTester t) async {
    final submitButton = find.byKey(const Key('submitEventFormButton'));
    await t.ensureVisible(submitButton);
    await t.pump();
    await t.tap(submitButton);
  }

  Future<void> selectStatus(WidgetTester t, String label) async {
    final status = find.byKey(const Key('eventStatusField'));
    await t.ensureVisible(status);
    await t.tap(status);
    await t.pumpAndSettle();
    await t.tap(find.text(label).last);
    await t.pumpAndSettle();
  }

  testWidgets('create selects Draft and submits the complete form as a draft', (
    t,
  ) async {
    EventFormInput? submitted;
    await t.pumpWidget(form(submit: (value) async => submitted = value));
    final field = t.widget<DropdownButtonFormField<EventStatus>>(
      find.byKey(const Key('eventStatusField')),
    );
    expect(field.initialValue, EventStatus.published);
    await selectStatus(t, 'Draft');
    await fill(t);
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(submitted?.status, EventStatus.draft);
    expect(submitted?.title, 'Flutter Workshop');
  });

  testWidgets('Draft selection still requires all event details', (t) async {
    var calls = 0;
    await t.pumpWidget(form(submit: (_) async => calls++));
    await t.enterText(find.byKey(const Key('titleField')), 'Draft workshop');
    await selectStatus(t, 'Draft');
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Description is required.'), findsOneWidget);
    expect(find.text('Location is required.'), findsOneWidget);
  });

  testWidgets('edit preselects Draft and saves the Published selection', (
    t,
  ) async {
    EventFormInput? submitted;
    await t.pumpWidget(
      form(
        initial: input().copyWith(status: EventStatus.draft),
        submit: (value) async => submitted = value,
      ),
    );
    expect(
      t
          .widget<DropdownButtonFormField<EventStatus>>(
            find.byKey(const Key('eventStatusField')),
          )
          .initialValue,
      EventStatus.draft,
    );
    await selectStatus(t, 'Published');
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(submitted?.status, EventStatus.published);
  });

  testWidgets(
    'participant event status is locked while detail edits remain available',
    (t) async {
      await t.pumpWidget(
        form(
          initial: input().copyWith(
            status: EventStatus.published,
            currentRegisteredCount: 1,
          ),
        ),
      );
      expect(
        t
            .widget<DropdownButtonFormField<EventStatus>>(
              find.byKey(const Key('eventStatusField')),
            )
            .onChanged,
        isNull,
      );
      expect(
        find.text('Status cannot change after participants have registered.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'create mode renders under ProviderScope with all required fields',
    (t) async {
      await t.pumpWidget(form());
      expect(find.text('Create Event'), findsNWidgets(3));
      for (final key in [
        'titleField',
        'descriptionField',
        'categoryField',
        'locationField',
        'startDateTimeField',
        'endDateTimeField',
        'capacityField',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
    },
  );
  testWidgets('edit mode prepopulates input values', (t) async {
    await t.pumpWidget(form(initial: input(title: 'Existing Event')));
    expect(find.text('Edit Event'), findsNWidgets(2));
    expect(find.text('Existing Event'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });
  testWidgets('invalid title prevents submit', (t) async {
    var count = 0;
    await t.pumpWidget(
      form(
        initial: input(title: '  '),
        submit: (_) async => count++,
      ),
    );
    await tapSubmit(t);
    await t.pump();
    expect(find.text('Title is required.'), findsOneWidget);
    expect(count, 0);
  });
  testWidgets('invalid description prevents submit', (t) async {
    var count = 0;
    await t.pumpWidget(
      form(
        initial: input(description: 'short'),
        submit: (_) async => count++,
      ),
    );
    await tapSubmit(t);
    await t.pump();
    expect(
      find.text('Description must be at least 20 characters.'),
      findsOneWidget,
    );
    expect(count, 0);
  });
  testWidgets('invalid capacity prevents submit', (t) async {
    var count = 0;
    await t.pumpWidget(form(submit: (_) async => count++));
    await fill(t);
    await t.enterText(find.byKey(const Key('capacityField')), '0');
    await tapSubmit(t);
    await t.pump();
    expect(find.text('Capacity must be greater than 0.'), findsOneWidget);
    expect(count, 0);
  });

  testWidgets('a fractional capacity is rejected without losing the input', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(form(submit: (_) async => calls++));
    await fill(t);
    await t.enterText(find.byKey(const Key('capacityField')), '1.5');
    await tapSubmit(t);
    await t.pump();
    expect(calls, 0);
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('Capacity must be greater than 0.'), findsOneWidget);
  });

  testWidgets('create date picker rejects a past start with an inline error', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(form(submit: (_) async => calls++));
    await fill(t);
    final labels = MaterialLocalizations.of(
      t.element(find.byType(EventFormScreen)),
    );
    final start = find.byKey(const Key('startDateTimeField'));
    await t.ensureVisible(start);
    await t.tap(start);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(labels.inputDateModeButtonLabel));
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      labels.formatCompactDate(DateTime(2020, 1, 1)),
    );
    await t.tap(find.text(labels.okButtonLabel));
    await t.pumpAndSettle();
    await t.tap(find.text(labels.okButtonLabel));
    await t.pumpAndSettle();
    await tapSubmit(t);
    await t.pump();
    expect(calls, 0);
    expect(
      find.text('Start time must be in the future for a new published event.'),
      findsOneWidget,
    );
    expect(find.text('Flutter Workshop'), findsOneWidget);
  });
  testWidgets('end time before start time prevents submit', (t) async {
    var count = 0;
    await t.pumpWidget(
      form(
        initial: input(
          start: DateTime(2030, 1, 1, 11),
          end: DateTime(2030, 1, 1, 9),
        ),
        submit: (_) async => count++,
      ),
    );
    await tapSubmit(t);
    await t.pump();
    expect(find.text('End time must be after start time.'), findsOneWidget);
    expect(count, 0);
  });
  testWidgets('valid input invokes submit callback', (t) async {
    EventFormInput? submitted;
    await t.pumpWidget(form(submit: (value) async => submitted = value));
    await fill(t);
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(submitted?.title, 'Flutter Workshop');
    expect(submitted?.capacity, 100);
  });
  testWidgets('loading prevents double submission', (t) async {
    final completer = Completer<void>();
    var count = 0;
    await t.pumpWidget(
      form(
        submit: (_) {
          count++;
          return completer.future;
        },
      ),
    );
    await fill(t);
    await tapSubmit(t);
    await t.pump();
    await tapSubmit(t);
    await t.pump();
    expect(find.text('Saving...'), findsOneWidget);
    expect(count, 1);
    completer.complete();
    await t.pump();
  });
  testWidgets('form works at a narrow viewport without overflow', (t) async {
    await t.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(form());
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('valid form submits through the Riverpod ViewModel', (t) async {
    var calls = 0;
    await t.pumpWidget(form(submit: (_) async => calls++));
    await fill(t);
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('Riverpod submitting state is reflected in the UI', (t) async {
    final completer = Completer<void>();
    await t.pumpWidget(form(submit: (_) => completer.future));
    await fill(t);
    await tapSubmit(t);
    await t.pump();
    expect(find.text('Saving...'), findsOneWidget);
    completer.complete();
    await t.pump();
  });

  testWidgets(
    'two rapid taps result in one save callback through the controller',
    (t) async {
      final completer = Completer<void>();
      var calls = 0;
      await t.pumpWidget(
        form(
          submit: (_) {
            calls++;
            return completer.future;
          },
        ),
      );
      await fill(t);
      await tapSubmit(t);
      await t.pump();
      await tapSubmit(t);
      await t.pump();
      expect(calls, 1);
      completer.complete();
      await t.pump();
    },
  );

  testWidgets('save exception displays the controller safe error message', (
    t,
  ) async {
    await t.pumpWidget(
      form(submit: (_) async => throw Exception('backend detail')),
    );
    await fill(t);
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('submissionErrorMessage')), findsOneWidget);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('retry succeeds after a failed save', (t) async {
    var calls = 0;
    await t.pumpWidget(
      form(
        submit: (_) async {
          calls++;
          if (calls == 1) throw Exception();
        },
      ),
    );
    await fill(t);
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(find.text('Flutter Workshop'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    await tapSubmit(t);
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(find.byKey(const Key('submissionErrorMessage')), findsNothing);
  });

  testWidgets('success callback fires once and a fresh form has idle state', (
    t,
  ) async {
    var saves = 0;
    var navigations = 0;
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EventFormScreen(
            onSubmit: (_) async => saves++,
            onSuccess: () => navigations++,
          ),
        ),
      ),
    );
    await fill(t);
    await tapSubmit(t);
    await t.pumpAndSettle();
    await tapSubmit(t);
    expect(saves, 1);
    expect(navigations, 1);
    await t.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SizedBox.shrink())),
    );
    await t.pumpAndSettle();
    await t.pumpWidget(form());
    await t.pump();
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('submitEventFormButton')))
          .onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('submissionErrorMessage')), findsNothing);
  });

  testWidgets('disposing during an in-flight save does not cause exceptions', (
    t,
  ) async {
    final completer = Completer<void>();
    await t.pumpWidget(form(submit: (_) => completer.future));
    await fill(t);

    await tapSubmit(t);
    await t.pump();
    await t.pumpWidget(const SizedBox.shrink());
    completer.complete();
    await t.pump();

    expect(t.takeException(), isNull);
  });
}
