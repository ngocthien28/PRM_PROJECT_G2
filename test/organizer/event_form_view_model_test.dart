import 'dart:async';

import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_form_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

EventFormInput validInput({String title = 'Flutter Workshop'}) {
  return EventFormInput(
    title: title,
    description: 'Learn practical Flutter patterns with the CampusHub team.',
    category: 'technology',
    locationName: 'Innovation Hall',
    startAt: DateTime(2030, 1, 1, 9),
    endAt: DateTime(2030, 1, 1, 11),
    capacity: 100,
  );
}

void main() {
  group('EventFormViewModel', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      container.listen(eventFormViewModelProvider, (_, _) {});
    });

    tearDown(() {
      container.dispose();
    });

    EventFormViewModel viewModel() =>
        container.read(eventFormViewModelProvider.notifier);

    EventFormSubmissionState currentState() =>
        container.read(eventFormViewModelProvider);

    test('initializes in idle state', () {
      expect(currentState().status, EventFormSubmissionStatus.idle);
      expect(currentState().validationErrors, isEmpty);
      expect(currentState().errorMessage, isNull);
    });

    test('exposes validation errors for invalid input', () async {
      await viewModel().submit(validInput(title: ''), (_) async {});

      expect(currentState().status, EventFormSubmissionStatus.error);
      expect(currentState().validationErrors, contains('title'));
    });

    test('does not invoke save callback for invalid input', () async {
      var calls = 0;

      await viewModel().submit(validInput(title: ''), (_) async => calls += 1);

      expect(calls, 0);
    });

    test('exposes submitting state while a valid save is pending', () async {
      final completer = Completer<void>();
      final pending = viewModel().submit(validInput(), (_) => completer.future);

      expect(currentState().status, EventFormSubmissionStatus.submitting);
      completer.complete();
      await pending;
    });

    test('exposes success after a successful save', () async {
      final submitted = await viewModel().submit(validInput(), (_) async {});

      expect(submitted, isTrue);
      expect(currentState().status, EventFormSubmissionStatus.success);
      expect(currentState().validationErrors, isEmpty);
    });

    test('exposes a safe error message when save fails', () async {
      final submitted = await viewModel().submit(
        validInput(),
        (_) async => throw StateError('internal failure'),
      );

      expect(submitted, isFalse);
      expect(currentState().status, EventFormSubmissionStatus.error);
      expect(
        currentState().errorMessage,
        'Something went wrong. Please try again.',
      );
    });

    test(
      'executes save callback once for rapid overlapping submissions',
      () async {
        final completer = Completer<void>();
        var calls = 0;
        Future<void> save(EventFormInput _) {
          calls += 1;
          return completer.future;
        }

        final first = viewModel().submit(validInput(), save);
        final second = viewModel().submit(validInput(), save);

        completer.complete();
        expect(await first, isTrue);
        expect(await second, isFalse);
        expect(calls, 1);
      },
    );

    test('allows another submission after a completed submission', () async {
      var calls = 0;
      Future<void> save(EventFormInput _) async {
        calls += 1;
      }

      expect(await viewModel().submit(validInput(), save), isTrue);
      expect(
        await viewModel().submit(validInput(title: 'Dart Workshop'), save),
        isTrue,
      );
      expect(calls, 2);
    });

    test('provider disposal removes its controller state listener', () async {
      final isolatedContainer = ProviderContainer();
      final completer = Completer<void>();
      final pending = isolatedContainer
          .read(eventFormViewModelProvider.notifier)
          .submit(validInput(), (_) => completer.future);

      isolatedContainer.dispose();
      completer.complete();

      await expectLater(pending, completes);
    });
  });

  test(
    'create validates future start before invoking the repository',
    () async {
      final input = validInput();
      final controller = EventFormSubmissionController(
        now: () => input.startAt,
      );
      var calls = 0;
      expect(
        await controller.submit(
          input,
          (_) async => calls++,
          requireFutureStart: true,
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(controller.state.validationErrors, contains('startAt'));
      expect(controller.state.isSubmitting, isFalse);
    },
  );
}
