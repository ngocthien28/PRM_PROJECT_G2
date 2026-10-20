import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../data/models/event_form_input.dart';

/// Submission states for the organizer event form.
enum EventFormSubmissionStatus { idle, validating, submitting, success, error }

/// Submission state exposed by the Riverpod EventFormViewModel.
class EventFormSubmissionState {
  const EventFormSubmissionState({
    required this.status,
    this.validationErrors = const {},
    this.errorMessage,
  });

  const EventFormSubmissionState.idle()
    : status = EventFormSubmissionStatus.idle,
      validationErrors = const {},
      errorMessage = null;

  final EventFormSubmissionStatus status;
  final Map<String, String> validationErrors;
  final String? errorMessage;

  bool get isSubmitting => status == EventFormSubmissionStatus.submitting;
}

typedef EventFormSaveCallback = Future<void> Function(EventFormInput input);
typedef EventFormSubmissionStateListener =
    void Function(EventFormSubmissionState state);

/// Coordinates validation and an injected async save operation.
///
/// The production ViewModel delegates to this coordinator so the same
/// validation and in-flight lock can also be tested without Firebase.
class EventFormSubmissionController {
  EventFormSubmissionController({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  EventFormSubmissionState _state = const EventFormSubmissionState.idle();
  bool _submissionLocked = false;
  final Set<EventFormSubmissionStateListener> _listeners = {};

  EventFormSubmissionState get state => _state;
  void addListener(EventFormSubmissionStateListener listener) =>
      _listeners.add(listener);
  void removeListener(EventFormSubmissionStateListener listener) =>
      _listeners.remove(listener);

  void _setState(EventFormSubmissionState next) {
    _state = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }

  Future<bool> submit(
    EventFormInput input,
    EventFormSaveCallback save, {
    bool requireFutureStart = false,
  }) async {
    if (_submissionLocked) return false;

    _setState(
      const EventFormSubmissionState(
        status: EventFormSubmissionStatus.validating,
      ),
    );
    final errors = input.validate(
      requireFutureStart: requireFutureStart,
      now: _now(),
    );
    if (errors.isNotEmpty) {
      _setState(
        EventFormSubmissionState(
          status: EventFormSubmissionStatus.error,
          validationErrors: Map.unmodifiable(errors),
        ),
      );
      return false;
    }

    _submissionLocked = true;
    _setState(
      const EventFormSubmissionState(
        status: EventFormSubmissionStatus.submitting,
      ),
    );
    try {
      await save(input);
      _setState(
        const EventFormSubmissionState(
          status: EventFormSubmissionStatus.success,
        ),
      );
      return true;
    } catch (error, stack) {
      final message = error is AppException
          ? error.message
          : mapError(error, stack).message;
      _setState(
        EventFormSubmissionState(
          status: EventFormSubmissionStatus.error,
          errorMessage: message,
        ),
      );
      return false;
    } finally {
      _submissionLocked = false;
    }
  }
}

final eventFormViewModelProvider =
    NotifierProvider.autoDispose<EventFormViewModel, EventFormSubmissionState>(
      EventFormViewModel.new,
    );

/// Riverpod wrapper for [EventFormSubmissionController].
///
/// The controller remains the single owner of validation and submission
/// workflow. Its listener mirrors intermediate state to Riverpod, so consumers
/// can observe submitting before the injected callback completes.
class EventFormViewModel extends Notifier<EventFormSubmissionState> {
  late final EventFormSubmissionController _controller;
  late final EventFormSubmissionStateListener _stateListener;

  @override
  EventFormSubmissionState build() {
    _controller = EventFormSubmissionController();
    _stateListener = (next) {
      if (ref.mounted) state = next;
    };
    _controller.addListener(_stateListener);
    ref.onDispose(() => _controller.removeListener(_stateListener));
    return _controller.state;
  }

  Future<bool> submit(
    EventFormInput input,
    EventFormSaveCallback save, {
    bool requireFutureStart = false,
  }) => _controller.submit(input, save, requireFutureStart: requireFutureStart);
}
