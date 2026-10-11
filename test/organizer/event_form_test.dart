import 'dart:async';

import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/screens/event_form_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_form_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EventFormInput input({String title = 'Flutter Workshop', DateTime? start, DateTime? end}) => EventFormInput(
    title: title, description: 'Learn Flutter fundamentals in this hands-on workshop.', category: 'technology', locationName: 'Hall A',
    startAt: start ?? DateTime(2030, 1, 1, 9), endAt: end ?? DateTime(2030, 1, 1, 11), capacity: 100,
  );
  Widget form({EventFormInput? initial, EventFormSubmitCallback? submit, EventFormSubmissionController? controller}) => MaterialApp(home: EventFormScreen(initialValue: initial, onSubmit: submit ?? (_) async {}, submissionController: controller));
  Future<void> fill(WidgetTester t) async {
    await t.enterText(find.byKey(const Key('titleField')), 'Flutter Workshop');
    await t.enterText(find.byKey(const Key('descriptionField')), 'Learn Flutter fundamentals in this hands-on workshop.');
    await t.enterText(find.byKey(const Key('categoryField')), 'technology');
    await t.enterText(find.byKey(const Key('locationField')), 'Hall A');
    await t.enterText(find.byKey(const Key('capacityField')), '100');
  }

  testWidgets('create mode renders all required fields', (t) async {
    await t.pumpWidget(form());
    expect(find.text('Create Event'), findsNWidgets(2));
    for (final key in ['titleField', 'descriptionField', 'categoryField', 'locationField', 'startDateTimeField', 'endDateTimeField', 'capacityField']) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
  });
  testWidgets('edit mode prepopulates input values', (t) async {
    await t.pumpWidget(form(initial: input(title: 'Existing Event')));
    expect(find.text('Edit Event'), findsNWidgets(2));
    expect(find.text('Existing Event'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });
  testWidgets('invalid title prevents submit', (t) async {
    var count = 0; await t.pumpWidget(form(submit: (_) async => count++)); await fill(t);
    await t.enterText(find.byKey(const Key('titleField')), '  '); await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    expect(find.text('Title is required.'), findsOneWidget); expect(count, 0);
  });
  testWidgets('invalid description prevents submit', (t) async {
    var count = 0; await t.pumpWidget(form(submit: (_) async => count++)); await fill(t);
    await t.enterText(find.byKey(const Key('descriptionField')), 'short'); await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    expect(find.text('Description must be at least 20 characters.'), findsOneWidget); expect(count, 0);
  });
  testWidgets('invalid capacity prevents submit', (t) async {
    var count = 0; await t.pumpWidget(form(submit: (_) async => count++)); await fill(t);
    await t.enterText(find.byKey(const Key('capacityField')), '0'); await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    expect(find.text('Capacity must be greater than 0.'), findsOneWidget); expect(count, 0);
  });
  testWidgets('end time before start time prevents submit', (t) async {
    var count = 0; await t.pumpWidget(form(initial: input(start: DateTime(2030, 1, 1, 11), end: DateTime(2030, 1, 1, 9)), submit: (_) async => count++));
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    expect(find.text('End time must be after start time.'), findsOneWidget); expect(count, 0);
  });
  testWidgets('valid input invokes submit callback', (t) async {
    EventFormInput? submitted; await t.pumpWidget(form(submit: (value) async => submitted = value)); await fill(t);
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pumpAndSettle();
    expect(submitted?.title, 'Flutter Workshop'); expect(submitted?.capacity, 100);
  });
  testWidgets('loading prevents double submission', (t) async {
    final completer = Completer<void>(); var count = 0;
    await t.pumpWidget(form(submit: (_) { count++; return completer.future; })); await fill(t);
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump(); await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    expect(find.text('Saving...'), findsOneWidget); expect(count, 1); completer.complete(); await t.pump();
  });
  testWidgets('form works at a narrow viewport without overflow', (t) async {
    await t.binding.setSurfaceSize(const Size(320, 640)); addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(form()); await t.drag(find.byType(SingleChildScrollView), const Offset(0, -300)); await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('valid form submits through the submission controller', (t) async {
    final controller = EventFormSubmissionController();
    await t.pumpWidget(form(controller: controller)); await fill(t);
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pumpAndSettle();
    expect(controller.state.status, EventFormSubmissionStatus.success);
  });

  testWidgets('controller loading state is reflected in the UI', (t) async {
    final controller = EventFormSubmissionController(); final completer = Completer<void>();
    await t.pumpWidget(form(controller: controller, submit: (_) => completer.future)); await fill(t);
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    expect(controller.state.isSubmitting, isTrue); expect(find.text('Saving...'), findsOneWidget);
    completer.complete(); await t.pump();
  });

  testWidgets('two rapid taps result in one save callback through the controller', (t) async {
    final completer = Completer<void>(); var calls = 0;
    await t.pumpWidget(form(submit: (_) { calls++; return completer.future; })); await fill(t);
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pump();
    expect(calls, 1); completer.complete(); await t.pump();
  });

  testWidgets('save exception displays the controller safe error message', (t) async {
    await t.pumpWidget(form(submit: (_) async => throw Exception('backend detail'))); await fill(t);
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pumpAndSettle();
    expect(find.byKey(const Key('submissionErrorMessage')), findsOneWidget);
    expect(find.text('Unable to save event. Please try again.'), findsOneWidget);
  });

  testWidgets('retry succeeds after a failed save', (t) async {
    final controller = EventFormSubmissionController(); var calls = 0;
    await t.pumpWidget(form(controller: controller, submit: (_) async { calls++; if (calls == 1) throw Exception(); })); await fill(t);
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('submitEventFormButton'))); await t.pumpAndSettle();
    expect(calls, 2); expect(controller.state.status, EventFormSubmissionStatus.success);
    expect(find.byKey(const Key('submissionErrorMessage')), findsNothing);
  });
}
