import 'dart:async';

import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EventFormInput validInput({String title = 'Flutter Workshop'}) => EventFormInput(
    title: title,
    description: 'Learn Flutter fundamentals in this hands-on workshop.',
    category: 'technology',
    locationName: 'Hall A',
    startAt: DateTime(2030, 1, 1, 9),
    endAt: DateTime(2030, 1, 1, 11),
    capacity: 100,
  );

  test('initial state is idle', () {
    expect(EventFormSubmissionController().state.status, EventFormSubmissionStatus.idle);
  });

  test('invalid input produces validation errors', () async {
    final controller = EventFormSubmissionController();
    final result = await controller.submit(validInput(title: ''), (_) async {});

    expect(result, isFalse);
    expect(controller.state.status, EventFormSubmissionStatus.error);
    expect(controller.state.validationErrors['title'], 'Title is required.');
  });

  test('invalid input does not call save callback', () async {
    var calls = 0;
    await EventFormSubmissionController().submit(validInput(title: ''), (_) async => calls++);

    expect(calls, 0);
  });

  test('valid input calls save callback once', () async {
    var calls = 0;
    final result = await EventFormSubmissionController().submit(validInput(), (_) async => calls++);

    expect(result, isTrue);
    expect(calls, 1);
  });

  test('submission enters loading state', () async {
    final completer = Completer<void>();
    final controller = EventFormSubmissionController();
    final pending = controller.submit(validInput(), (_) => completer.future);

    expect(controller.state.status, EventFormSubmissionStatus.submitting);
    completer.complete();
    await pending;
  });

  test('successful save sets success state', () async {
    final controller = EventFormSubmissionController();
    await controller.submit(validInput(), (_) async {});

    expect(controller.state.status, EventFormSubmissionStatus.success);
    expect(controller.state.validationErrors, isEmpty);
  });

  test('failed save sets a safe error state', () async {
    final controller = EventFormSubmissionController();
    final result = await controller.submit(validInput(), (_) async => throw Exception('raw backend error'));

    expect(result, isFalse);
    expect(controller.state.status, EventFormSubmissionStatus.error);
    expect(controller.state.errorMessage, 'Unable to save event. Please try again.');
  });

  test('failure releases the submission lock', () async {
    final controller = EventFormSubmissionController();
    await controller.submit(validInput(), (_) async => throw Exception());
    var calls = 0;
    final result = await controller.submit(validInput(), (_) async => calls++);

    expect(result, isTrue);
    expect(calls, 1);
  });

  test('rapid double submission invokes save only once', () async {
    final completer = Completer<void>();
    final controller = EventFormSubmissionController();
    var calls = 0;
    final first = controller.submit(validInput(), (_) { calls++; return completer.future; });
    final second = controller.submit(validInput(), (_) { calls++; return completer.future; });

    expect(await second, isFalse);
    expect(calls, 1);
    completer.complete();
    expect(await first, isTrue);
  });

  test('later valid submission proceeds after a successful submission', () async {
    final controller = EventFormSubmissionController();
    var calls = 0;
    await controller.submit(validInput(), (_) async => calls++);
    final result = await controller.submit(validInput(title: 'Dart Workshop'), (_) async => calls++);

    expect(result, isTrue);
    expect(calls, 2);
  });
}
